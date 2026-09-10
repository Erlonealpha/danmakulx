local amp = require("elxlibs.asyncio.amp")

local M = {}

--[[
Options<select one>
    --url  -u add from url
    --path -p add from path
]]
function M.command_add(arg0, ...)
    
end

--[[
Options<select one>
    --source-id     -si remove from source id
    --source-name   -sn remove from source name
    --url           -u  remove from url
    --path          -p  remove from path
]]
function M.command_remove(arg0, ...)
    
end

--[[
Sub-Commands:
    sources
        --filter        -f
    source
        --source-id     -si
        --source-name   -sn
    render
]]
function M.command_show(arg0, ...)
    
end

function M._parse_commands(callbacks)
    
end


amp.register_script_message('add', M.command_add)
amp.register_script_message('remove', M.command_remove)
amp.register_script_message('show', M.command_show)
