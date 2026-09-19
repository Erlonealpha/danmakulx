local curl = require 'modules.curl'
local std = require 'elxlibs.std'
local fun = require 'elxlib.elxlibs.fun'
local rex = require 'elxlib.elxlibs.rex'
local json = require 'elxlibs.json'
local hashlib = require 'elxlibs.hashlib'
local normalize = require 'modules.parse'
local base = require 'sources._base'

local M = { source_name = "dandanplay" }

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
    return '/api/v2' .. path
end
local function api_url(path)
    return API_BASE .. path
end

local _app = {}

---@param appid string
---@param secret string
function M.set_appid(appid, secret)
    _app.appid = appid
    _app.appsecret = secret
end

---@return string?
function M.generate_signature(path, time, appid, secret)
    appid = appid or _app.appid
    secret = secret or _app.appsecret
    if not appid or not secret then
        return nil
    end
    local sig = string.format('%s%s%s%s', appid, time, path, secret)
    return hashlib.base64_encode(
        hashlib.hex2bin(hashlib.sha256(sig)))
end

---@param path string
---@param time int
---@return string
function M._C_generate_signature(path, time)
    -- TODO gensig.cpp (path, time) -> string
    return ''
end

---@param headers table<string, string|number>
---@param path string
local function _signature_headers(headers, path)
    local appid = _app.appid
    local sec = _app.appsecret
    if appid ~= nil and sec ~= nil then
        local time = os.time()
        headers["X-AppId"] = appid
        headers["X-Signature"] = M.generate_signature(path, time, appid, sec)
        headers["X-Timestamp"] = time
    end
end

---@param result RequestResult
---@return FutureResult<any>
local function basic_result_process(result)
    if result.data == nil or result.data == "" or not result.success then
        return {ok=false, error=result.error or 'invalid result'}
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
return async(function()
    local headers = {}
    local path = api_v2('/shin')
    _signature_headers(headers, path)
    local result = await(curl.get(
        api_url(path), {
            params = {filterAdultContent = filter_adult_content},
            headers = headers,
            user_agent = 'MPV-danmakulx 0.1.0'
        }
    ))
    return basic_result_process(result)
end)
end

---@see DandanAPI.DandanAPI_Bangumi_GetBangumiDetails
---@param bangumi_id string|int 支持传入数字形式的 animeId（如 18319）或字符串形式的 bangumiId（如 "tmdb-movie-21832"）。
---@return asyncio.Coroutine<FutureResult<DandanAPIBangumiDetailsResponse>>
function M.bangumi_details(bangumi_id)
return async(function()
    local headers = {}
    local path = api_v2('/bangumi/' .. tostring(bangumi_id))
    _signature_headers(headers, path)
    local result = await(curl.get(
        api_url(path), {
            headers = headers,
            user_agent = 'MPV-danmakulx 0.1.0'
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
    local path = api_v2('/match')
    _signature_headers(headers, path)
    local result = await(curl.post(
        api_url(path), {
            headers = headers,
            body = body,
            user_agent = 'MPV-danmakulx 0.1.0'
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
    local path = api_v2('/match/batch')
    _signature_headers(headers, path)
    local result = await(curl.post(
        api_url(path), {
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
    local path = api_v2('/search/anime')
    _signature_headers(headers, path)
    local result = await(curl.get(
        api_url(path), {
            headers = headers,
            params = params,
        }
    ))
    return basic_result_process(result)
end)
end

---@see DandanAPI.DandanAPI_Search_SearchAdvanced
---@async
---@param params DandanAPI_Search_SearchAdvanced_Parameters
---@return asyncio.Coroutine<FutureResult<DandanAPISearchBangumiResponse>>
function M.search_advanced(params)
return async(function()
    local headers = {}
    local path = api_v2('/search/adv')
    _signature_headers(headers, path)
    local result = await(curl.get(
        api_url(path), {
            headers = headers,
            params = params,
            user_agent = 'MPV-danmakulx 0.1.0'
        }
    ))
    return basic_result_process(result)
end)
end

---@see DandanAPI.DandanAPI_Search_SearchEpisodes
---@param params DandanAPI_Search_SearchEpisodes_Parameters
---@return asyncio.Coroutine<FutureResult<DandanAPISearchEpisodesResponse>>
function M.search_episodes(params)
return async(function()
    local headers = {}
    local path = api_v2('/search/episodes')
    _signature_headers(headers, path)
    local result = await(curl.get(
        api_url(path), {
            headers = headers,
            params = params,
        }
    ))
    return basic_result_process(result)
end)
end

---@see DandanAPI.DandanAPI_Comment_GetComment
---@param params DandanAPI_Comment_GetComment_Parameters 
---@return asyncio.Coroutine<FutureResult<DandanAPICommentResponseV2>>
function M.get_comment(params)
return async(function()
    if params.episodeId == nil or type(params.episodeId) ~= "number" then
        return {ok = false, error = string.format('DandanAPI.get_comment: invalid episodeId %s', params.episodeId)}
    end
    local headers = {}
    local path = api_v2(string.format('/search/comment/%d', params.episodeId))
    params.episodeId = nil
    _signature_headers(headers, path)
    local result = await(curl.get(
        api_url(path), {
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

function DananplayProvider:process_url(url, nodata)
return async(function()
    
end)
end

function DananplayProvider:process_path(path, nodata)
return async(function()
    local filename, err = await(normalize(path))
    if err then
        return base.new_process_error(err)
    end
    ---@cast filename -?
    
end)
end

---@param path string
local function get_file_pre16M_hash(path)
    
end

---@param path? string
---@param filehash? string
---@param filesize? int
---@param duration? int
---@param hashonly? boolean
---@param nameonly? boolean
---@param nodata? boolean
function DananplayProvider:match(path, filehash, filesize, duration, hashonly, nameonly, nodata)
return async(function()
    local mode = hashonly and "hashOnly" or (nameonly and "fileNameOnly" or "hashAndFileName")
    local body = {
        fileName = path,
        fileSize = filesize or 1, 
        fileHash = filehash or '00000000000000000000000000000000',
        videoDuration = duration or 0,
        matchMode = mode,
    }
    if not nameonly and filehash == nil and path ~= nil then
        body.fileHash = get_file_pre16M_hash(path)
    end
    if not body.fileName and not body.fileHash then
        return base.new_process_error('DandanAPI match required path or filehash')
    end
    local result = await(M.match(body))
    if not result.ok or not result.result then
        return base.new_process_error(result.error or 'DandanAPI error')
    end
    local match = result.result
    if not match.success or match.errorCode ~= 0 then
        return base.new_process_error(string.format(
            'DandanAPI error: %s%s', match.errorMessage or '', match.errorDetail or ''))
    end
    -- if match.isMatched then
    --     return
    -- end
    return {result = match}
end)
end

function DananplayProvider:search()
    
end

local danmaku_type_map = {
    [1] = 1, -- SCROLL
    [4] = 3, -- BOTTOM
    [5] = 2, -- TOP
}

---@param epid int
function DananplayProvider:process_epid(epid, url, with_related, nodata)
return async(function()
    local result = await(M.get_comment({
        episodeId = epid,
        withRelated = false,
        chConvert = 1,
    }))
    if result.error ~= nil or not result.result then
        return base.new_process_error(result.error or 'dandanplay api error')
    end
    if result.result.count <= 0 or result.result.comments == nil then
        return {}
    end
    local danmakus = fun.totable(fun.map(function(d)
        ---@cast d DandanAPICommentData
        ---@type string[]
        local parts = fun.totable(rex.split(d.p--[[@cast -?]], ','))
        ---@type Danmaku
        return {
            text = d.m,
            time = tonumber(parts[1]),
            type = danmaku_type_map[tonumber(parts[2])] or 1,
            color = string.format('%06X', tonumber(parts[3]) or 0xFFFFFF),
            extra = {
                cid = d.cid,
                userid = tonumber(parts[4])
            }
        }
    end, result.result.comments))
    return base.new_process_result(
        danmakus,
        new_source(epid, url, with_related)
    )
end)
end

M.provider = DananplayProvider

return M