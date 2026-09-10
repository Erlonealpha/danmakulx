local mp = require 'mp'
local options = require 'modules/options'


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


---@generic T
---@param a T?
---@param def std.NotNull<T>
---@return std.NotNull<T>
local function select(a, def)
    if a ~= nil then
        return a
    end
    return def
end

local function parse_res(res_opt, def)
    if res_opt == "display-w" then
        return mp.get_property_number('display-width', 1920)
    elseif res_opt == 'display-h' then
        return mp.get_property_number('display-height', 1080)
    else
        return tonumber(res_opt) or def
    end
end

---@alias OsdRenderOptions {
---     fontname: string,
---     scrolltime: number,
---     fixedtime: number,
---     fontsize: number,
---     border: boolean,
---     opacity: number,
---     shadow: number,
---     outline: number,
---     displayarea: number,
---     density: string,
---     follow_scale: boolean,
---     res_x: number,
---     res_y: number,
--- }

local M = {}

---@return OsdRenderOptions
function M.get_optinos()
    return {
        fontname = options.fontname,
        scrolltime = select(tonumber(options.scrolltime), 10),
        fixedtime = select(tonumber(options.fixedtime), 2),
        fontsize = select(tonumber(options.fontsize), 32),
        border = options.border,
        opacity = select(tonumber(options.opacity), 0.8),
        shadow = select(tonumber(options.shadow), 0),
        outline = select(tonumber(options.outline), 1.0),
        displayarea = select(tonumber(options.displayarea), 0.4),
        density = options.density,
        follow_scale = options.follow_scale,
        res_x = parse_res(options.res_x, 1920),
        res_y = parse_res(options.res_y, 1080)
    }
end

return M