local std = require 'elxlibs.std'
local rex = require 'elxlibs.rex'
local json = require 'elxlibs.json'
local lxp = require 'elxlibs.lxp'
local curl = require 'modules/curl'
local base = require 'sources/_base'
local utils = require 'modules/utils'

local tointeger = utils.tointeger


---@desc 此处的API均只列出关键且需要的字段
---@desc API 参考: https://github.com/rinnein/bilibili-API-collect/
local M = { source_name = "bilibili" }

---@class BilibiliSource : SourceBase
---@field cid int
---@field url string?
---@field name "bilibili"

---@param cid int
---@param url string?
---@return BilibiliSource
local function new_source(cid, url)
    return {
        id = string.format("%s_c%s", M.source_name, cid), 
        cid = cid, 
        url = url, 
        name = M.source_name
    }
end


---@alias BilibiliVideoInfo {
---     code: 0|-400|-403|-404|62002|62004|62014,
---     message: string,
---     ttl: int,
---     data: {
---         bvid: string,
---         aid: int,
---         videos: int,
---         title: string,
---         pubdate: number,
---         desc: string,
---         duration: number,
---         redirect_url: string,
---         cid: int,
---         pages: {
---             cid: int,
---             page: int,
---             from: string,
---             part: string,
---             duration: number,
---         }[],
---     }
--- }


---@async
---@param aid int?
---@param bvid string?
---@param session_data string?
---@return asyncio.Coroutine<FutureResult<BilibiliVideoInfo>>
function M.video_info(aid, bvid, session_data)
return async(
function()
    local api = 'https://api.bilibili.com/x/web-interface/view'
    if not aid and not bvid then
        error('bilibili api error: video_info need aid or bvid')
    end
    local result = await(curl.get(api, {
        params = {aid = aid, bvid = bvid},
        cookies = session_data and {SESSDATA = session_data} or nil,
        timeout = 10,
    }))
    if not result.data or not result.success then
        return {ok=false, error=result.error}
    end
    return {ok=true, result=json.loads(result.data)}
end)
end

function M.video_pagelist()
    
end

---@alias BilibiliBangumiInfo {
---     code: 0|-400|-404,
---     message: string,
---     result: {
---         media: {
---             areas: {id: int, name: string}[],
---             cover: string,
---             horizontal_picture: string,
---             media_id: int,
---             new_ep: {id: int, index: string, index_show: string},
---             rating: {count: int, score: int},
---             season_id: int,
---             share_url: string,
---             title: string,
---             type: 1|2|3|4|5|7,
---             type_name: string,
---         },
---         review: {is_coin: int, is_open: int},
---     }
--- }

---@param mdid int
---@param session_data string?
---@return asyncio.Coroutine<FutureResult<BilibiliBangumiInfo>>
function M.bangumi_info(mdid, session_data)
return async(function()
    if mdid == nil then
        error('bilibili api error: bangumi_info need mdid')
    end

    local api = 'https://api.bilibili.com/pgc/review/user'
    local result = await(curl.get(api, {
        params = {media_id = mdid},
        cookies = session_data and {SESSDATA = session_data} or nil,
        timeout = 10,
    }))
    if not result.data or not result.success then
        return {ok=false, error=result.error}
    end
    return {ok=true, result=json.loads(result.data)}
end)
end

---@alias BilibiliBangumiInfoDetail {
---     code: 0|-404,
---     message: string,
---     result: {
---         areas: {id: int, name: string}[],
---         bkg_cover: string,
---         cover: string,
---         episodes: {
---             aid: int,
---             badge: string,
---             badge_info: {bg_color: string, bg_color_night: string, text: string},
---             badge_type: int,
---             bvid: string,
---             cid: int,
---             cover: string,
---             dimension: {
---                 height: int,
---                 rotate: int,
---                 width: int,
---             },
---             duration: int,
---             ep_id: int,
---             id: int,
---             link: string,
---             long_title: string,
---             pub_time: int,
---             share_copy: string,
---             share_url: string,
---             short_link: string,
---             show_title: string,
---             subtitle: string,
---             title: string,
---             toast_title: string,
---             vid: string,
---         }[],
---         evaluate: string,
---         jp_title: string,
---         link: string,
---         media_id: int,
---         new_ep: {desc: string, id: int, is_new: 0|1, title: string},
---         publish: {
---             is_finish: 0|1,
---             is_started: 0|1,
---             pub_time: string,
---             pub_time_show: string,
---             unknow_pub_date: int,
---             weekday: int
---         },
---         rating: {count: int, score: int},
---         season_id: int,
---         season_title: string,
---         seasons: {
---             badge: string,
---             badge_info: {bg_color: string, bg_color_night: string, text: string},
---             badge_type: int,
---             cover: string,
---             media_id: int,
---             new_ep: {cover: string, id: int, index_show: string},
---             season_id: int,
---             season_title: string,
---             season_type: int,
---             stat: {
---                 favorites: int,
---                 series_follow: int,
---                 views: int,
---                 vt: int,
---             },
---         }[],
---         section: {
---             attr: int,
---             episode_id: int,
---             episode_ids: {}[],
---             episodes: {}[],
---             id: int,
---             report: {},
---             title: string,
---         }[],
---         series: {
---             display_type: int,	
---             series_id: int,	
---             series_title: string,
---         },
---         share_copy: string,
---         share_sub_title: string,
---         share_url: string,
---         staff: string,
---         stat: {
---             coins: int,
---             danmakus: int,
---             favorite: int,
---             favorites: int,
---             follow_text: string,
---             hot: int,
---             likes: int,
---             reply: int,
---             share: int,
---             views: int,
---             vt: int,
---         },
---         status: int,
---         styles: string[],
---         subtitle: string,
---         title: string,
---         total: int,
---         type: int,
---     }
--- }

---@param epid int?
---@param ssid int?
---@param session_data string?
---@return asyncio.Coroutine<FutureResult<BilibiliBangumiInfoDetail>>
function M.bangumi_info_detail(epid, ssid, session_data)
return async(function()
    if epid == nil and ssid == nil then
        error('bilibili api error: bangumi_info need epid or ssid')
    end

    local api = 'https://api.bilibili.com/pgc/view/web/season'
    local result = await(curl.get(api, {
        params = {ep_id = epid, season_id = ssid},
        cookies = session_data and {SESSDATA = session_data} or nil,
        timeout = 10,
    }))
    -- debug_msg(function()
    --     return json.dumps(result, 2)
    -- end)
    if not result.data or not result.success then
        return {ok=false, error=result.error}
    end
    return {ok=true, result=json.loads(result.data)}
end)
end

---@param cid string|int
---@param session_data? string
---@return asyncio.Coroutine<FutureResult<string>>
function M.get_danmaku_from_cid(cid, session_data)
    return async(
    function()
        if not cid then
            error('bilibili api error: cid is required')
        end
        local api = string.format('https://comment.bilibili.com/%s.xml', tostring(cid))
        local result = await(curl.get(api, {
            timeout = 10,
            cookies = session_data and {SESSDATA = session_data} or nil,
            extras = {"--compressed"}
        }))
        if not result.data or not result.success then
            return {ok=false, error=result.error}
        end
        return {ok=true, result=result.data}
    end)
end

---@class BilibiliSourceProvider : SourceProviderBase
---@overload fun(session_data: string?):self
local BilibiliSourceProvider = std.class.new('BilibiliSourceProvider', {base.SourceProviderBase})
function BilibiliSourceProvider:__init(session_data)
    self.session_data = session_data
    self.name = 'bilibili'
end

-- local id_pattern = rex.new[[((BV)([A-Za-z0-9]{10}))|((av)(\d+))|((ep)(\d+))|((ss)(\d+))]]
local url_pattern = rex.new[[^https?://(?:[^/]*\.)?(bilibili\.com|b23\.tv)\S*]]
local id_pattern = rex.new[[((?|(BV)([A-Za-z0-9]{10})|(av)([0-9]+)|(ep)([0-9]+)|(ss)([0-9]+)))]]

---@param url string
function BilibiliSourceProvider:process_url(url)
return async(function()
    debug_msgf('BilibiliSourceProvider:process_url try %s', url)
    local m = url_pattern:match(url)
    if m == nil then
        return
    elseif m == 'b23.tv' then
        
    end

    local full, type, id = id_pattern:match(url)
    if not id then
        return
    end
    debug_msgf('BilibiliSourceProvider:process_url parsed %s %s', type, id)
    local query = utils.parse_query(url)
    if type == 'BV' then
        return await(self:process_bvid(full, query.p, url))
    elseif type == 'av' then
        id = tointeger(id)
        if id == nil then
            return base.new_process_error(string.format('bilibili api error: parse aid error, id: %s', id))
        end
        return await(self:process_avid(id, url))
    elseif type == 'ep' then
        id = tointeger(id)
        if id == nil then
            return base.new_process_error(string.format('bilibili api error: parse epid error, id: %s', id))
        end
        return await(self:process_epid(id, url))
    elseif type == 'ss' then
        id = tointeger(id)
        if id == nil then
            return base.new_process_error(string.format('bilibili api error: parse ssid error, id: %s', id))
        end
        return await(self:process_ssid(id, url))
    else
        -- unreachable
        return base.new_process_error(string.format('bilibili api error: parsed unknown id type, path: %s', url))
    end
end)
end

---@param bvid string
---@param page? int|string
---@param url string?
---@return asyncio.Coroutine<ProcessResult?>
function BilibiliSourceProvider:process_bvid(bvid, page, url)
return async(function()
    local result = await(M.video_info(nil, bvid))
    if not result.result or not result.ok then
        return base.new_process_error(string.format('bilibili api error: %s', result.error))
    end
    local info = result.result
    if info.code ~= 0 then
        return base.new_process_error(string.format('bilibili api error: %s', info.message))
    end

    local cid
    if page then
        for _, _page in ipairs(info.data.pages) do
            if tonumber(page) == _page.page then
                cid = _page.cid
                break
            end
        end
    else
        cid = info.data.cid
    end
    if not cid then
        return base.new_process_error('bilibili api error: cid not found')
    end
    return await(self:process_cid(cid, url))
end)
end

---@param aid int
---@param page? int|string
---@param url string?
---@return asyncio.Coroutine<ProcessResult?>
function BilibiliSourceProvider:process_avid(aid, page, url)
return async(function()
    local result = await(M.video_info(aid))
    if not result.result or not result.ok then
        return base.new_process_error(string.format('bilibili api error: %s', result.error))
    end
    local info = result.result
    if info.code ~= 0 then
        return base.new_process_error(string.format('bilibili api error: %s', info.message))
    end

    local cid
    if page then
        for _, _page in ipairs(info.data.pages) do
            if tonumber(page) == _page.page then
                cid = _page.cid
                break
            end
        end
    else
        cid = info.data.cid
    end
    if not cid then
        return base.new_process_error('bilibili api error: cid not found')
    end
    return await(self:process_cid(cid, url))
end)
end

---@param epid int
---@param url string?
---@return asyncio.Coroutine<ProcessResult?>
function BilibiliSourceProvider:process_epid(epid, url)
return async(function()
    local result = await(M.bangumi_info_detail(epid))
    if not result.result or not result.ok then
        return base.new_process_error(string.format('bilibili api error: %s', result.error))
    end
    local info = result.result
    if info.code ~= 0 then
        return base.new_process_error(string.format('bilibili api error: %s', info.message))
    end
    ---@[lsp_optimization("delayed_definition")]
    local cid
    for _, ep in ipairs(info.result.episodes) do
        if ep.ep_id == epid then
            cid = ep.cid
            break
        end
    end
    if cid == nil then
        return base.new_process_error(string.format('bilibili api error: cannot find cid from %d', epid))
    end
    return await(self:process_cid(cid, url))
end)
end

---@param ssid int
---@param url string?
---@return asyncio.Coroutine<ProcessResult?>
function BilibiliSourceProvider:process_ssid(ssid, url)
return async(function()
    local result = await(M.bangumi_info_detail(nil, ssid))
    if not result.result or not result.ok then
        return base.new_process_error(string.format('bilibili api error: %s', result.error))
    end
    local info = result.result
    if info.code ~= 0 then
        return base.new_process_error(string.format('bilibili api error: %s', info.message))
    end
    ---@[lsp_optimization("delayed_definition")]
    local cid
    for _, ep in ipairs(info.result.episodes) do
        cid = ep.cid
        break
    end
    if cid == nil then
        return base.new_process_error(string.format('bilibili api error: cannot find cid from %d', ssid))
    end
    return await(self:process_cid(cid, url))
end)
end

---@param mdid int
---@param url string?
---@return asyncio.Coroutine<ProcessResult?>
function BilibiliSourceProvider:process_mdid(mdid, url)
return async(function()
    local result = await(M.bangumi_info(mdid))
    if not result.result or not result.ok then
        return base.new_process_error(string.format('bilibili api error: %s', result.error))
    end
    local info = result.result
    if info.code ~= 0 then
        return base.new_process_error(string.format('bilibili api error: %s', info.message))
    end
    return await(self:process_ssid(info.result.media.season_id, url))
end)
end

--[[
字符串内每项用逗号,分隔

项	含义	类型	备注
0	视频内弹幕出现时间	 float	秒
1	弹幕类型	        int32
    1 2 3：普通弹幕
    4：底部弹幕
    5：顶部弹幕
    6：逆向弹幕
    7：高级弹幕
    8：代码弹幕
    9：BAS弹幕（pool必须为2）
2	弹幕字号	int32
    18：小
    25：标准
    36：大
3	弹幕颜色	int32	十进制RGB888值
4	弹幕发送时间	int32	时间戳
5	弹幕池类型	int32	
    0: 普通池
    1: 字幕池
    2: 特殊池 (代码/BAS弹幕)
    3: 互动池?
6	发送者mid的HASH	string	用于屏蔽用户和查看用户发送的所有弹幕 也可反查用户id
7	弹幕dmid	int64	唯一 可用于操作参数
8	弹幕的屏蔽等级	int32	0-10，低于用户设定等级的弹幕将被屏蔽
    （新增，下方样例未包含）
]]
---@param xml_data string
---@return_overload Danmaku[]
---@return_overload nil, string
function M.parse_danmaku_xml(xml_data)
    local insert = table.insert
    local tonumber = tonumber
    ---@type Danmaku[]
    local danmakus = {}
    ---@type string?
    local curr_danmaku_p
    local xml_parser = lxp.new({
        StartElement = function(parser, elementName, attributes)
            if elementName == "d" then
                curr_danmaku_p = attributes.p
            end
        end,
        CharacterData = function(parser, s)
            if curr_danmaku_p ~= nil then
                local parts = std.split(curr_danmaku_p, ',')
                insert(danmakus, {
                    text = s,
                    ---@diagnostic disable-next-line: param-type-mismatch
                    color = tonumber(parts[4]),
                    type = tonumber(parts[2]),
                    time = tonumber(parts[1]),
                    extra = {
                        fontsize = tonumber(parts[3]),
                        send_time = tonumber(parts[5]),
                        pool_type = tonumber(parts[6]),
                        mid = parts[7],
                        dmid = tonumber(parts[8]),
                        block_level = tonumber(parts[9])
                    },
                })
                curr_danmaku_p = nil
            end
        end
    }):setencoding("UTF-8")
    local _, err, line, col, pos = xml_parser:parse(xml_data)
    if err ~= nil then
        xml_parser:close()
        return nil, string.format(
            "bilibili api error: failed to parse xml result, at line %d col %d pos %d: %s", 
            line, col, pos, err
        )
    end
    xml_parser:close()
    return danmakus
end

---@param cid int
---@param url string?
---@return asyncio.Coroutine<ProcessResult?>
function BilibiliSourceProvider:process_cid(cid, url)
return async(function()
    local xml_result = await(M.get_danmaku_from_cid(cid))
    if not xml_result.result then
        return base.new_process_error(xml_result.error or 'bilibili api error: danmaku fetch error')
    end
    local danmakus, err = M.parse_danmaku_xml(xml_result.result)
    if err ~= nil then
        return base.new_process_error(err)
    end
    return base.new_process_result(
        danmakus,
        new_source(cid, url)
    )
end)
end

M.provider = BilibiliSourceProvider

return M