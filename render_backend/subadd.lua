local mp = require 'mp'
local std = require 'elxlibs.std'
local algo = require 'modules/layout_algo'
local options = require 'modules/options'
local base = require 'render_backend/_base'


---@class DanmakuSubaddRender : DanmakuRenderBackend
---@overload fun():self
---@field _source_map table<string, {source: SourceBase, data: (Danmaku|_PreparedDanmaku)[], enable: boolean}>
local DanmakuSubaddRender = std.class.new('DanmakuSubaddRender')
function DanmakuSubaddRender:__init()
    self.is_rendering = false
    self.is_running = false

    self._options = base.get_optinos()

    self._source_map = {}
end

function DanmakuSubaddRender:start()
    
end

function DanmakuSubaddRender:stop()
    
end

function DanmakuSubaddRender:enable()
    
end

function DanmakuSubaddRender:disable()
    
end

function DanmakuSubaddRender:add_source(source, data)
    if self._source_map[source.id] ~= nil then
        mp.msg.warn('DanmakuSubaddRender: added duplicate source')
    else
        self._source_map[source.id] = { source = source, data = data}
    end
end

function DanmakuSubaddRender:remove_source(source)
    if self._source_map[source.id] == nil then
        mp.msg.warn('DanmakuSubaddRender: cannot remove not exists source', source.id, source.name)
    else
        self._source_map[source.id] = nil
        self._source_dirty = true
    end
end

---@param source SourceBase
function DanmakuSubaddRender:enable_source(source)

end

---@param source SourceBase
function DanmakuSubaddRender:disable_source(source)
    
end

function DanmakuSubaddRender:get_sources()
    return {}
end

function DanmakuSubaddRender:get_source(id)
    
end

function DanmakuSubaddRender:_render()
    if self._source_dirty then
        
    end
    
end

return DanmakuSubaddRender
