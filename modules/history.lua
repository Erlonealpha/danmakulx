local mp = require 'mp'
local fs = require 'elxlibs.fs'
local json = require 'elxlibs.json'


local M = {}

---@alias History {}

local state = {
    ---@type History?
    his = nil
}

---@param path string
---@overload fun(path: string):true
---@overload fun(path: string):false, string
function M.load_history(path)
    local fp, err = io.open(path, 'r')
    if fp == nil or err then
        return false, string.format('load_history: cannot open the history file %s, %s', path, err)
    end
    local content = fp:read("a")
    local parse_err, data
    try {
        function ()
            data = json.loads(content)
        end,
        catch {
            function (e)
                parse_err = e
            end
        }
    }
    if parse_err or not data then
        return false, string.format('load_history: %s', parse_err or 'parsed empty data')
    end
    state.his = data
end

---@param path string
---@param his? History
---@overload fun(path: string, his?: History):true
---@overload fun(path: string, his?: History):false, string
function M.save_history(path, his)
    local dir, _ = mp.utils.split_path(path)
    if dir and not fs.exists(dir) then
        local ok, err = fs.create_dir(dir, true)
        if not ok then
            return false, string.format('save_history: create history folder error, %s', err)
        end
    end

    his = his or state.his
    if his == nil then
        return false, 'save_history: empty history'
    end

    local fp, err = io.open(path, 'w')
    if fp == nil or err then
        return false, string.format('save_history: cannot open the history file %s, %s', path, err)
    end
    local write_err
    try {
        function ()
            fp:write(json.dumps(his, 2))
        end,
        catch {
            function (err_)
                write_err = err_
            end
        },
        finally {
            function ()
                fp:close()
            end
        }
    }
    if write_err ~= nil then
        return false, string.format('save_history: %s', write_err)
    end

    return true
end


return M