-- simple validator

local validators = {}
local va = validators
local operator = {}

---@alias RawValidator fun(name: string, value: any)

---@alias validator.operators
--- | ">"
--- | ">="
--- | "<"
--- | "<="

---@param bound number
---@param op validator.operators
---@param op_func fun(a: number, b: number):boolean
---@return RawValidator
local function _number_validator(bound, op, op_func)
    return function (name, value)
        if not op_func(value, bound) then
            error(string.format('%s must be %s %s: %s', name, op, bound, value))
        end
    end
end

function operator.gt(a, b)
    return a > b
end

function operator.ge(a, b)
    return a >= b
end

function operator.lt(a, b)
    return a < b
end

function operator.le(a, b)
    return a <= b
end

---@param val number
---@return RawValidator
function va.gt(val)
    return _number_validator(val, ">", operator.gt)
end

---@param val number
---@return RawValidator
function va.ge(val)
    return _number_validator(val, ">=", operator.ge)
end

---@param val number
---@return RawValidator
function va.lt(val)
    return _number_validator(val, "<", operator.lt)
end

---@param val number
---@return RawValidator
function va.le(val)
    return _number_validator(val, "<=", operator.le)
end

---@param vals any[]
---@return RawValidator
function va.in_(vals)
    return function(name, value)
        local any_ok
        for _, val in ipairs(vals) do
            any_ok = val == value
            if any_ok then
                break
            end
        end
        if not any_ok then
            local function t_tostring()
                local t = {}
                for i, val in ipairs(vals) do
                    t[i] = tostring(val)
                end
                return t
            end
            error(string.format('%s must in %s (got %s)', name, table.concat(t_tostring(), ', '), value))
        end
    end
end

---@param ... RawValidator
---@return RawValidator
function va.and_(...)
    local vlidators = {...}
    return function (name, value)
        for _, v in ipairs(vlidators) do
            v(name, value)
        end
    end
end

---@param validator RawValidator
---@return RawValidator
function va.not_(validator)
    return function (name, value)
        local ok, _ = xpcall(function()
            validator(name, value)
        end, debug.traceback)
        if not ok then
            error(string.format('not validator %s did not raise error', validator))
        end
    end
end

---@param ... RawValidator
---@return RawValidator
function va.or_(...)
    local vlidators = {...}
    return function(name, value)
        local ok
        for _, v in ipairs(vlidators) do
            v(name, value)
            ok = true
        end
        if not ok then
            error(string.format('Not any validators satisfied for value %s', value))
        end
    end
end

---@param typ std.type
---@return RawValidator
function va.type_of(typ)
    return function(name, value)
        local t = type(value)
        if t ~= typ then
            error(string.format('%s must be %s (got %s that is %s)', name, typ, value, t))
        end
    end
end

return validators
