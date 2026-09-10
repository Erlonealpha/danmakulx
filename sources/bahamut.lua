local curl = require 'modules/curl'
local std = require "elxlibs.std"
local json = require 'elxlibs.json'
local base = require 'sources/_base'
local rex = require "elxlibs.rex"
local utils = require "modules.utils"

local tointeger = utils.tointeger

local M = {source_name = "bahamut"}

---@class BahamutSource : SourceBase
---@field url string?
---@field sn int
---@field name "bahamut"

---@param sn int
---@param url string?
---@return BahamutSource
local function new_source(sn, url)
    return {
        id = string.format("%s_%d", M.source_name, sn),
        sn = sn, 
        url = url, 
        name = "bahamut"
    }
end

---@alias BahamutAnimeInfo {
---     data: {
---         video: {
---             video_sn: int,
---             anime_sn: int,
---             duration: int,
---             rating: int,
---             type: int,
---             cover: string,
---             quality: string,
---             breakpoint: int,
---             rating_desc: string,
---             sponsor_text: string,
---             prev_video_sn: int,
---             next_video_sn: int,
---             title: string,
---         },
---         anime: {
---             acg_sn: int,
---             anime_sn: int,
---             title: string,
---             dc_c1: int,
---             dc_c2: int,
---             total_volume: int,
---             upload_time: string,
---             season_start: string,
---             season_end: string,
---             favorite: boolean,
---             flag: int,
---             popular: int,
---             highlightTag: {
---                 bilingual: boolean,
---                 edition: string,
---                 vipTime: string,
---             },
---             volume_index: int,
---             volumes: table<string, {
---                 volume: int,
---                 video_sn: int,
---                 state: int,
---                 cover: string,
---             }>,
---             cover: string,
---             content: string,
---             tags: string[],
---             category: int,
---             director: string,
---             publisher: string,
---             maker: string,
---             score: int,
---             star: int,
---             userReviewId: string,
---         },
---         relative_anime: {
---             acg_sn: int,
---             anime_sn: int,
---             title: string,
---             dc_c1: int,
---             dc_c2: int,
---             favorite: boolean,
---             flag: int,
---             cover: string,
---             info: string,
---             popular: int,
---             highlightTag: {
---                 bilingual: boolean,
---                 edition: string,
---                 vipTime: string,
---             }
---         }[],
---         relative_gnn: {
---             url: string,
---             title: string,
---             pic: string,
---         }[],
---         promote: string[]
---     },
---     error?: string,
--- }

---@async
---@param sn string
---@return asyncio.Coroutine<FutureResult<BahamutAnimeInfo>>
function M.anime_info(sn)
return async(function()    
    local api = 'https://api.gamer.com.tw/mobile_app/anime/v2/video.php'
    local result = await(curl.get(api, {
        params = {sn = sn}
    }))
    if not result.data or not result.success then
        return {ok=false, error=result.error}
    end
    return {ok=true, result=json.loads(result.data)}
end)
end

---@alias BahamutDanmakuData {
---     text: string,
---     color: string,
---     size: int,
---     position: int,
---     time: int,
---     sn: int,
---     userid: string,
--- }[]

---@async
---@param sn string
---@param cookie string
---@return asyncio.Coroutine<FutureResult<BahamutDanmakuData>>
function M.get_danmaku(sn, cookie)
return async(function()    
    local api = 'https://ani.gamer.com.tw/ajax/danmuGet.php'
    local result = await(curl.post(api, {
        data = {sn = sn}, 
        cookies = {cf_clearance = cookie},
    }))
    if not result.data or not result.success then
        return {ok=false, error=result.error}
    end
    return {ok=true, result=json.loads(result.data)}
end)
end

---@class BahamutProvider : SourceProviderBase
---@overload fun():self
local BahamutProvider = std.class.new("BahamutProvider", {base.SourceProviderBase})
function BahamutProvider:__init(cookies_context)
    self.name = "bahamut"
    self.cookies_context = cookies_context
end

local url_pattern = rex.new('ani.gamer.com.tw')

function BahamutProvider:process_url(url)
return async(function()
    if not url_pattern:match(url) then
        return
    end
    local q = utils.parse_query(url)
    if q.sn == nil then
        return
    end
    local sn = tointeger(q.sn)
    if sn == nil then
        return base.new_process_error(string.format('bahamut api error: parse sn error, sn=%s', q.sn))
    end
    return await(self:process_sn(sn, url))
end)
end

---@param sn int
---@param url string?
function BahamutProvider:process_sn(sn, url)
return async(function()
    local cookies = self.cookies_context.get('bahamut')
    local result = await(
        M.get_danmaku(tostring(sn), cookies))
    if not result.result or not result.ok then
        return base.new_process_error(string.format('bahamut api error: %s', result.error))
    end
    return base.new_process_result(
        "json", 
        result.result, 
        new_source(sn, url), 
        true
    )
end)
end
