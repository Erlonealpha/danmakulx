local mp = require "mp"
local amp = require "elxlibs.asyncio.amp"
local bilibili = require 'sources.bilibili'
local json = require "elxlibs.json"
local source_m = require 'source'
local rex = require("elxlib.elxlibs.rex")
local asyncio = require("elxlib.elxlibs.asyncio")
local render = require("render")
local anitomy = require("modules.anitomy")
local dandanplay = require("sources.dandanplay")
local normalize_path = require("modules.parse")

require 'test_set_dandanapi'


local M = {}
local commands = {}

local source_manager = source_m.SourceManager()
local test_render = render()

---@param danmakus Danmaku[]
---@param level int
local function process_block_level(danmakus, level)
    for i = #danmakus, 1, -1 do
        ---@type Danmaku
        local d = danmakus[i]
        if d.extra.block_level < level then
            d.enable = false
        else
            d.enable = true
        end
    end
end

local url_patt = rex.safe_new[[^([a-z][a-z0-9+\.-]*:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w\.\-\?&\+=\#~%]*)$]]
function commands.add(...)
    ---@type asyncio.Task<_ProcessResult?>[]
    local ts = {}
    for _, p in ipairs({...}) do
        if url_patt:match(p) then
            table.insert(ts, asyncio.create_task(source_manager:process_url(p)))
        else
            table.insert(ts, asyncio.create_task(source_manager:process_path(p)))
        end
    end
    local results = await(asyncio.gather(ts))
    for _, result in ipairs(results) do
        if result ~= nil then
            if result.source.name == "bilibili" then
                process_block_level(result.data, 5)
            end
            test_render:add_source(result.source, result.data)
        end
    end
end

function commands.remove(...)
end

function commands.enable(source)
    if source ~= nil then
        test_render:enable_source({id = source, name = nil})
    else
        test_render:enable()
    end
end

function commands.set_block_level(source, level)
    local function set(s)
        if s ~= nil and s.source.name == "bilibili" then
            process_block_level(s.data, level)
        end
    end
    if source ~= nil then
        set(test_render:get_source(source))
    else
        for _, s in ipairs(test_render:get_sources()) do
            set(test_render:get_source(s.id))
        end
    end
    test_render:_invalidate(INVALIDATE_PREPARE)
end

function commands.disable(source)
    if source ~= nil then
        test_render:disable_source({id = source, name = nil})
    else
        test_render:disable()
    end
end

function commands.set_delay(source, delay, start, end_)
    if delay ~= nil then
        test_render:set_source_delay({id = source, name = nil}, tonumber(delay))
    else
        delay = tonumber(source)
        if delay ~= nil then
            for _, s in ipairs(test_render:get_sources()) do
                test_render:set_source_delay(s, delay)
            end
        end
    end
end

function commands.update(key, val)
    if val == "yes" or val == "true" then
        val = true
    elseif val == "no" or val == "false" then
        val = false
    end
    local n = tonumber(val)
    if n ~= nil then
        val = n
    end
    test_render:update_options({[key] = val})
end

function commands.match(name)
    local p = source_manager:get('dandanplay', dandanplay.provider)
    if p == nil then
        return
    end
    name = name or await(normalize_path(mp.get_property('path')))
    local res = await(p:match(
        name, 
        nil, 
        math.floor(mp.get_property_number('file-size')), 
        math.floor(mp.get_property_number('duration')), 
        nil, 
        true
    ))
    if res.error then
        mp.msg.warn(res.error)
    else
        mp.msg.info(json.dumps(res.result, 2))
    end
end

function commands.search(...)
    local result = await(dandanplay.search({
        keyword = table.concat({...}, ' '),
        v2 = true,
    }))
    if result.error then
        mp.msg.warn(result.error)
    else
        mp.msg.info(json.dumps(result.result, 2))
    end
end

function commands.anitomy(name)
    name = name or mp.get_property('title')
    local result = await(anitomy(name))
    mp.msg.info(json.dumps(result, 2))
end

function M.test(command, ...)
    if not test_render.is_running then
        test_render:start()
    end
    if commands[command] ~= nil then
        local args = {...}
        debug_msg('TEST', command .. '(' .. table.concat(args, ', ') .. ')')
        local _, err = xpcall(function()
            commands[command](table.unpack(args))
        end, debug.traceback)
        if err then
            mp.msg.error('TEST', command, 'error:\n', err)
        end
    else
        mp.msg.warn('unkonwn test command', command)
    end
end

amp.register_script_message('test', M.test)

local osd = mp.create_osd_overlay("ass-events")
osd.res_x = 2560
osd.res_y = 1600

amp.register_script_message('tests', function(text, x, y, fs, bold, an)
    x = x and tonumber(x) or 0
    y = y and tonumber(y) or 0
    fs = fs and tonumber(fs) or 36
    an = an and tonumber(an) or 8
    local b = bold and "\\b1" or ""
    osd.data = string.format('{\\fs%d\\pos(%.3f, %.3f)%s\\an%d}%s', fs, x, y, b, an, text)
    osd.compute_bounds = true
    local res = osd:update()
    local osd_dim = mp.get_property_native('osd-dimensions')
    mp.msg.info(string.format(
        "bound(%.2f, %.2f) pos<%.2f, %.2f, %.2f, %.2f> res[%d, %d] osd[%d, %d] %s", 
        res.x1 - res.x0,
        res.y1 - res.y0,
        res.x0, res.x1, res.y0, res.y1, 
        osd.res_x, osd.res_y,
        osd_dim.w, osd_dim.h, text
    ))
end)

amp.register_script_message('testss', function(k, v)
    if k == 'res_x' then
        osd.res_x = tonumber(v)
    elseif k == 'res_y' then
        osd.res_y = tonumber(v)
    end
end)

require '_tmp'