local mp = require "mp"
local amp = require "elxlibs.asyncio.amp"
local asyncio = require "elxlibs.asyncio"

---@class DanmakulxOptions
-- Options
---@field autoload boolean              自动尝试加载弹幕 [默认关闭]
---@field autoload_by_name boolean      自动加载仅在名称匹配 [默认关闭]
---@field autoload_name_pattern string  自动加载名称匹配模式
---@field dandanplay_api string         设置弹弹Play的后端API [默认官方]
---@field follow_scale boolean          弹幕跟随窗口缩放 [默认关闭]
---@field scrolltime number             滚动弹幕显式时间 [默认: 10]
---@field fixedtime number              固定弹幕的显示时间 [默认: 5]
---@field fontname string               弹幕字体 [默认: 'sans-serif']
---@field fontsize number               弹幕字体大小 [默认: 32]
---@field shadow number                 弹幕字体阴影 [默认: 0]
---@field border boolean                弹幕粗体 [默认关闭]
---@field opacity number                弹幕透明度 (0.0~1.0) [默认: 0.8]
---@field displayarea number            弹幕显式范围 (0.0~1.0) [默认: 0.2]
---@field outline number                弹幕描边 (0.0~4.0) [默认: 1.0]
---@field max_screen_danmaku number     限制同屏弹幕数量 (0表示不限制) [默认: 0]
---@field density string                弹幕密度 (normal: 正常 more: 更多 overlap: 重叠) [默认: 'normal']
---@field res_x int                     弹幕渲染基于的画布宽度 ('display-w' 表示显示器宽度) [默认: 'display-w']
---@field res_y int                     弹幕渲染基于的画布高度 ('display-h' 表示显示器宽度) [默认: 'display-h']
---@field debug boolean                 输出调试信息 [默认关闭]
-- Methods
---@field on_options_change fun(names: string[], cb: fun(changes: string[]))
---@field unregister fun(cb: fun(changes: string[]))

---@diagnostic disable-next-line: missing-fields
---@type DanmakulxOptions
local opts = {
    autoload = false,
    autoload_by_name = false,
    autoload_name_pattern = '',

    dandanplay_api = 'https://api.dandanplay.net',

    -- 弹幕跟随窗口缩放，默认关闭
    follow_scale = false,
    --滚动弹幕的显示时间
    scrolltime = 10.0,
    --固定弹幕的显示时间
    fixedtime = 5.0,
    --字体
    fontname = "sans-serif",
    --字体大小 
    fontsize = 32.0,
    --字体阴影
    shadow = 0.0,
    --字体粗体
    border = false,
    -- 透明度：0（完全透明）到 1（不透明）
    opacity = 0.8,
    --全部弹幕的显示范围(0.0-1.0)
    displayarea = 0.2,
    --描边 0-4
    outline = 1.0,
    -- 限制屏幕中同时显示的最大弹幕数量，0 表示不限制
    max_screen_danmaku = 0,
    -- 弹幕密度，normal: 正常 more: 更多 overlap: 重叠
    density = "normal",
    -- 弹幕渲染基于的画布宽度，默认显示器宽度
    res_x = "display-w",
    -- 弹幕渲染基于的画布宽度，默认显示器高度
    res_y = "display-h",

    debug = true,
}

---@type table<string, fun(changes: string[])[]>
local on_options_changes = {}

---@async
---@param changes string[]
local function properties_change(changes)
    local cb_map = {}
    for _, change in ipairs(changes) do
        local cbs = on_options_changes[change]
        if cbs and #cbs > 0 then
            for _, cb in ipairs(cbs) do
                if cb_map[cb] == nil then
                    cb_map[cb] = {}
                end
                table.insert(cb_map[cb], change)
            end
        end
    end
    local ts = {}
    for cb, cb_changes in pairs(cb_map) do
        table.insert(ts, asyncio.create_task(function()
            cb(cb_changes)
        end))
    end
    await(asyncio.gather(ts))
end

local mpob = mp.observe_property
mp.observe_property = amp.observe_property
require("mp.options").read_options(opts, mp.get_script_name(), properties_change)
mp.observe_property = mpob

---@param names string[]
---@param cb fun(changes: string[])
function opts.on_options_change(names, cb)
    for _, n in ipairs(names) do
        if on_options_changes[n] == nil then
            on_options_changes[n] = {}
        end
        table.insert(on_options_changes[n], cb)
    end
end

---@param cb fun(changes: string[])
function opts.unregister(cb)
    for _, cbs in pairs(on_options_changes) do
        for i = #cbs, 1 do
            if cbs[i] == cb then
                table.remove(cbs, i)
            end
        end
    end
end

return opts