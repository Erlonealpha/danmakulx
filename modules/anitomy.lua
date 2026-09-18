local mp = require 'mp'
local amp = require 'elxlibs.asyncio.amp'
local json = require("elxlib.elxlibs.json")
local loops = require("elxlib.elxlibs.asyncio.loops")

local bin = mp.get_script_directory() .. '/bin/anitomy'

---@alias _OneOrList<T> T|T[]

---@class AnitomyParseResult
---@field audio_term _OneOrList<string>
---@field device _OneOrList<string>
---@field episode _OneOrList<string>
---@field episode_title _OneOrList<string>
---@field file_checksum _OneOrList<string>
---@field file_extension _OneOrList<string>
---@field language _OneOrList<string>
---@field other _OneOrList<string>
---@field part _OneOrList<string>
---@field release_group _OneOrList<string>
---@field release_information _OneOrList<string>
---@field release_version _OneOrList<string>
---@field season _OneOrList<string>
---@field source _OneOrList<string>
---@field subtitles _OneOrList<string>
---@field title string
---@field type _OneOrList<string>
---@field video_resolution _OneOrList<string>
---@field video_term _OneOrList<string>
---@field volume _OneOrList<string>
---@field year _OneOrList<string>

---@async
---@param filename string
---@return asyncio.Coroutine<FutureResult<AnitomyParseResult>>
local function parse(filename)
return async(function()
    local fut = loops.get_running_loop():create_future()
    amp.command_native_async({
        args = {bin, '--format=json', '"' .. filename .. '"'},
        name = 'subprocess',
        playback_only = false,
        capture_stdout = true,
        capture_stderr = true,
    }, function(success, result, error)
        if not success or result.status ~= 0 or error or not result.stdout then
            fut:set_result({ok = false, error = error or result.stderr})
        else
            fut:set_result({ok = true, result = json.loads(result.stdout)})
        end
    end)
    return await(fut)
end)
end

return parse
