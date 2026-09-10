local std = require 'elxlibs.std'
local source_m = require 'source'
local render_m = require 'render'


---@alias Danmaku {
---     text: string,
---     color: int,
---     type: int,
---     time: int,
---     extra: table,
---     delay: number?,
---     enable: boolean?, 
--- }


---@class Danmakus : std.object
---@overload fun(data: Danmaku[]):self
local Danmakus = std.class.new('Danmakus')
function Danmakus:__init()
end

function Danmakus:filter()
    
end


---@class DanmakuManager : std.object
---@overload fun():DanmakuManager
local DanmakuManager = std.class.new('DanmakuManager')

function DanmakuManager:__init()
    self.source_manager = source_m.SourceManager()
    self.render_backend = render_m
    self.render_backend:start()
    self.render_backend:disable()
    self._source_map = {}
end

---@param url string
---@param source_name string?
function DanmakuManager:process_url(url, source_name)
return async(function()
    local result = await(self.source_manager:process_url(url, source_name))
    if result ~= nil then
        self:add_source(result.source--[[@cast -?]], result.data)
    end
end)
end

function DanmakuManager:process_path(path, source_name)
return async(function()
    local result = await(self.source_manager:process_path(path, source_name))
    if result ~= nil then
        self:add_source(result.source--[[@cast -?]], result.data)
    end
end)
end

---@param source SourceBase
---@param data Danmaku[]?
function DanmakuManager:add_source(source, data)
    if data == nil then
        -- TODO
        return
    end
    self.render_backend:add_source(source, data)
end

---@param source SourceBase
function DanmakuManager:remove_source(source)
    self.render_backend:remove_source(source)
end

function DanmakuManager:clear_sources()
    
end

---@param source SourceBase
function DanmakuManager:enable_source(source)
    self.render_backend:enable_source(source)
end

---@param source SourceBase
function DanmakuManager:disable_source(source)
    self.render_backend:disable_source(source)
end

