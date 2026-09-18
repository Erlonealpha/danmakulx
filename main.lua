local mp = require 'mp'
mp.utils = require 'mp.utils'

local elxlib = require 'elxlib_load'
local amp = require 'elxlibs.asyncio.amp'
local asyncio = require 'elxlibs.asyncio'

async = asyncio.async
await = asyncio.await
try = elxlib.std.try
catch = elxlib.std.catch
finally = elxlib.std.finally

local options = require 'modules.options'


function debug_msg(arg0, ...)
    if options.debug then
        if type(arg0) == "function" then
            mp.msg.info('DEBUG', arg0())
        else
            mp.msg.info('DEBUG', arg0, ...)
        end
    end
end

function debug_msgf(arg0, ...)
    if options.debug then
        mp.msg.info('DEBUG', string.format(arg0, ...))
    end
end


---@alias file_info {
---     dir: string,
---     path: string,
---     filename: string,
---     duration: number,
---     fps: number,
---     is_video: boolean,
--- }

local state = {
    ---@type file_info?
    info = nil,

    ---@type SourceManager?
    source_manager = nil,
}


local function autoload()
    
end

local function is_video()
    
end

amp.register_event('file-loaded', function()
    debug_msg('file loaded')
    state.info = state.info or {}
    local info = state.info

    info.path = mp.get_property("path")
    info.dir, info.filename = mp.utils.split_path(info.path)
    info.duration = mp.get_property_number("duration", 0)
    info.fps = mp.get_property_number("container-fps", 0)
    info.is_video = is_video()
end)

amp.register_script_message('add', function(...)
    
end)

require 'test'
