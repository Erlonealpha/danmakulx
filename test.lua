local mp = require "mp"
local amp = require "elxlibs.asyncio.amp"
local bilibili = require 'sources.bilibili'
local json = require "elxlibs.json"
local source_m = require 'source'
local rex = require("elxlib.elxlibs.rex")
local asyncio = require("elxlib.elxlibs.asyncio")
local render = require("render")

local M = {}

-- ---@async
-- function M.test(url)
--     if not url then
--         mp.msg.error('test url is required')
--         return
--     end

--     local bvid = url:match('(BV[a-zA-Z0-9]+)')
--     if not bvid then
--         mp.msg.error('cannot find BVID from', url)
--         return
--     end

--     local fetch_result = await(bilibili.video_info(nil, bvid))
--     if fetch_result.error then
--         mp.msg.info('test info error', fetch_result.error)
--         return
--     end
--     local result = fetch_result.result
--     if result == nil then
--         mp.msg.info('test info got nil')
--         return
--     end
--     if result.code ~= 0 then
--         mp.msg.info('test info got code', result.code, result.message)
--         return
--     end
--     local vinfo = {
--         aid = result.data.aid,
--         bvid = result.data.bvid,
--         cid = result.data.cid,
--         title = result.data.title,
--         desc = result.data.desc,
--         pages = result.data.pages,
--     }
--     mp.msg.info(json.dumps(vinfo, 2))

--     local danmaku_result = await(bilibili.get_danmaku_from_cid(result.data.cid))
--     if danmaku_result == nil then
--         mp.msg.info('test danmaku fetch got nil')
--         return
--     end
--     if danmaku_result.error then
--         mp.msg.info('test danmaku fetch error', danmaku_result.error)
--         return
--     end
--     local result_d = danmaku_result.result
--     if result_d == nil then
--         mp.msg.info('test danmaku fetch got empty result')
--         return
--     end
--     if danmaku_result.result ~= nil then
--         local danmakus = bilibili.parse_danmaku_xml(danmaku_result.result)
--         if danmakus ~= nil then
--             table.sort(danmakus, function(a, b)
--                 return a.time < b.time
--             end)
--             for i = #danmakus, 1, -1 do
--                 local d = danmakus[i]
--                 if d.extra.block_level < 7 then
--                     table.remove(danmakus, i)
--                 elseif d.text == '切换简体' then
--                     table.remove(danmakus, i)
--                 end
--             end
--             -- for _, d in ipairs(danmakus) do
--             --     if d.type > 3 then
--             --         debug_msgf('TB time: %.2f type: %d text: %s', d.time, d.type, d.text)
--             --     end
--             -- end
--             -- local pre_20 = {}
--             -- table.sort(danmakus, function(a, b)
--             --     return a.time < b.time
--             -- end)
--             -- for i, d in ipairs(danmakus) do
--             --     if i > 20 then
--             --         break
--             --     end
--             --     table.insert(pre_20, d)
--             -- end
--             -- mp.msg.info(require('elxlibs.json').dumps(pre_20, 2))
--             local render_cls = require('render')
--             if test_render == nil then
--                 test_render = render_cls()
--             end
--             test_render:add_source({id = vinfo.cid, name = "bilibili", cid = vinfo.cid}, danmakus)
--             if not test_render.is_running then
--                 test_render:start()
--                 test_render:enable()
--             end
--         end
--     end

--     mp.msg.info('TEST END')
-- end

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
    debug_msg('TEST add')
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
    debug_msg('TEST enable')
    if source ~= nil then
        test_render:enable_source({id = source, name = nil})
    else
        test_render:enable()
    end
end

function commands.set_block_level(source, level)
    debug_msg('TEST set_block_level')
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
    test_render:_all_dirty()
end

function commands.disable(source)
    debug_msg('TEST disable')
    if source ~= nil then
        test_render:disable_source({id = source, name = nil})
    else
        test_render:disable()
    end
end

function commands.set_delay(source, delay, start, end_)
    debug_msg('TEST set_delay', source, delay, start, end_)
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
    debug_msg('TEST update', key, val, type(val))
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

function M.test(command, ...)
    if not test_render.is_running then
        test_render:start()
    end
    if commands[command] ~= nil then
        local args = {...}
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