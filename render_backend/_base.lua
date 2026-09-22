local mp = require 'mp'
local std = require 'elxlibs.std'
local amp = require 'elxlibs.asyncio.amp'
local fun = require 'elxlibs.fun'
local options = require 'modules.options'


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

---@interface DanmakuRenderBackend
---@field start fun(s: self)
---@field stop fun(s: self)
---@field enable fun(s: self)
---@field disable fun(s: self)
---@field enable_source fun(s: self, source: SourceBase)
---@field disable_source fun(s: self, source: SourceBase)
---@field set_source_delay fun(s: self, source: SourceBase, delay: number)
---@field add_source fun(s: self, source: SourceBase, data: Danmaku[])
---@field remove_source fun(s: self, source: SourceBase)
---@field get_sources fun(s: self, enable: boolean?):SourceBase[]
---@field get_source fun(s: self, id: string):{source: SourceBase, data: Danmaku[]}?
---@field update_options fun(s: self, opts: table)
---@field is_running boolean
---@field is_rendering boolean

local function parse_res(res_opt, def)
    if res_opt == "display-w" then
        return mp.get_property_number('display-width', 1920)
    elseif res_opt == 'display-h' then
        return mp.get_property_number('display-height', 1080)
    else
        return tonumber(res_opt) or def
    end
end

---@alias RenderOptions {
---     fontname: string,
---     scrolltime: number,
---     fixedtime: number,
---     fontsize: number,
---     border: boolean,
---     opacity: number,
---     shadow: number,
---     displayarea: number,
---     outline: number,
---     max_screen_danmaku: int,
---     density: string,
---     follow_scale: boolean,
---     res_x: number,
---     res_y: number,
--- }

local M = {}

---@return RenderOptions
function M.get_optinos()
    return {
        fontname = options.fontname,
        scrolltime = options.scrolltime,
        fixedtime = options.fixedtime,
        fontsize = options.fontsize,
        border = options.border,
        opacity = options.opacity,
        shadow = options.shadow,
        displayarea = options.displayarea,
        outline = options.outline,
        max_screen_danmaku = options.max_screen_danmaku,
        density = options.density,
        follow_scale = options.follow_scale,
        res_x = parse_res(options.res_x, 1920),
        res_y = parse_res(options.res_y, 1080),
    }
end

---@alias _option_update_dispatch_cb<C> fun(
---     self: C, 
---     map: table<INVALIDATE_TYPE, true>, 
---     val: any,
---     finals: function[]
--- )

---@alias _invalidate_dispatch_cb<C, D> fun(
---     self: C,
---     danmaku_fields: table<keyof D, any>,
---     add_inline: fun(i: INVALIDATE_TYPE)
--- )

---@interface IRenderContext<D> : std.object
---@field on_pause fun(s:self, pause:boolean)
---@field on_osd_dimentions fun(s:self, osd: {w: int, h: int})
---@field on_display_fps fun(s:self, fps:number)
---@field on_playback_restart fun(s:self)
---@field on_options_change fun(s:self, changes:string[])
---@field option_update_dispatch_map table<keyof RenderOptions, _option_update_dispatch_cb<self>>
---@field invalidate_dispatch_map table<INVALIDATE_TYPE, _invalidate_dispatch_cb<self, D>>

---@class RenderContext<Render, D=_CalcedDanmaku> : IRenderContext<D>
---@field render Render
---@field options RenderOptions
---@field danmakus Danmaku[]
---@overload fun(render: Render):self
local RenderContext = std.class.new("RenderContext")

M.RenderContext = RenderContext

---@param render Render
function RenderContext:__init(render)
    self.render = render
    self.options = M.get_optinos()
    self.danmakus = {}
    self.options_keys = fun.totable(fun.map(function(k)
        return k
    end, self.options))
end

function RenderContext:start()
    self:_register_events()
end

function RenderContext:stop()
    self:_unregister_events()
end

---@param danmakus Danmaku[]
function RenderContext:update_danmakus(danmakus)
    self.danmakus = danmakus
end

---@param opts Partial<RenderOptions>?
function RenderContext:update_options(opts)
    if opts == nil then
        self.options = M.get_optinos()
        self:invalidate(INVALIDATE_SOURCE, INVALIDATE_PREPARE, INVALIDATE_LAYOUT, INVALIDATE_ASS)
        return
    end
    local invalidate_map = {}
    local finals = {}
    for k, v in pairs(opts) do
        -- EmmyluaBUG undefined attr/field `[k]`
        ---@diagnostic disable-next-line: undefined-field
        ---@type RawValidator?
        local va = options.validators[k]
        if va == nil then
            mp.msg.warn('RenderContext update_options: unknown option', k)
        else
            local ok, err = pcall(va, k, v)
            if not ok then
                mp.msg.warn('RenderContext update_options:', err)
            else
                ---@cast k keyof RenderOptions
                self:_update_option(k, v, invalidate_map, finals)
            end
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
        self:invalidate(table.unpack(invalidate_t))
    end
end

---@param key keyof RenderOptions
---@param val any
---@param invalidate_map table<INVALIDATE_TYPE, true>
---@param finals function[]
function RenderContext:_update_option(key, val, invalidate_map, finals)
    debug_msgf('RenderContext:update_option(%s, %s)', key, val)
    self.option_update_dispatch_map[key](self, invalidate_map, val, finals)
    self.options[key] = val
end

---@param ... INVALIDATE_TYPE
function RenderContext:invalidate(...)
    local args = {...}
    if #args <= 0 then
        return
    end
    local set = {}
    debug_msg(function()
        return string.format("RenderContext:invalidate(%s)", fun.str_concat(fun.map(function(x)
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
    ---@type table<string, any>
    local danmaku_fields = {}
    local i = 1
    while i <= #args do
        local n = args[i]
        -- EmmyluaBUG `self.invalidate_dispatch_map` type `any`
        ---@type _invalidate_dispatch_cb<self, D>?
        local dispatch_fn = self.invalidate_dispatch_map[n]
        if dispatch_fn == nil then
            mp.msg.warn('RenderContext:invalidate got unknown invalidate type', n)
        else
            -- EmmyluaBUG `self` type-mismatch `RenderContext<D = _CalcedDanmaku>`
            ---@diagnostic disable-next-line: param-type-mismatch 
            dispatch_fn(self, danmaku_fields, add_inline)
        end
        i = i--[[@cast -?]] + 1
    end

    for field, val in pairs(danmaku_fields) do
        for _, d in ipairs(self.danmakus) do
            d[field] = val
        end
    end
end

function RenderContext:on_options_change(changes)
    local change_t = {}
    for _, change in ipairs(changes) do
        change_t[change] = options[change]
    end
    self:update_options(change_t)
end

function RenderContext:_register_events()
    ---@generic T
    ---@param func fun(...: T...)
    ---@param state any
    ---@param ... T...
    local function call_if_not_nil(func, state, ...)
        if state ~= nil then
            func(...)
        end
    end
    if self._on_pause_f == nil then
        self._on_pause_f = function(_, pause) call_if_not_nil(self.on_pause, pause, self, pause) end
    end
    if self._on_display_fps_f == nil then
        self._on_display_fps_f = function (_, fps) call_if_not_nil(self.on_display_fps, fps, self, fps) end
    end
    if self._on_osd_dimentions_f == nil then
        self._on_osd_dimentions_f = function(osd) call_if_not_nil(self.on_osd_dimentions, osd, self, osd) end
    end
    if self._on_playback_restart_f == nil then
        self._on_playback_restart_f = function() self:on_playback_restart() end
    end
    amp.observe_property('pause', 'bool', self._on_pause_f)
    amp.observe_property('display-fps', 'number', self._on_display_fps_f)
    amp.observe_property('osd-dimensions', 'native', self._on_osd_dimentions_f)
    amp.register_event('playback-restart', self._on_playback_restart_f)

    if self._on_options_change_f == nil then
        self._on_options_change_f = function(changes) self:on_options_change(changes) end
    end
    options.on_options_change(self.options_keys, self._on_options_change_f)
end

function RenderContext:_unregister_events()
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


return M