local curl = require 'modules/curl'
local std = require 'elxlibs.std'
local json = require 'elxlibs.json'
local hashlib = require 'elxlibs.hashlib'

local M = { source_name = "dandanplay"}

---@class DandanplaySource : SourceBase
---@field url string
---@field epid int
---@field with_related boolean
---@field name "dandanplay"

---@param epid int
---@param url string?
---@param with_related boolean?
---@return DandanplaySource
local function new_source(epid, url, with_related)
    return {
        id = string.format("%s_%d_%d", M.source_name, epid, with_related and 1 or 0),
        epid = epid,
        url = url,
        with_related = with_related,
        name = M.source_name
    }
end

-- https://api.dandanplay.net/swagger/index.html
local API_BASE = 'https://api.dandanplay.net'

---@param path string
local function api_v2(path)
    return API_BASE .. '/api/v2' .. path
end

local _appid = nil
local _appsecret = nil

---@param appid string
---@param secret string
function M.set_appid(appid, secret)
    _appid = appid
    _appsecret = secret
end

---@return string?
function M.generate_signature(path, time, appid, secret)
    appid = appid or _appid
    secret = secret or _appsecret
    if not appid or not secret then
        return nil
    end
    local sig = string.format('%s%s%s%s', appid, time, path, secret)
    return hashlib.base64_encode(
        hashlib.sha256(sig)
    )
end

---@param path string
---@param time int
---@return string
function M._C_generate_signature(path, time)
    -- TODO gensig.cpp (path, time) -> string
    return ''
end

---@param headers table<string, string>
local function _signature_headers(headers, path)
    if _appid and _appsecret then
        local time = os.time()
        headers["X-AppId"] = _appid
        headers["X-Signature"] = M.generate_signature(path, time, _appid, _appsecret)
        headers["X-Timestamp"] = tostring(time)
    end
end

--[[
    BANGUMI
--]]

---@alias DandanplayBangumiShinData {
---     errorCode: int,
---     success: boolean,
---     errorMessage: string,
---     errorDetail: string,
---     bangumiList: {
---         animeId: int,
---         bangumiId: string,
---         animeTitle: string,
---         imageUrl: string,
---         searchKeyword: string,
---         isOnAir: boolean,
---         airDay: int,
---         isFavorited: boolean,
---         isRestricted: boolean,
---         rating: int
---     }[]
--- }

-- 此接口用于获取官方的新番列表
---@async
---@param filter_adult_content boolean?
---@return asyncio.Coroutine<FutureResult<DandanplayBangumiShinData>>
function M.bangumi_shin(filter_adult_content)
return async(
function ()
    local headers = {}
    _signature_headers(headers)
    local result = await(curl.get(
        api_v2('/shin'), {
            params = {filterAdultContent = tostring(filter_adult_content)},
            headers = headers,
        }
    ))
    if not result.data or not result.success then
        return {ok=false, error=result.error}
    end
    return {ok=true, result=json.loads(result.data)}
end)
end

--[[
    FILE MATCH
--]]

---@alias DandaplayAnimeType 
--- | "tvseries"
--- | "tvspecial" 
--- | "ova" 
--- | "movie" 
--- | "musicvideo" 
--- | "web" 
--- | "other" 
--- | "jpmovie" 
--- | "jpdrama" 
--- | "unknown" 
--- | "tmdbtv" 
--- | "tmdbmovie"

---@alias DandanplayMatchData {
---     errorCode: int,
---     success: boolean,
---     errorMessage: string,
---     errorDetail: string,
---     isMatched: boolean,
---     matches: {
---         episodeId: int,
---         animeId: int,
---         animeTitle: string,
---         episodeTitle: string,
---         type: DandaplayAnimeType,
---         typeDescription: string,
---         shift: int,
---         imageUrl: string
---     }[]
--- }

---@async
---@param body {
---     filename: string,
---     filehash: string?,
---     filesize: int?,
---     video_duration: int?,
---     match_mode: "hashAndFileName"|"fileNameOnly"|"hashOnly"?
--- }
---@return asyncio.Coroutine<FutureResult<DandanplayMatchData>>
function M.match(body)
return async(
function ()
    body.filehash = body.filehash or ''
    body.filesize = body.filesize or 0
    body.video_duration = body.video_duration or 0
    body.match_mode = body.match_mode or "hashAndFileName"
    local headers = {}
    _signature_headers(headers)
    local result = await(curl.get(
        api_v2('/match'), {
            headers = headers,
            body = {
                fileName = body.filename,
                fileHash = body.filehash,
                fileSize = tostring(body.filesize),
                videoDuration = tostring(body.video_duration),
                matchMode = body.match_mode,
            }
        }
    ))
    if not result.data or not result.success then
        return {ok=false, error=result.error}
    end
    return {ok=true, result=json.loads(result.data)}
end)
end


---@class DananplayProvider : SourceProviderBase
---@overload fun():self
local DananplayProvider = std.class.new('DananplayProvider')
function DananplayProvider:__init()
    self.name = 'dandanplay'
end

function DananplayProvider:process_url(url)
return async(function()
    
end)
end

M.provider = DananplayProvider

return M