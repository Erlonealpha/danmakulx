local anitomy_parse = require 'modules.anitomy'
local rex = require 'elxlib.elxlibs.rex'
local fun = require 'elxlib.elxlibs.fun'

---@alias _ExtractOne<T> T extends [] and T[1] or T

---@generic K, T
---@param data table<K, T>
---@return table<K, _ExtractOne<T>>
local function take_one(data)
    for k, v in pairs(data) do
        if type(v) == "table" then
            data[k] = v[1]
        end
    end
    return data
end

---@async
---@param path string
---@param keep int?
local function normalize_path(path, keep)
return async(function()
    local splits = {}
    for s in rex.split(path, [[/|\\]]) do
        table.insert(splits, s)
    end
    local n = #splits
    local filename
    if not keep or keep <= 0 or n <= 1 then
        filename = splits[n]
    else
        local start = n - math.min(n, keep) + 1
        filename = fun.str_concat(fun.map(function (i) return splits[i] end, fun.range(start, n)), ' ')
    end
    ---@cast filename string
    local result = await(anitomy_parse(filename))
    if result.ok then
        local fmt = string.format
        ---@cast result.result -?
        local parsed = take_one(result.result)
        local rv = parsed.title
        local extra = {}
        if parsed.year then
            table.insert(extra, parsed.year)
        end
        if parsed.season then
            table.insert(extra, fmt('S%02d', parsed.season))
        end
        if parsed.episode ~= nil then
            table.insert(extra, fmt('E%02d', parsed.episode))
        end
        if parsed.episode_title then
            table.insert(extra, parsed.episode_title)
        end
        if #extra > 0 then
            rv = rv .. ' ' .. table.concat(extra, ' ')
        end
        return rv, nil
    else
        ---@diagnostic disable-next-line: redundant-return-value
        ---@cast result.error -?
        return nil, result.error
    end
end)
end

return normalize_path
