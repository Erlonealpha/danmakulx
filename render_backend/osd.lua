local mp = require 'mp'
local std = require 'elxlibs.std'
local asyncio = require 'elxlibs.asyncio'
local amp = require 'elxlibs.asyncio.amp'
local locks = require 'elxlibs.asyncio.locks'
local algo = require 'modules/layout_algo'
local utils = require 'modules/utils'
local options = require 'modules.options'
local base = require 'render_backend/_base'


local RENDER_SLICE = 30


local function get_max_tracks(display_area, res_y, height)
    return math.floor(display_area * res_y / height)
end

---@alias _OsdRenderingDanmaku Danmaku & Partial<_PreparedT> & _CalcedT

---@class DanmakuOsdRender : DanmakuRenderBackend
---@field _render_ctx {
---     dirty: boolean,
---     calc_offset_scroll: int,
---     calc_offset_fixed: int,
---     screen: DanmakuScreen,
---     danmakus: _CalcedDanmaku[],
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
end

function DanmakuOsdRender:_init()
    debug_msg('DanmakuOsdRender:_init()')
    self.is_running = false
    self.is_rendering = false
    self.is_enable = true
    self._source_dirty = true

    self.pause = mp.get_property_bool('pause')
    self.fps = mp.get_property_number('display-fps', 120)
    local osd = mp.get_property_native('osd-dimensions')
    self.osd_w = osd.w
    self.osd_h = osd.h
    self.refresh_tick = 1 / self.fps

    ---@type OsdRenderOptions
    local render_opts = base.get_optinos()
    self._render_opts = render_opts
    self._options_keys = {}
    for k, _ in pairs(render_opts) do
        table.insert(self._options_keys, k)
    end
    self.res_x = render_opts.res_x
    self.res_y = render_opts.res_y
    if not render_opts.follow_scale and self.osd_h then
        render_opts.res_y = self.osd_h
    end

    local max_tracks
    if render_opts.displayarea < 1 and render_opts.displayarea > 0 then
        max_tracks = get_max_tracks(render_opts.displayarea, self.res_y, render_opts.fontsize)
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
        dirty = true,
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

function DanmakuOsdRender:add_source(source, data)
    debug_msgf('DanmakuOsdRender:add_source(%s, %d)', source.id, #data)
    if self._source_map[source.id] ~= nil then
        -- Warn or opts.dup_source_handle(update or others)
        mp.msg.warn('DanmakuOsdRender: added duplicate source')
    else
        self._source_map[source.id] = {source = source, data = data, enable = true}
        self._source_dirty = true
        self:_calc_dirty()
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
        self._source_dirty = true
        self:_calc_dirty()
        self:_request_tick()
    end
end

function DanmakuOsdRender:enable_source(source)
    debug_msgf('DanmakuOsdRender:enable_source(%s)', source.id)
    local s = self._source_map[source.id]
    if s ~= nil and not s.enable then
        s.enable = true
        self._source_dirty = true
        self:_calc_dirty()
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
        self._source_dirty = true
        self:_calc_dirty()
        self:_request_tick()
    end
end

function DanmakuOsdRender:set_source_delay(source, delay)
    debug_msgf('DanmakuOsdRender:set_source_delay(%s, %.2f)', source.id, delay)
    local s = self._source_map[source.id]
    if s ~= nil then
        s.source.delay = delay
        self:_all_dirty()
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

---@param opts Partial<OsdRenderOptions>
function DanmakuOsdRender:update_options(opts)
    for k, v in pairs(opts) do
        if self._render_opts[k] == nil then
            mp.msg.warn('DanmakuOsdRender update_options: unknown option', k)
        elseif type(self._render_opts[k]) ~= type(v) then
            mp.msg.warn('DanmakuOsdRender update_options: type mismatch for', k, 
                ---@diagnostic disable-next-line: undefined-field
                'expect', type(self._render_opts[k]),
                'got', type(v))
        else
            self:_update_option(k, v)
        end
    end
end

function DanmakuOsdRender:_request_tick()
    if self.is_enable then
        self._event:set()
    end
end

---@param key string
---@param val any
function DanmakuOsdRender:_update_option(key, val)
    debug_msgf('DanmakuOsdRender:_update_option(%s, %s)', key, val)
    if key == 'res_x' then
        self.res_x = val
        self:_res_x_dirty(val)
    elseif key == 'res_y' then
        self.res_y = val
        if self._render_opts.follow_scale and val ~= self._render_opts.res_y then
            self:_res_y_dirty(val)
        end
    elseif key == "scrolltime" or key == "fixedtime" or key == "density" then
        self:_all_dirty()
    elseif key == "fontsize" then
        self._render_ctx.screen.fixed:_update("height", val)
        self._render_ctx.screen.scroll:_update("height", val)
        self:_all_dirty()
    elseif key == "displayarea" then
        local max = get_max_tracks(val, self._render_opts.res_y, self._render_opts.fontsize)
        self._render_ctx.screen.fixed:_update("max_tracks", max)
        self._render_ctx.screen.scroll:_update("max_tracks", max)
        self:_all_dirty()
    elseif key == "follow_scale" then
        if val and self._render_opts.res_y ~= self.res_y then
            self:_res_y_dirty(self.res_y)
        end
    else
        self:_st_dirty()
    end
    self._render_opts[key] = val
    self:_request_tick()
end

function DanmakuOsdRender:_on_options_change(changes)
    for _, change in ipairs(changes) do
        self:_update_option(change, options[change])
    end
end

---@alias _IdxMap table<int, int>

---@alias _SlicedDanmaku {
---     scroll:  table<int, _CalcedDanmaku[] & { idx_map: _IdxMap }> & {global_idx_list: int[]},
---     fixed: table<int, _CalcedDanmaku[] & { idx_map: _IdxMap }> & {global_idx_list: int[]}
--- }

---@param danmakus _CalcedDanmaku[]
---@param slice int
---@return _SlicedDanmaku
local function build_sliced(danmakus, slice)
    ---@type _SlicedDanmaku
    local result = { scroll = { global_idx_list = {} }, fixed = { global_idx_list = {} } }
    local insert = table.insert
    for idx, d in ipairs(danmakus) do
        local r
        if d.type < 4 then
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

---@alias _CalcedOsdRenderDanmaku _CalcedDanmaku & { st_text?: string, st_dirty: boolean }

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
                        if st.source.delay ~= nil then
                            d.delay = st.source.delay
                        end
                        if d._prepared ~= true then
                            algo.prepare(d, opts.scrolltime, opts.fixedtime)
                        end
                        if d._prepared then
                            ---@diagnostic disable-next-line: inject-field
                            ---@cast d _PreparedDanmaku
                            insert(ctx.danmakus, d)
                            c = c + 1
                        end
                    end
                end
            end
            debug_msgf('DanmakuOsdRender:_render() source: (id: %s name: %s count: %d actual: %d)', 
                st.source.id, st.source.name, #st.data, c)
        end
        if #ctx.danmakus <= 0 then
            -- no source enabled
            debug_msg('DanmakuOsdRender:_render() no danmaku prepared')
            self:disable(true)
            return
        end
        ---@diagnostic disable-next-line: param-type-mismatch
        table.sort(ctx.danmakus, function(a, b)
            return a.time < b.time
        end)
        self._source_dirty = false
        ctx.dirty = true
    end
    if ctx.dirty then
        ctx.sliced = build_sliced(ctx.danmakus, slice)
        ctx.dirty = false
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
        if pos >= d.start_time and pos <= d.end_time then
            local idx = idx_map[i]
            local offset = is_scroll and ctx.calc_offset_scroll or ctx.calc_offset_fixed
            if offset <= idx then
                for _i = offset, idx do
                    ---@type _CalcedDanmaku
                    local _d = all_danmakus[global_idx_list[_i]--[[@cast -?]]]
                    _d._dirty = true
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
            if d.is_move ~= nil then
                local ass_text
                if d.st_dirty ~= false then
                    local b, g, r = utils.hex_rgb2bgr(d.color)
                    d.st_text = str_fmt(
                        "{fn%s\\fs%d\\c&H%s%s%s&\\alpha&H%s\\bord%s\\shad%s\\b%s\\q2}%s",
                        opts.fontname,
                        opts.fontsize,
                        b, g, r,
                        str_fmt("%02X", (1 - opts.opacity) * 255),
                        opts.outline,
                        opts.shadow,
                        opts.border,
                        d.escaped_text
                    )
                    d.st_dirty = false
                end
                if d.is_move then
                    local move = d.move
                    ---@cast move -?
                    local progress = (pos - d.start_time) / opts.scrolltime
                    ass_text = str_fmt(
                        "{\\pos(%.1f,%.1f)\\an7}%s",
                        move.x1 + (move.x2 - move.x1) * progress,
                        move.y1 + (move.y2 - move.y1) * progress,
                        d.st_text
                    )
                else
                    local d_pos = d.pos
                    ---@cast d_pos -?
                    ass_text = str_fmt(
                        "{\\pos(%.1f,%.1f)\\an8}%s",
                        d_pos.x,
                        d_pos.y,
                        d.st_text
                    )
                end
                insert(ass_events, ass_text)
            end
        end
    end
end

function DanmakuOsdRender:_all_dirty()
    local ctx = self._render_ctx
    self._source_dirty = true
    for _, d in ipairs(ctx.danmakus) do
        d._prepared = false
        d._dirty = true
        d.is_move = nil
        ---@diagnostic disable-next-line: inject-field
        d._st_dirty = true
    end
    self:_calc_dirty()
end

function DanmakuOsdRender:_st_dirty()
    local ctx = self._render_ctx
    for _, d in ipairs(ctx.danmakus) do
        ---@diagnostic disable-next-line: inject-field
        d._st_dirty = true
    end
end

---@param res_x number
function DanmakuOsdRender:_res_x_dirty(res_x)
    self._render_opts.res_x = res_x
    local ctx = self._render_ctx
    ctx.screen.scroll:_update("res_x", res_x)
    ctx.screen.fixed:_update("res_x", res_x)
    self:_all_dirty()
end

---@param res_y number
function DanmakuOsdRender:_res_y_dirty(res_y)
    self._render_opts.res_y = res_y
    local ctx = self._render_ctx
    ctx.screen.scroll:_update("res_y", res_y)
    ctx.screen.fixed:_update("res_y", res_y)
    self:_all_dirty()
end

function DanmakuOsdRender:_calc_dirty()
    self:_calc_scroll_dirty()
    self:_calc_fixed_dirty()
end

function DanmakuOsdRender:_calc_scroll_dirty()
    local ctx = self._render_ctx
    ctx.calc_offset_scroll = 1
    ctx.screen.scroll:clear()
end

function DanmakuOsdRender:_calc_fixed_dirty()
    local ctx = self._render_ctx
    ctx.calc_offset_fixed = 1
    ctx.screen.fixed:clear()
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
        if not self._render_opts.follow_scale then
            if self._render_opts.res_y ~= osd.h then
                self:_res_y_dirty(osd.h)
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
    mp.commandv("vf", "append", string.format("@danmakulx:fps=fps=%d", self.fps or 120))
end

function DanmakuOsdRender:_remove_vf_fps()
    mp.commandv("vf", "remove", "@danmakulx")
end

return DanmakuOsdRender
