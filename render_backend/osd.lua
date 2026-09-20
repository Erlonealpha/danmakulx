local mp = require 'mp'
local std = require 'elxlibs.std'
local asyncio = require 'elxlibs.asyncio'
local amp = require 'elxlibs.asyncio.amp'
local locks = require 'elxlibs.asyncio.locks'
local fun = require 'elxlibs.fun'
local algo = require 'modules.layout_algo'
local options = require 'modules.options'
local base = require 'render_backend._base'


local RENDER_SLICE = 30

INVALIDATE_SOURCE = 0
INVALIDATE_PREPARE = 1
INVALIDATE_LAYOUT = 2
INVALIDATE_ASS = 3

---@alias INVALIDATE_TYPE
--- | 0 SOURCE
--- | 1 PREPARE
--- | 2 LAYOUT
--- | 3 ASS

local _INVALIDATE_STR_MAP = {
    [INVALIDATE_SOURCE] = 'SOURCE',
    [INVALIDATE_PREPARE] = 'PREPARE',
    [INVALIDATE_LAYOUT] = 'LAYOUT',
    [INVALIDATE_ASS] = 'ASS',
}


local function get_max_tracks(display_area, res_y, height)
    return math.floor(display_area * res_y / height)
end

---@alias _OsdRenderingDanmaku Danmaku & Partial<_PreparedT> & _CalcedT
---@alias _CalcedOsdRenderDanmaku _CalcedDanmaku & { ass_text?: string, ass_dirty?: boolean }

---@class DanmakuOsdRender : DanmakuRenderBackend
---@field _render_ctx {
---     sliced_dirty: boolean,
---     calc_offset_scroll: int,
---     calc_offset_fixed: int,
---     screen: DanmakuScreen,
---     danmakus: _CalcedOsdRenderDanmaku[],
---     sliced: _SlicedDanmaku,
---     overlay: mp_osd_overlay,
--- }
---@field _render_task asyncio.Task<nil>?
---@field _render_task_err any?
---@field _source_map table<string, {source: SourceBase, data: _OsdRenderingDanmaku[], enable: boolean}>
---@overload fun():self
local DanmakuOsdRender = std.class.new("DanmakuOsdRender")

function DanmakuOsdRender:__init()
    debug_msg('DanmakuOsdRender:__init()')
    self.refresh_tick = 1 / 60
    self.is_running = false
    self.is_rendering = false
    self.is_enable = true

    self._render_task = nil
    self._render_task_err = nil
    self._source_map = {}
    self._source_dirty = true
    self._prepare_dirty = true
end

function DanmakuOsdRender:_init()
    debug_msg('DanmakuOsdRender:_init()')
    self.is_running = false
    self.is_rendering = false
    self.is_enable = true
    self._source_dirty = true
    self._prepare_dirty = true

    self.pause = mp.get_property_bool('pause')
    self.fps = mp.get_property_number('display-fps', 120)
    local osd = mp.get_property_native('osd-dimensions')
    self.osd_w = osd.w
    self.osd_h = osd.h
    self.refresh_tick = 1 / self.fps

    ---@type RenderOptions
    local render_opts = base.get_optinos()
    self._render_opts = render_opts
    self._options_keys = {}
    for k, _ in pairs(render_opts) do
        table.insert(self._options_keys, k)
    end
    self.res_x = render_opts.res_x
    --         self.res_y: base, can only changed by user
    -- _render_opts.res_y: can changed by state change
    self.res_y = render_opts.res_y
    if not render_opts.follow_scale and self.osd_h then
        render_opts.res_y = self.osd_h
    end

    local max_tracks
    if render_opts.displayarea < 1 and render_opts.displayarea > 0 then
        max_tracks = get_max_tracks(render_opts.displayarea, render_opts.res_y, render_opts.fontsize)
    end
    debug_msg('DanmakuOsdRender:__init', 
        mp.get_property_number('display-width', 1920),
        mp.get_property_number('display-height', 1080),
        render_opts.res_x,
        render_opts.res_y, 
        render_opts.displayarea, 
        render_opts.fontsize,
        self.osd_h,
        self.res_y,
        max_tracks
    )
    -- debug_msgf('DanmakuOsdRender:__init max_tracks %d', max_tracks)
    self._event = locks.Event()
    self._render_ctx = {
        sliced_dirty = true,
        calc_offset_scroll = 1,
        calc_offset_fixed = 1,
        screen = algo.new_screen(
            self.res_x, 
            self.res_y, 
            render_opts.fontsize, 
            max_tracks
        ), 
        danmakus = {},
        sliced = nil,
        overlay = nil
    }
end

function DanmakuOsdRender:start()
    debug_msg('DanmakuOsdRender:start()')
    if self.is_running then
        mp.msg.warn('DanmakuOsdRender already started')
        return
    end

    self:_init()

    self:_register_events()

    self._render_ctx.overlay = mp.create_osd_overlay("ass-events")
    self._render_task = asyncio.create_task(function()
        local await = await
        local coro = async(function()
            local loop = asyncio.loops.get_running_loop()
            while true do
                if not self._event:is_set() then
                    -- debug_msg('DanmakuOsdRender:_render_task pre wait event')
                    await(self._event:wait())
                    -- debug_msg('DanmakuOsdRender:_render_task wait event done')
                end
                self:_render()
                if self.pause then
                    self._event:clear()
                end
                -- sleep
                local fut = loop:create_future()
                local handle = loop:call_later(self.refresh_tick, function()
                    fut:set_result()
                end)
                fut:__try_await()
                handle:cancel()
                -- debug_msg('DanmakuOsdRender:_render_task sleep done')
            end
        end)
        local _, err = asyncio.try_await(coro)
        if err ~= nil then
            debug_msg('DanmakuOsdRender:_render_task_err', err)
            self._render_task_err = err
        end
    end)
    self:_add_vf_fps()

    self.is_running = true
end

function DanmakuOsdRender:stop()
    debug_msg('DanmakuOsdRender:stop()')
    if not self.is_running then
        mp.msg.warn('DanmakuOsdRender is has stopped')
        return
    end

    if self._render_ctx.overlay ~= nil then
        self._render_ctx.overlay:remove()
        self._render_ctx.overlay = nil
    end
    if self._render_task ~= nil then
        if not self._render_task:done() then
            self._render_task:cancel()
        end
        self._render_task = nil
    end
    self:_handle_render_err(true)
    self:_unregister_events()
    self:_remove_vf_fps()

    self.is_rendering = false
    self.is_running = false
end

function DanmakuOsdRender:enable()
    debug_msg('DanmakuOsdRender:enable()')
    if self:_handle_render_err() then
        return
    end
    if not self.is_running then
        mp.msg.warn('DanmakuOsdRender:enable() not running')
        return
    end
    self._event:set()
    self.is_enable = true
    self._disable_from_empty = false
end

function DanmakuOsdRender:disable(from_empty)
    debug_msg('DanmakuOsdRender:disable()')
    if self:_handle_render_err() then
        return
    end
    if not self.is_running then
        mp.msg.warn('DanmakuOsdRender:disable() not running')
        return
    end
    self._event:clear()
    self._render_ctx.overlay:remove()
    if from_empty then
        self._disable_from_empty = true
    else
        self._disable_from_empty = false
    end
    self.is_rendering = false
    self.is_enable = false
end

---@param danmakus Danmaku[]
local function validate_danmakus(danmakus)
    for i = #danmakus, 1, -1 do
        if not algo.validate(danmakus[i]) then
            table.remove(danmakus, i)
        end
    end
end

function DanmakuOsdRender:add_source(source, data)
    debug_msgf('DanmakuOsdRender:add_source(%s, %d)', source.id, #data)
    if self._source_map[source.id] ~= nil then
        -- Warn or opts.dup_source_handle(update or others)
        mp.msg.warn('DanmakuOsdRender: added duplicate source')
    else
        validate_danmakus(data)
        self._source_map[source.id] = {source = source, data = data, enable = true}
        self:_invalidate(INVALIDATE_SOURCE)
        if self._disable_from_empty then
            self:enable()
        end
        self:_request_tick()
    end
end

function DanmakuOsdRender:remove_source(source)
    debug_msgf('DanmakuOsdRender:remove_source(%s)', source.id)
    if self._source_map[source.id] == nil then
        mp.msg.warn('DanmakuOsdRender: cannot remove not exists source', source.id, source.name)
    else
        self._source_map[source.id] = nil
        self:_invalidate(INVALIDATE_SOURCE)
        self:_request_tick()
    end
end

function DanmakuOsdRender:enable_source(source)
    debug_msgf('DanmakuOsdRender:enable_source(%s)', source.id)
    local s = self._source_map[source.id]
    if s ~= nil and not s.enable then
        s.enable = true
        self:_invalidate(INVALIDATE_SOURCE)
        if self._disable_from_empty then
            self:enable()
        end
        self:_request_tick()
    end
end

function DanmakuOsdRender:disable_source(source)
    debug_msgf('DanmakuOsdRender:disable_source(%s)', source.id)
    local s = self._source_map[source.id]
    if s ~= nil and s.enable then
        s.enable = false
        self:_invalidate(INVALIDATE_SOURCE)
        self:_request_tick()
    end
end

function DanmakuOsdRender:set_source_delay(source, delay)
    debug_msgf('DanmakuOsdRender:set_source_delay(%s, %.2f)', source.id, delay)
    local s = self._source_map[source.id]
    if s ~= nil then
        s.source.delay = delay
        for _, d in ipairs(s.data) do
            d.delay = delay
        end
        self:_invalidate(INVALIDATE_SOURCE, INVALIDATE_PREPARE)
        self:_request_tick()
    end
end

function DanmakuOsdRender:get_sources(enable)
    local rv = {}
    for _, s in pairs(self._source_map) do
        if enable == nil or enable == s.enable then
            table.insert(rv, s.source)
        end
    end
    return rv
end

function DanmakuOsdRender:get_source(id)
    return self._source_map[id]
end

---@param opts Partial<RenderOptions>
function DanmakuOsdRender:update_options(opts)
    local invalidate_map = {}
    local finals = {}
    for k, v in pairs(opts) do
        if self._render_opts[k] == nil then
            mp.msg.warn('DanmakuOsdRender update_options: unknown option', k)
        end
        ---@diagnostic disable-next-line: undefined-field
        local target_typ = type(self._render_opts[k])
        local typ = type(v)
        if target_typ ~= typ then
            mp.msg.warn('DanmakuOsdRender update_options: type mismatch for', k, 
                'expect', target_typ,
                'got', typ)
        else
            ---@cast k keyof RenderOptions
            self:_update_option(k, v, invalidate_map, finals)
        end
    end

    if #finals > 0 then
        for _, fn in ipairs(finals) do
            fn()
        end
    end

    if next(invalidate_map) ~= nil then
        local invalidate_t = {}
        for e, _ in pairs(invalidate_map) do
            table.insert(invalidate_t, e)
        end
        self:_invalidate(table.unpack(invalidate_t))
    end

    self:_request_tick()
end

---@type table<keyof RenderOptions, _option_update_dispatch_cb>
local option_update_dispatch_map
do
    ---@alias _option_update_dispatch_cb fun(
    ---     self: DanmakuOsdRender, 
    ---     map: table<INVALIDATE_TYPE, true>, 
    ---     val: any,
    ---     finals: function[]
    --- )
    ---@type table<string, _option_update_dispatch_cb>
    local helper = {}
    function helper.prepare(self, map, val)
        map[INVALIDATE_PREPARE] = true
    end
    function helper.layout(self, map, val)
        map[INVALIDATE_LAYOUT] = true
    end
    function helper.ass(self, map, val)
        map[INVALIDATE_ASS] = true
    end

    option_update_dispatch_map = {
        fontname = helper.ass,
        opacity = helper.ass,
        shadow = helper.ass,
        border = helper.ass,
        outline = helper.ass,
        scrolltime = helper.prepare,
        fixedtime = helper.prepare,
        density = helper.layout,
        max_screen_danmaku = helper.layout,
        fontsize = function(self, map, val)
            if self._render_ctx ~= nil then
                local screen = self._render_ctx.screen
                screen.fixed:_update("height", val)
                screen.scroll:_update("height", val)
            end
            map[INVALIDATE_LAYOUT] = true
            map[INVALIDATE_ASS] = true
        end,
        displayarea = function(self, map, val, finals)
            if self._render_ctx ~= nil then
                local screen = self._render_ctx.screen
                table.insert(finals, function()
                    local max = get_max_tracks(val, self._render_opts.res_y, self._render_opts.fontsize)
                    screen.fixed:_update("max_tracks", max)
                    screen.scroll:_update("max_tracks", max)
                end)
            end
            map[INVALIDATE_LAYOUT] = true
        end,
        follow_scale = function(self, map, val, finals)
            table.insert(finals, function()
                local max_tracks
                local function try_update_max_tracks()
                    local screen = self._render_ctx.screen
                    local max = get_max_tracks(self._render_opts.displayarea, self._render_opts.res_y, self._render_opts.fontsize)
                    if screen.scroll.max_tracks ~= max then
                        screen.scroll:_update("max_tracks", max)
                    end
                    if screen.fixed.max_tracks ~= max then
                        screen.fixed:_update("max_tracks", max)
                    end
                end
                if val and self._render_opts.res_y ~= self.res_y then
                    self._render_opts.res_y = self.res_y
                    try_update_max_tracks()
                    map[INVALIDATE_LAYOUT] = true
                elseif not val and self.osd_h ~= self._render_opts.res_y then
                    self._render_opts.res_y = self.osd_h
                    try_update_max_tracks()
                    map[INVALIDATE_LAYOUT] = true
                end
            end)
        end,
        res_x = function(self, map, val)
            self['res_x']= val
            if self._render_ctx ~= nil then
                local screen = self._render_ctx.screen
                screen.scroll:_update('res_x', val)
                screen.fixed:_update('res_x', val)
            end
            map[INVALIDATE_LAYOUT] = true
        end,
        res_y = function(self, map, val, finals)
            self['res_y']= val
            if self._render_opts ~= nil and self._render_opts.follow_scale then
                -- if res_y and final follow_scale
                table.insert(finals, function()
                    self._render_opts.res_y = val
                end)
                if self._render_ctx ~= nil then
                    local screen = self._render_ctx.screen
                    screen.scroll:_update('res_y', val)
                    screen.fixed:_update('res_y', val)
                end
                map[INVALIDATE_LAYOUT] = true
            end
        end,
    }
end

---@param key keyof RenderOptions
---@param val any
---@param invalidate_map table<INVALIDATE_TYPE, true>
---@param finals function[]
function DanmakuOsdRender:_update_option(key, val, invalidate_map, finals)
    debug_msgf('DanmakuOsdRender:_update_option(%s, %s)', key, val)
    option_update_dispatch_map[key](self, invalidate_map, val, finals)
    self._render_opts[key] = val
end

function DanmakuOsdRender:_on_options_change(changes)
    local change_t = {}
    for _, change in ipairs(changes) do
        change_t[change] = options[change]
    end
    self:update_options(change_t)
end

-- Note: call in _render may not work caused by pause
-- -> set pause after event:wait() in asyncio event loop
-- -> _render call _request_tick()
-- -> _event:clear()
function DanmakuOsdRender:_request_tick()
    if self.is_enable then
        self._event:set()
    end
end

---@alias _IdxMap table<int, int>

---@alias _SlicedDanmaku {
---     scroll:  table<int, _CalcedOsdRenderDanmaku[] & { idx_map: _IdxMap }> & {global_idx_list: int[]},
---     fixed: table<int, _CalcedOsdRenderDanmaku[] & { idx_map: _IdxMap }> & {global_idx_list: int[]}
--- }

---@param danmakus _CalcedOsdRenderDanmaku[]
---@param slice int
---@return _SlicedDanmaku
local function build_sliced(danmakus, slice)
    ---@type _SlicedDanmaku
    local result = { scroll = { global_idx_list = {} }, fixed = { global_idx_list = {} } }
    local insert = table.insert
    for idx, d in ipairs(danmakus) do
        local r
        if d.type == 0 then
            r = result.scroll
        else
            r = result.fixed
        end
        insert(r.global_idx_list, idx)
        local pos_start = math.floor(d.start_time / slice)
        local pos_end   = math.floor(d.end_time / slice)
        for i = pos_start, pos_end do
            local s = r[i]
            if s == nil then
                s = { idx_map = {} }
                r[i] = s
            end
            ---@diagnostic disable-next-line: param-type-mismatch
            insert(s, d)
            s.idx_map[#s] = #r.global_idx_list
        end
    end
    debug_msgf('build_sliced scroll: %d fixed: %d', #result.scroll.global_idx_list, #result.fixed.global_idx_list)
    return result
end

---@param danmakus _OsdRenderingDanmaku[]
---@param scrolltime number
---@param fixedtime number
---@param force boolean?
local function prepare_danmakus(danmakus, scrolltime, fixedtime, force)
    for _, d in ipairs(danmakus) do
        if force or d.prepared ~= true then
            algo.prepare(d, scrolltime, fixedtime)
        end
    end
    ---@diagnostic disable-next-line: param-type-mismatch
    table.sort(danmakus, function(a, b)
        return a.start_time < b.start_time
    end)
end

function DanmakuOsdRender:_render()
    -- debug_msg('DanmakuOsdRender:_render()')

    local slice = RENDER_SLICE
    local opts = self._render_opts
    local ctx = self._render_ctx
    local insert = table.insert

    if self._source_dirty then
        ctx.danmakus = {}
        for _, st in pairs(self._source_map) do
            local c = 0
            if st.enable then
                for _, d in ipairs(st.data) do
                    if d.enable ~= false then
                        insert(ctx.danmakus, d)
                        c = c + 1
                    end
                end
            end
            debug_msgf('DanmakuOsdRender:_render() source: (id: %s name: %s count: %d actual: %d)', 
                st.source.id, st.source.name, #st.data, c)
        end
        self._prepare_dirty = false
        prepare_danmakus(ctx.danmakus, opts.scrolltime, opts.fixedtime, false)
        if #ctx.danmakus <= 0 then
            -- no source enabled
            debug_msg('DanmakuOsdRender:_render() no danmaku prepared')
            self:disable(true)
            return
        end
        self._source_dirty = false
        ctx.sliced_dirty = true
    end

    if self._prepare_dirty then
        prepare_danmakus(ctx.danmakus, opts.scrolltime, opts.fixedtime, true)
    end

    if ctx.sliced_dirty ~= false then
        ctx.sliced = build_sliced(ctx.danmakus, slice)
        ctx.sliced_dirty = false
    end

    local pos = mp.get_property_number("time-pos")
    if pos == nil then
        mp.msg.warn("cannot get current time-pos, danmaku render disabled.")
        self:disable()
        return
    end
    local sliced_pos = math.floor(pos / slice)
    -- debug_msgf("DanmakuOsdRender:_render() pos: %d %d", pos, sliced_pos)
    local scroll_danmakus = ctx.sliced.scroll[sliced_pos]
    local fixed_danmakus = ctx.sliced.fixed[sliced_pos]
    local l = 0
    if scroll_danmakus ~= nil then
        l = l + #scroll_danmakus
    end
    if fixed_danmakus ~= nil then
        l = l + #fixed_danmakus
    end
    if (scroll_danmakus == nil and fixed_danmakus == nil) or l <= 0 then
        -- debug_msg("DanmakuOsdRender:_render() no danmakus in current window")
        ctx.overlay:remove()
        self.is_rendering = false
        return
    end
    local ass_events = {}
    if scroll_danmakus ~= nil then
        self:_render_ass(pos, sliced_pos, ass_events, true)
    end
    if fixed_danmakus ~= nil then
        self:_render_ass(pos, sliced_pos, ass_events, false)
    end
    -- debug_msgf("DanmakuOsdRender:_render() ass_events: %d", #ass_events)
    if #ass_events > 0 then
        ctx.overlay.res_x = opts.res_x
        ctx.overlay.res_y = opts.res_y
        ctx.overlay.data = table.concat(ass_events, "\n")
        ctx.overlay:update()
        self.is_rendering = true
    else
        ctx.overlay:remove()
        self.is_rendering = false
    end
end

---@param pos number
---@param sliced_pos int,
---@param ass_events string[]
---@param is_scroll boolean
function DanmakuOsdRender:_render_ass(pos, sliced_pos, ass_events, is_scroll)
    local str_fmt = string.format
    local insert = table.insert
    local opts = self._render_opts
    local ctx = self._render_ctx
    local danmakus = is_scroll and ctx.sliced.scroll[sliced_pos] or ctx.sliced.fixed[sliced_pos]
    local global_idx_list = is_scroll and ctx.sliced.scroll.global_idx_list or ctx.sliced.fixed.global_idx_list
    local idx_map = danmakus.idx_map
    local all_danmakus = ctx.danmakus
    -- debug_msg('DanmakuOsdRender:_render_ass()')
    for i, d in ipairs(danmakus) do
        ---@cast d _CalcedOsdRenderDanmaku
        -- debug_msgf('DanmakuOsdRender:_render_ass() time(%.5f, %.5f) %s', d.start_time, d.end_time, d.escaped_text)
        if d.start_time > pos then
            break
        elseif d.end_time >= pos then
            local idx = idx_map[i]
            local offset = is_scroll and ctx.calc_offset_scroll or ctx.calc_offset_fixed
            if offset <= idx then
                for _i = offset, idx do
                    ---@type _CalcedOsdRenderDanmaku
                    local _d = all_danmakus[global_idx_list[_i]--[[@cast -?]]]
                    -- force layout_dirty
                    _d.layout_dirty = true
                    ---@diagnostic disable-next-line: param-type-mismatch
                    algo.calc_danmaku(_d, ctx.screen, opts)
                end
                if is_scroll then
                    ctx.calc_offset_scroll = idx + 1
                else
                    ctx.calc_offset_fixed = idx + 1
                end
            end

            -- debug_msgf('DanmakuOsdRender:_render_ass() time(%.2f, %.2f) %s type: %d move: %s', 
                -- d.start_time, d.end_time, d.escaped_text, d.type, d.is_move)

            if d.layout_dirty ~= false or d.is_move == nil then
                -- continue
            else
                local ass_text
                if d.ass_dirty ~= false then
                    d.ass_text = str_fmt(
                        "{fn%s\\fs%d\\c&H%s&\\alpha&H%s\\bord%s\\shad%s\\b%s\\q2}%s",
                        opts.fontname,
                        opts.fontsize,
                        d.color,
                        str_fmt("%02X", (1 - opts.opacity) * 255),
                        opts.outline,
                        opts.shadow,
                        opts.border,
                        d.escaped_text
                    )
                    d.ass_dirty = false
                end
                if d.is_move then
                    local move = d.move
                    ---@cast move -?
                    local progress = (pos - d.start_time) / opts.scrolltime
                    ass_text = str_fmt(
                        "{\\pos(%.1f,%.1f)\\an7}%s",
                        move.x1 + (move.x2 - move.x1) * progress,
                        move.y1 + (move.y2 - move.y1) * progress,
                        d.ass_text
                    )
                else
                    local d_pos = d.pos
                    ---@cast d_pos -?
                    ass_text = str_fmt(
                        "{\\pos(%.1f,%.1f)\\an8}%s",
                        d_pos.x,
                        d_pos.y,
                        d.ass_text
                    )
                end
                insert(ass_events, ass_text)
                if opts.max_screen_danmaku > 0 and #ass_events >= opts.max_screen_danmaku then
                    break
                end
            end
        end
    end
end


---@param ... INVALIDATE_TYPE
function DanmakuOsdRender:_invalidate(...)
    if not self.is_running then
        return
    end
    local args = {...}
    if #args <= 0 then
        return
    end
    local set = {}
    debug_msg(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        return string.format("DanmakuOsdRender:_invalidate(%s)", fun.str_concat(fun.map(function(x)
            return _INVALIDATE_STR_MAP[x]
        end, args), ', '))
    end)
    local function add_inline(n)
        if set[n] == nil then
            args[#args+1] = n
            set[n] = true
        end
    end
    for i = 1, #args do
        set[args[i]] = true
    end
    local ctx = self._render_ctx
    local danmaku_fields = {}
    local i = 1
    while i <= #args do
        local n = args[i]
        -- SOURCE
        if n == INVALIDATE_SOURCE then
            self._source_dirty = true
            add_inline(INVALIDATE_LAYOUT)
        -- PREPARE
        elseif n == INVALIDATE_PREPARE then
            self._prepare_dirty = true
            add_inline(INVALIDATE_LAYOUT)
            danmaku_fields['prepared'] = false
        -- LAYOUT
        elseif n == INVALIDATE_LAYOUT then
            ctx.calc_offset_scroll = 1
            ctx.calc_offset_fixed = 1
            ctx.screen.scroll:clear()
            ctx.screen.fixed:clear()
            danmaku_fields['layout_dirty'] = true
        -- ASS
        elseif n == INVALIDATE_ASS then
            danmaku_fields['ass_dirty'] = true
        else
            mp.msg.warn('DanmakuOsdRender:_invalidate got unknown invalidate type', n)
        end
        i = i--[[@cast -?]] + 1
    end

    for field, val in pairs(danmaku_fields) do
        for _, d in ipairs(ctx.danmakus) do
            ---@diagnostic disable-next-line: inject-field
            d[field] = val
        end
    end

    self:_request_tick()
end

function DanmakuOsdRender:_handle_render_err(from_stop)
    local err = self._render_task_err ~= nil
    if err then
        mp.msg.error('DanmakuOsdRender error,', self._render_task_err)
        self._render_task_err = nil
        if not from_stop then
            self:stop()
        end
    end
    return err
end

function DanmakuOsdRender:_on_pause(pause)
    if pause ~= nil and pause ~= self.pause then
        if not pause then
            self:_request_tick()
        end
        self.pause = pause
    end
end

function DanmakuOsdRender:_on_playback_restart()
    self:_request_tick()
end

function DanmakuOsdRender:_on_display_fps(fps)
    if fps ~= nil and fps ~= self.fps then
        self.refresh_tick = 1 / fps
        self.fps = fps
        self:_remove_vf_fps()
        self:_add_vf_fps()
    end
end

function DanmakuOsdRender:_on_osd_dimentions(osd)
    if osd ~= nil then
        self.osd_w = osd.w
        self.osd_h = osd.h
        local render_opts = self._render_opts
        local ctx = self._render_ctx
        if not render_opts.follow_scale then
            if render_opts.res_y ~= osd.h then
                render_opts.res_y = osd.h
                ctx.screen.scroll:_update("res_y", osd.h)
                ctx.screen.fixed:_update("res_y", osd.h)
                if render_opts.displayarea > 0 and render_opts.displayarea < 1 then
                    local max_tracks = get_max_tracks(render_opts.displayarea, osd.h, render_opts.fontsize)
                    ctx.screen.scroll:_update("max_tracks", max_tracks)
                    ctx.screen.fixed:_update("max_tracks", max_tracks)
                end
                self:_invalidate(INVALIDATE_LAYOUT)
            end
        end
        self:_request_tick()
    end
end

function DanmakuOsdRender:_register_events()
    if self._on_pause_f == nil then
        self._on_pause_f = function(_, pause) self:_on_pause(pause) end
    end
    if self._on_display_fps_f == nil then
        self._on_display_fps_f = function (_, fps) self:_on_display_fps(fps) end
    end
    if self._on_osd_dimentions_f == nil then
        self._on_osd_dimentions_f = function (_, osd) self:_on_osd_dimentions(osd) end
    end
    if self._on_playback_restart_f == nil then
        self._on_playback_restart_f = function() self:_on_playback_restart() end
    end
    amp.observe_property('pause', 'bool', self._on_pause_f)
    amp.observe_property('display-fps', 'number', self._on_display_fps_f)
    amp.observe_property('osd-dimensions', 'native', self._on_osd_dimentions_f)
    amp.register_event('playback-restart', self._on_playback_restart_f)

    if self._on_options_change_f == nil then
        self._on_options_change_f = function(changes) self:_on_options_change(changes) end
    end
    options.on_options_change(self._options_keys, self._on_options_change_f)
end

function DanmakuOsdRender:_unregister_events()
    if self._on_pause_f ~= nil then
        amp.unobserve_property(self._on_pause_f)
    end
    if self._on_display_fps_f ~= nil then
        amp.unobserve_property(self._on_display_fps_f)
    end
    if self._on_osd_dimentions_f ~= nil then
        amp.unobserve_property(self._on_osd_dimentions_f)
    end
    if self._on_playback_restart_f ~= nil then
        amp.unregister_event(self._on_playback_restart_f)
    end
    if self._on_options_change_f ~= nil then
        options.unregister(self._on_options_change_f)
    end
end

function DanmakuOsdRender:_add_vf_fps()
    mp.commandv("vf", "append", string.format("@danmakulx:fps=%d", self.fps or 120))
end

function DanmakuOsdRender:_remove_vf_fps()
    mp.commandv("vf", "remove", "@danmakulx")
end

function DanmakuOsdRender:__gc()
    if self.is_running then
        self:stop()
    end
end

return DanmakuOsdRender
