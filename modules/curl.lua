local mp = require 'mp'
local amp = require 'elxlibs.asyncio.mp'
local asyncio = require 'elxlibs.asyncio'
local json = require 'elxlibs.json'

local M = {}

local default_ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36'

---@alias RequestMethod 
--- "GET"|
--- "POST"|
--- "PUT"| 
--- "DELETE"| 
--- "PATCH"

---@alias RequestResult {
---     success: boolean,
---     data: string?,
---     error: string?
--- }

---@alias ValidRequestParam string | number | boolean

---@alias RequestOptions {
---     params: table<string, ValidRequestParam?>?,
---     headers: table<string, ValidRequestParam?>?,
---     body: table<string, any?>?,
---     cookies: table<string, string?>?,
---     timeout: number?,
---     disable_redirect: boolean?,
---     user_agent: string?,
---     proxy: string?,
---     extras: string[]?,
--- }

---@async
---@param url string
---@param method RequestMethod
---@param options RequestOptions?
---@return asyncio.Future<RequestResult>
function M.request(url, method, options)
    local args = {'curl', '-X', method}
    local headers = options and options.headers
    local body = options and options.body
    local cookies = options and options.cookies
    local params = options and options.params
    local timeout = options and options.timeout
    local disable_redirect = options and options.disable_redirect
    local user_agent = options and options.user_agent or default_ua
    local proxy = options and options.proxy
    local extras = options and options.extras

    if not disable_redirect then
        table.insert(args, '-L')
    end

    if user_agent then
        table.insert(args, '-A')
        table.insert(args, user_agent)
    end

    if proxy then
        table.insert(args, '-x')
        table.insert(args, proxy)
    end

    if headers then
        for k, v in pairs(headers) do
            table.insert(args, '-H')
            table.insert(args, k..": "..v)
        end
    end

    if body then
        local _d
        if type(body) ~= "string" then
            _d = mp.utils.format_json(body)
        else
            _d = body
        end
        table.insert(args, '-H')
        table.insert(args, 'Content-Type: application/json')
        table.insert(args, '-d')
        table.insert(args, _d)
    end

    if cookies then
        local cookies_parts = {}
        for k, v in pairs(cookies) do
            table.insert(cookies_parts, k.."="..v)
        end
        table.insert(args, '-b')
        table.insert(args, table.concat(cookies_parts, "; "))
    end

    if params then
        local parts = {}
        for k, v in pairs(params) do
            table.insert(parts, k.."="..v)
        end
        url = url.."?"..table.concat(parts, "&")
    end

    if timeout then
        table.insert(args, '-m')
        table.insert(args, tostring(timeout))
    end

    if extras and #extras > 0 then
        for _, extra in ipairs(extras) do
            table.insert(args, extra)
        end
    end

    table.insert(args, url)

    ---@type asyncio.Future<RequestResult>
    local fut = asyncio.loops.get_running_loop():create_future()
    
    debug_msg('curl request', method, url)
    amp.command_native_async({
        name = 'subprocess',
        args = args,
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
        }, function(ok, result, err)
        debug_msg('curl', ok, result.status, err)
        if not ok or not result then
            fut:set_result({success = false, error = err})
            return
        end
        if result.status ~= 0 then
            fut:set_result({success = false, error = result.stderr})
            return
        end
        
        fut:set_result({success = true, data = result.stdout})
    end)

    return fut
end

---@async
---@param url string
---@param options RequestOptions?
function M.get(url, options)
    return M.request(url, "GET", options)
end

---@async
---@param url string
---@param options RequestOptions?
function M.post(url, options)
    return M.request(url, "POST", options)
end

---@async
---@param url string
---@param options RequestOptions?
function M.put(url, options)
    return M.request(url, "PUT", options)
end

---@async
---@param url string
---@param options RequestOptions?
function M.patch(url, options)
    return M.request(url, "PATCH", options)
end

---@async
---@param url string
---@param options RequestOptions?
function M.delete(url, options)
    return M.request(url, "DELETE", options)
end

return M