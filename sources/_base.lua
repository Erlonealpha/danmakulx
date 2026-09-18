local std = require 'elxlibs.std'

local M = {}

---@alias FutureResult<T> {
---     ok: boolean,
---     result?: T,
---     error?: string,
--- }

---@alias ProcessResult {
---     data?: Danmaku[],
---     source?: SourceBase,
---     error?: string
--- }

---@alias _ProcessResult {
---     data: Danmaku[],
---     source: SourceBase,
--- }

---@interface SourceBase
---@field id string
---@field name string
---@field delay? number

---@interface SourceProviderBase
---@field name string
---@field process_url fun(s: self, url: string, nodata: boolean):asyncio.Awaitable<ProcessResult?>?
---@field process_path fun(s: self, path: string, nodata: boolean):asyncio.Awaitable<ProcessResult?>?
local SourceProviderBase = std.class.new("SourceProviderBase")
function SourceProviderBase:process_url(url)
end
function SourceProviderBase:process_path(path)
end

---@param data Danmaku[]
---@param source SourceBase
---@return _ProcessResult
function M.new_process_result(data, source)
    return {
        data = data,
        source = source,
    }
end

---@param err string
---@return ProcessResult
function M.new_process_error(err)
    return {error = err}
end


M.SourceProviderBase = SourceProviderBase

return M