local mp = require 'mp'
local amp = require 'elxlibs.asyncio.amp'
local asyncio = require 'elxlibs.asyncio'
local va = require 'modules.validator'

---@class DanmakulxOptions
-- Options
---@field autoload boolean              自动尝试加载弹幕 [默认关闭]
---@field autoload_by_name boolean      自动加载仅在名称匹配 [默认关闭]
---@field autoload_name_pattern string  自动加载名称匹配模式
---@field dandanplay_api string         设置弹弹Play的后端API [默认官方]
---@field follow_scale boolean          弹幕跟随窗口缩放 [默认关闭]
---@field scrolltime number             滚动弹幕显式时间 (0.0~25) [默认: 10]
---@field fixedtime number              固定弹幕的显示时间 (0.0~25) [默认: 5]
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
---@field validators table<keyof DanmakulxOptions, RawValidator>

local validators = {
    autoload =              va.type_of("boolean"),
    autoload_by_name =      va.type_of("boolean"),
    autoload_name_pattern = va.type_of("string"),
    dandanplay_api =        va.type_of("string"),
    follow_scale =          va.type_of("boolean"),
    scrolltime =            va.and_(va.type_of("number"), va.gt(0), va.le(25)),
    fixedtime =             va.and_(va.type_of("number"), va.gt(0), va.le(25)),
    fontname =              va.type_of("string"),
    fontsize =              va.and_(va.type_of("number"), va.gt(0)),
    shadow =                va.and_(va.type_of("number"), va.ge(0)),
    border =                va.type_of("boolean"),
    opacity =               va.and_(va.type_of("number"), va.ge(0), va.le(1)),
    displayarea =           va.and_(va.type_of("number"), va.gt(0), va.le(1)),
    outline =               va.and_(va.type_of("number"), va.gt(0), va.le(4)),
    max_screen_danmaku =    va.and_(va.type_of("number"), va.ge(0)),
    density =               va.in_({"normal", "more", "overlap"}),
    res_x =                 va.or_(va.in_({"display-w", "display-h"}), va.and_(va.type_of("number"), va.gt(0))),
    res_y =                 va.or_(va.in_({"display-w", "display-h"}), va.and_(va.type_of("number"), va.gt(0))),
    debug =                 va.type_of("boolean"),
}

---@diagnostic disable-next-line: missing-fields
---@type DanmakulxOptions
local opts = {
    autoload = false,
    autoload_by_name = false,
    autoload_name_pattern = '',

    dandanplay_api = 'https://api.dandanplay.net',

    -- 弹幕跟随窗口缩放，默认关闭
    follow_scale = false,
    --滚动弹幕的显示时间 0.0~25
    scrolltime = 10.0,
    --固定弹幕的显示时间 0.0~25
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

local read_options
do
    -- converts val to type of desttypeval
    local function typeconv(desttypeval, val)
        if type(desttypeval) == "boolean" then
            if val == "yes" then
                val = true
            elseif val == "no" then
                val = false
            else
                mp.msg.error("Error: Can't convert '" .. val .. "' to boolean!")
                val = nil
            end
        elseif type(desttypeval) == "number" then
            if tonumber(val) ~= nil then
                val = tonumber(val)
            else
                mp.msg.error("Error: Can't convert '" .. val .. "' to number!")
                val = nil
            end
        end
        return val
    end

    -- performs a deep-copy of the given option value
    local function opt_copy(val)
        return val -- no tables currently
    end

    -- compares the given option values for equality
    local function opt_equal(val1, val2)
        return val1 == val2
    end

    -- performs a deep-copy of an entire option table
    local function opt_table_copy(opts)
        local copy = {}
        for key, value in pairs(opts) do
            copy[key] = opt_copy(value)
        end
        return copy
    end

    ---@param options table
    ---@param identifier string?
    ---@param on_update fun(changes:string[])?
    function read_options(options, identifier, on_update)
        local option_types = opt_table_copy(options)
        if identifier == nil then
            identifier = mp.get_script_name()
        end
        mp.msg.debug("reading options for " .. identifier)

        -- read config file
        local conffilename = "script-opts/" .. identifier .. ".conf"
        local conffile = mp.find_config_file(conffilename)
        local f = conffile and io.open(conffile,"r")
        if f == nil then
            -- config not found
            mp.msg.debug(conffilename .. " not found.")
        else
            -- config exists, read values
            mp.msg.verbose("Opened config file " .. conffilename .. ".")
            local linecounter = 1
            for line in f:lines() do
                ---@cast line string
                if line:sub(#line) == "\r" then
                    line = line:sub(1, #line - 1)
                end
                if string.find(line, "#") ~= 1 then
                    local eqpos = string.find(line, "=")
                    if eqpos ~= nil then
                        local key = string.sub(line, 1, eqpos-1)
                        local val = string.sub(line, eqpos+1)

                        -- match found values with defaults
                        if option_types[key] == nil then
                            mp.msg.warn(conffilename..":"..linecounter..
                                " unknown key '" .. key .. "', ignoring")
                        else
                            local convval = typeconv(option_types[key], val)
                            if convval == nil then
                                mp.msg.error(conffilename..":"..linecounter..
                                    " error converting value '" .. val ..
                                    "' for key '" .. key .. "'")
                            else
                                if pcall(validators[key]--[[@cast -?]], key, convval) then
                                    options[key] = convval
                                end
                            end
                        end
                    end
                end
                linecounter = linecounter + 1
            end
            io.close(f)
        end

        --parse command-line options
        local prefix = identifier.."-"
        -- command line options are always applied on top of these
        local conf_and_default_opts = opt_table_copy(options)

        local function parse_opts(full, opt)
            for key, val in pairs(full) do
                if string.find(key, prefix, 1, true) == 1 then
                    key = string.sub(key, string.len(prefix)+1)

                    -- match found values with defaults
                    if option_types[key] == nil then
                        mp.msg.warn("script-opts: unknown key " .. key .. ", ignoring")
                    else
                        local convval = typeconv(option_types[key], val)
                        if convval == nil then
                            mp.msg.error("script-opts: error converting value '" .. val ..
                                "' for key '" .. key .. "'")
                        else
                            
                            opt[key] = convval
                        end
                    end
                end
            end
        end

        --initial
        parse_opts(mp.get_property_native("options/script-opts"), options)

        --runtime updates
        if on_update then
            local last_opts = opt_table_copy(options)

            amp.observe_property("options/script-opts", "native", function(_, val)
                local new_opts = opt_table_copy(conf_and_default_opts)
                parse_opts(val, new_opts)
                local changelist = {}
                for k, v in pairs(new_opts) do
                    if not opt_equal(last_opts[k], v) then
                        -- copy to user
                        options[k] = opt_copy(v)
                        changelist[k] = true
                    end
                end
                last_opts = new_opts
                if next(changelist) ~= nil then
                    on_update(changelist)
                end
            end)
        end

    end
end

read_options(opts, mp.get_script_name(), properties_change)

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

opts.validators = validators

return opts