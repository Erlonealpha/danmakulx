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

---@param result RequestResult
---@return FutureResult<any>
local function basic_result_process(result)
    if not result.data or not result.success then
        return {ok=false, error=result.error}
    end
    return {ok=true, result=json.loads(result.data)}
end

--[[
    BANGUMI
--]]

-- 此接口用于获取官方的新番列表
---@see DandanAPI.DandanAPI_Bangumi_GetShinBangumi
---@async
---@param filter_adult_content boolean?
---@return asyncio.Coroutine<FutureResult<DandanAPIBangumiListResponse>>
function M.bangumi_shin(filter_adult_content)
return async(
function ()
    local headers = {}
    _signature_headers(headers)
    local result = await(curl.get(
        api_v2('/shin'), {
            params = {filterAdultContent = filter_adult_content},
            headers = headers,
        }
    ))
    return basic_result_process(result)
end)
end

--[[
    FILE MATCH
--]]

---@see DandanAPI.DandanAPI_Match_Match
---@async
---@param body DandanAPI_Match_Match_Body
---@return asyncio.Coroutine<FutureResult<DandanAPIMatchResponseV2>>
function M.match(body)
return async(
function ()
    body.fileSize = body.fileSize or 0
    body.videoDuration = body.videoDuration or 0
    body.matchMode = body.matchMode or "hashAndFileName"
    local headers = {}
    _signature_headers(headers)
    local result = await(curl.post(
        api_v2('/match'), {
            headers = headers,
            body = body
        }
    ))
    return basic_result_process(result)
end)
end

---@see DandanAPI.DandanAPI_Match_BatchMatch
---@async
---@param body DandanAPI_Match_BatchMatch_Body
---@return asyncio.Coroutine<FutureResult<DandanAPIBatchMatchResponse>>
function M.match_batch(body)
return async(function()
    if not body.requests then
        return {ok=false, error='Dandanplay api: match batch body.requests is required'}
    end
    for _, req in ipairs(body.requests) do
        req.fileSize = req.fileSize or 0
        req.videoDuration = req.videoDuration or 0
        req.matchMode = req.matchMode or "hashAndFileName"
    end
    local headers = {}
    _signature_headers(headers)
    local result = await(curl.post(
        api_v2('/match/batch'), {
            headers = headers,
            body = body,
        }
    ))
    return basic_result_process(result)
end)
end

---@see DandanAPI.DandanAPI_Search_SearchAnime
---@async
---@param params DandanAPI_Search_SearchAnime_Parameters
---@return asyncio.Coroutine<FutureResult<DandanAPISearchAnimeResponse>>
function M.search(params)
return async(function()
    local headers = {}
    _signature_headers(headers)
    local result = await(curl.get(
        api_v2('/match/batch'), {
            headers = headers,
            params = params,
        }
    ))
    return basic_result_process(result)
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