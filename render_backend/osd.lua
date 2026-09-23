local mp = require 'mp'
local std = require 'elxlibs.std'
local asyncio = require 'elxlibs.asyncio'
local locks = require 'elxlibs.asyncio.locks'
local algo = require 'modules.layout_algo'
local base = require 'render_backend._base'


local RENDER_SLICE = 30


local function get_max_tracks(display_area, res_y, height)
    return math.floor(display_area * res_y / height)
end

---@alias _OsdRenderingDanmaku Danmaku & Partial<_PreparedT> & _CalcedT
---@alias _CalcedOsdRenderDanmaku _CalcedDanmaku & { ass_text?: string, ass_dirty?: boolean }

---@class OsdRenderContext : RenderContext<DanmakuOsdRender>
---@field render DanmakuOsdRender
---@field options RenderOptions
---@field danmakus _CalcedOsdRenderDanmaku[]
---@field sliced _SlicedDanmaku?
---@field overlay mp_osd_overlay?
---@overload fun(render: DanmakuOsdRender):self
local OsdRenderContext = std.class.new('OsdRenderContext', {base.RenderContext})
---@param render DanmakuOsdRender
function OsdRenderContext:__init(render)
    debug_msgf("OsdRenderContext:__init(%s)", render)
    std.super(OsdRenderContext, self, base.RenderContext):__init(render)
    self.refresh_tick = 1 / 60
    self.source_dirty = true
    self.prepare_dirty = true
    self.sliced_dirty = true
    self.calc_offset_scroll = 1
    self.calc_offset_fixed = 1
    self.sliced = nil
    self.overlay = nil
end

function OsdRenderContext:start()
    local opts = self.options
    self.pause = mp.get_property_bool('pause')
    self.fps = mp.get_property_number('display-fps', 120)
    local osd = mp.get_property_native('osd-dimensions')
    self.osd_w = osd.w
    self.osd_h = osd.h
    self.refresh_tick = 1 / self.fps
    self.res_x = opts.res_x
    --    self.res_y: base, can only changed by user
    -- options.res_y: can changed by state change (effective)
    self.res_y = opts.res_y
    if not opts.follow_scale and self.osd_h then
        opts.res_y = self.osd_h
    end
    self.screen = algo.new_screen(
        self.res_x, 
        self.res_y, 
        opts.fontsize, 
        (opts.displayarea < 1 and opts.displayarea > 0)
            and get_max_tracks(opts.displayarea, opts.res_y, opts.fontsize) 
            or nil
    )
    self.overlay = mp.create_osd_overlay("ass-events")
    std.super(OsdRenderContext, self, base.RenderContext):start()
end

function OsdRenderContext:stop()
    std.super(OsdRenderContext, self, base.RenderContext):stop()
    self.source_dirty = true
    self.prepare_dirty = true
    self.sliced_dirty = true
    self.calc_offset_scroll = 1
    self.calc_offset_fixed = 1
    self.sliced = nil
    self.danmakus = {}
    if self.overlay ~= nil then
        self.overlay:remove()
        self.overlay = nil
    end
end

---@class DanmakuOsdRender : DanmakuRenderBackend
---@field _render_task asyncio.Task<nil>?
---@field _render_task_err any?
---@field _source_map table<string, {source: SourceBase, data: _OsdRenderingDanmaku[], enable: boolean}>
---@overload fun():self
local DanmakuOsdRender = std.class.new("DanmakuOsdRender")

function DanmakuOsdRender:__init()
    debug_msg('DanmakuOsdRender:__init()')
    self.is_running = false
    self.is_rendering = false
    self.is_enable = true

    self._render_task = nil
    self._render_task_err = nil
    self._source_map = {}
end

function DanmakuOsdRender:_init()
    debug_msg('DanmakuOsdRender:_init()')
    self.is_running = false
    self.is_rendering = false
    self.is_enable = true

    if self.context == nil then
        self.context = OsdRenderContext(self)
    else
        -- sync options
        self.context:update_options()
    end

    self._event = locks.Event()
end

function DanmakuOsdRender:start()
    debug_msg('DanmakuOsdRender:start()')
    if self.is_running then
        mp.msg.warn('DanmakuOsdRender already started')
        return
    end

    self:_init()
    self.context:start()

    self._render_task = asyncio.create_task(function()
        local await = await
        local ctx = self.context
        local coro = async(function()
            local loop = asyncio.loops.get_running_loop()
            while true do
                if not self._event:is_set() then
                    -- debug_msg('DanmakuOsdRender:_render_task pre wait event')
                    await(self._event:wait())
                    -- debug_msg('DanmakuOsdRender:_render_task wait event done')
                end
                self:_render()
                if ctx.pause then
                    self._event:clear()
                end
                -- sleep
                local fut = loop:create_future()
                local handle = loop:call_later(ctx.refresh_tick, function()
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

    if self._render_task ~= nil then
        if not self._render_task:done() then
            self._render_task:cancel()
        end
        self._render_task = nil
    end
    self:_handle_render_err(true)
    self:_remove_vf_fps()

    self.context:stop()

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
    assert(self.context.overlay)
    self.context.overlay:remove()
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
    validate_danmakus(data)
    self._source_map[source.id] = {source = source, data = data, enable = true}
    if self._disable_from_empty then
        self:enable()
    end
    self:_invalidate(INVALIDATE_SOURCE)
end

function DanmakuOsdRender:add_source_batch(batch)
    
end

function DanmakuOsdRender:remove_source(source)
    debug_msgf('DanmakuOsdRender:remove_source(%s)', source.id)
    if self._source_map[source.id] == nil then
        mp.msg.warn('DanmakuOsdRender: cannot remove not exists source', source.id, source.name)
    else
        self._source_map[source.id] = nil
        self:_invalidate(INVALIDATE_SOURCE)
    end
end

function DanmakuOsdRender:enable_source(source)
    debug_msgf('DanmakuOsdRender:enable_source(%s)', source.id)
    local s = self._source_map[source.id]
    if s ~= nil and not s.enable then
        s.enable = true
        if self._disable_from_empty then
            self:enable()
        end
        self:_invalidate(INVALIDATE_SOURCE)
    end
end

function DanmakuOsdRender:disable_source(source)
    debug_msgf('DanmakuOsdRender:disable_source(%s)', source.id)
    local s = self._source_map[source.id]
    if s ~= nil and s.enable then
        s.enable = false
        self:_invalidate(INVALIDATE_SOURCE)
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
    self.context:update_options(opts)
    self:_request_tick()
end

-- Note: call in _render may not work caused by pause
-- -> set pause after event:wait() in asyncio event loop
-- -> _render call _request_tick()
-- -> _event:clear()
function DanmakuOsdRender:_request_tick()
    if self.is_enable and not self:_handle_render_err() then
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
    local ctx = self.context
    local opts = ctx.options
    local insert = table.insert

    if ctx.source_dirty then
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
        ctx.prepare_dirty = false
        prepare_danmakus(ctx.danmakus, opts.scrolltime, opts.fixedtime, false)
        if #ctx.danmakus <= 0 then
            -- no source enabled
            debug_msg('DanmakuOsdRender:_render() no danmaku prepared')
            self:disable(true)
            return
        end
        ctx.source_dirty = false
        ctx.sliced_dirty = true
    end

    if ctx.prepare_dirty then
        prepare_danmakus(ctx.danmakus, opts.scrolltime, opts.fixedtime, true)
    end

    if ctx.sliced_dirty ~= false then
        ctx.sliced = build_sliced(ctx.danmakus, slice)
        ctx.sliced_dirty = false
    end
    ---@cast ctx.sliced -?
    ---@cast ctx.overlay -?

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
    local ctx = self.context
    local opts = ctx.options
    ---@cast ctx.sliced -?
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
    self.context:invalidate(...)
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

function DanmakuOsdRender:_add_vf_fps()
    mp.commandv("vf", "append", string.format("@danmakulx:fps=%d", self.context.fps or 120))
end

function DanmakuOsdRender:_remove_vf_fps()
    mp.commandv("vf", "remove", "@danmakulx")
end

function DanmakuOsdRender:__gc()
    if self.is_running then
        self:stop()
    end
end


---@type table<INVALIDATE_TYPE, fun(
---     self: OsdRenderContext, 
---     danmaku_fields: table<keyof _CalcedOsdRenderDanmaku,any>, 
---     add_inline: fun(i: INVALIDATE_TYPE)
--- )>
local invalidate_dispatch_map = {
    [INVALIDATE_SOURCE] = function(self, danmaku_fields, add_inline)
        self.source_dirty = true
        add_inline(INVALIDATE_LAYOUT)
    end,
    [INVALIDATE_PREPARE] = function(self, danmaku_fields, add_inline)
        self.prepare_dirty = true
        danmaku_fields['prepared'] = false
        add_inline(INVALIDATE_LAYOUT)
    end,
    [INVALIDATE_LAYOUT] = function(self, danmaku_fields, add_inline)
        self.calc_offset_scroll = 1
        self.calc_offset_fixed = 1
        self.screen.scroll:clear()
        self.screen.fixed:clear()
        danmaku_fields['layout_dirty'] = true
    end,
    [INVALIDATE_ASS] = function(self, danmaku_fields, add_inline)
        danmaku_fields['ass_dirty'] = true
    end,
}

---@type table<keyof RenderOptions, fun(
---     self: OsdRenderContext, 
---     map: table<INVALIDATE_TYPE,true>, 
---     val: any, 
---     finals: function[]
--- )>
local option_update_dispatch_map
do
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
            if self ~= nil then
                local screen = self.screen
                screen.fixed:_update("height", val)
                screen.scroll:_update("height", val)
            end
            map[INVALIDATE_LAYOUT] = true
            map[INVALIDATE_ASS] = true
        end,
        displayarea = function(self, map, val, finals)
            local screen = self.screen
            table.insert(finals, function()
                local max = get_max_tracks(val, self.options.res_y, self.options.fontsize)
                screen.fixed:_update("max_tracks", max)
                screen.scroll:_update("max_tracks", max)
            end)
            map[INVALIDATE_LAYOUT] = true
        end,
        follow_scale = function(self, map, val, finals)
            table.insert(finals, function()
                local function try_update_max_tracks()
                    local screen = self.screen
                    local max = get_max_tracks(self.options.displayarea, self.options.res_y, self.options.fontsize)
                    if screen.scroll.max_tracks ~= max then
                        screen.scroll:_update("max_tracks", max)
                    end
                    if screen.fixed.max_tracks ~= max then
                        screen.fixed:_update("max_tracks", max)
                    end
                end
                if val and self.options.res_y ~= self.res_y then
                    self.options.res_y = self.res_y
                    try_update_max_tracks()
                    map[INVALIDATE_LAYOUT] = true
                elseif not val and self.osd_h ~= nil and self.osd_h ~= self.options.res_y then
                    self.options.res_y = self.osd_h
                    try_update_max_tracks()
                    map[INVALIDATE_LAYOUT] = true
                end
            end)
        end,
        res_x = function(self, map, val)
            self['res_x']= val
            local screen = self.screen
            screen.scroll:_update('res_x', val)
            screen.fixed:_update('res_x', val)
            map[INVALIDATE_LAYOUT] = true
        end,
        res_y = function(self, map, val, finals)
            self['res_y']= val
            if self.options ~= nil and self.options.follow_scale then
                -- if res_y and final follow_scale
                table.insert(finals, function()
                    self.options.res_y = val
                end)
                local screen = self.screen
                screen.scroll:_update('res_y', val)
                screen.fixed:_update('res_y', val)
                map[INVALIDATE_LAYOUT] = true
            end
        end,
    }
end

OsdRenderContext.option_update_dispatch_map = option_update_dispatch_map
OsdRenderContext.invalidate_dispatch_map = invalidate_dispatch_map

function OsdRenderContext:on_pause(pause)
    if pause ~= nil and pause ~= self.pause then
        if not pause then
            self.render:_request_tick()
        end
        self.pause = pause
    end
end

function OsdRenderContext:on_display_fps(fps)
    local render = self.render
    if fps ~= nil and fps ~= self.fps then
        self.refresh_tick = 1 / fps
        self.fps = fps
        render:_remove_vf_fps()
        render:_add_vf_fps()
    end
end

function OsdRenderContext:on_playback_restart()
    self.render:_request_tick()
end

function OsdRenderContext:on_osd_dimentions(osd)
    self.osd_w = osd.w
    self.osd_h = osd.h
    local opts = self.options
    if not opts.follow_scale then
        if opts.res_y ~= osd.h then
            opts.res_y = osd.h
            self.screen.scroll:_update("res_y", osd.h)
            self.screen.fixed:_update("res_y", osd.h)
            if opts.displayarea > 0 and opts.displayarea < 1 then
                local max_tracks = get_max_tracks(opts.displayarea, osd.h, opts.fontsize)
                self.screen.scroll:_update("max_tracks", max_tracks)
                self.screen.fixed:_update("max_tracks", max_tracks)
            end
            self.render:_invalidate(INVALIDATE_LAYOUT)
        end
    end
end

return DanmakuOsdRender
