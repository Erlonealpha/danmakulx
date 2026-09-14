---@diagnostic disable: return-type-mismatch Emmylua why

local mp = require 'mp'
local std = require 'elxlibs.std'
local bilibili = require 'sources.bilibili'
local bahamut = require 'sources.bahamut'
local dandanplay = require 'sources.dandanplay'

local M = {}

---@class SourceManager : std.object
---@overload fun():self
local SourceManager = std.class.new('SourceManager')

function SourceManager:__init()
	---@type SourceProviderBase[]
	self.source_providers = {
		bilibili.provider(),
		bahamut.provider(),
		dandanplay.provider(),
	}
end

---@async
---@param url string
---@param source string?
---@param no_data boolean?
---@return asyncio.Coroutine<_ProcessResult?>
function SourceManager:process_url(url, source, no_data)
return async(function()
	debug_msgf('SourceManager:process_url %s %s %s', url, source, no_data)
	if source ~= nil then
		for _, source_provider in ipairs(self.source_providers) do
			if source_provider.name == source then
				local result = await(source_provider:process_url(url))
				if result ~= nil then
					if result.error ~= nil then
						mp.msg.warn('SourceManager:process_url error:', result.error)
					else
						---@cast result _ProcessResult
						return result
					end
				end
				break
			end
		end
	else
		for _, source_provider in ipairs(self.source_providers) do
			local result = await(source_provider:process_url(url))
			if result == nil then -- continue
			else
				if result.error ~= nil then
					mp.msg.warn('SourceManager:process_url error:', result.error)
				else
					---@cast result _ProcessResult
					return result
				end
			end
		end
	end
end)
end

---@async
---@param path string
---@param source string?
---@return asyncio.Coroutine<_ProcessResult?>
function SourceManager:process_path(path, source, no_data)
return async(function()
	debug_msgf('SourceManager:process_path %s %s %s', path, source, no_data)
	if source ~= nil then
		for _, source_provider in ipairs(self.source_providers) do
			if source_provider.name == source then
				local result = await(source_provider:process_path(path))
				if result ~= nil then
					if result.error ~= nil then
						mp.msg.warn('SourceManager:process_path error:', result.error)
					else
						---@cast result _ProcessResult
						return result
					end
				end
				break
			end
		end
	else
		for _, source_provider in ipairs(self.source_providers) do
			local result = await(source_provider:process_path(path))
			if result == nil then -- continue
			else
				if result.error ~= nil then
					mp.msg.warn('SourceManager:process_path error:', result.error)
				else
					---@cast result _ProcessResult
					return result
				end
			end
		end
	end
end)
end


M.SourceManager = SourceManager

return M