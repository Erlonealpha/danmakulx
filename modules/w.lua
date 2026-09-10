---@class tagtool_w
local _M = {}

---@alias tagtool_char_type
---| 'ascii'
---| 'latin'
---| 'combining_mark'
---| 'korean_jamo'
---| 'cjk'
---| 'korean_syllable'
---| 'cjk_compat'
---| 'vertical_punctuation'
---| 'cjk_symbol'
---| 'fullwidth_ascii'
---| 'cjk_extension'
---| 'emoji'
---| 'other'
---| 'invalid'

---@type table<tagtool_char_type, number>
_M.default_weights = {
    ascii = 1,
    latin = 1,
    combining_mark = 0,
    korean_jamo = 2,
    cjk = 2,
    korean_syllable = 2,
    cjk_compat = 2,
    vertical_punctuation = 2,
    cjk_symbol = 2,
    fullwidth_ascii = 2,
    cjk_extension = 2,
    emoji = 2,
    other = 1,
    invalid = 1,
}

---@param b1 integer
---@param b2 integer?
---@param b3 integer?
---@param b4 integer?
---@return integer|nil codepoint
---@return integer size
local function decode_utf8_char(b1, b2, b3, b4)
    if not b1 then
        return nil, 0
    end

    if b1 < 0x80 then
        return b1, 1
    end

    if b1 >= 0xC2 and b1 <= 0xDF and b2 and b2 >= 0x80 and b2 <= 0xBF then
        return (b1 % 0x20) * 0x40 + (b2 % 0x40), 2
    end

    if b1 >= 0xE0 and b1 <= 0xEF and b2 and b3
        and b2 >= 0x80 and b2 <= 0xBF
        and b3 >= 0x80 and b3 <= 0xBF then
        return (b1 % 0x10) * 0x1000 + (b2 % 0x40) * 0x40 + (b3 % 0x40), 3
    end

    if b1 >= 0xF0 and b1 <= 0xF4 and b2 and b3 and b4
        and b2 >= 0x80 and b2 <= 0xBF
        and b3 >= 0x80 and b3 <= 0xBF
        and b4 >= 0x80 and b4 <= 0xBF then
        return (b1 % 0x08) * 0x40000 + (b2 % 0x40) * 0x1000 + (b3 % 0x40) * 0x40 + (b4 % 0x40), 4
    end

    return nil, 1
end

---@param codepoint integer|nil
---@return tagtool_char_type
local function get_char_type(codepoint)
    if not codepoint then
        return 'invalid'
    end

    if codepoint <= 0x7F then
        return 'ascii'
    elseif codepoint >= 0x0300 and codepoint <= 0x036F then
        return 'combining_mark'
    elseif codepoint >= 0x0080 and codepoint <= 0x024F then
        return 'latin'
    elseif codepoint >= 0x1100 and codepoint <= 0x115F then
        return 'korean_jamo'
    elseif codepoint >= 0x2E80 and codepoint <= 0xA4CF then
        return 'cjk'
    elseif codepoint >= 0xAC00 and codepoint <= 0xD7AF then
        return 'korean_syllable'
    elseif codepoint >= 0xF900 and codepoint <= 0xFAFF then
        return 'cjk_compat'
    elseif codepoint >= 0xFE10 and codepoint <= 0xFE19 then
        return 'vertical_punctuation'
    elseif codepoint >= 0xFE30 and codepoint <= 0xFE6F then
        return 'cjk_symbol'
    elseif codepoint >= 0xFF00 and codepoint <= 0xFFEF then
        return 'fullwidth_ascii'
    elseif codepoint >= 0x20000 and codepoint <= 0x3FFFF then
        return 'cjk_extension'
    elseif codepoint >= 0x1F300 and codepoint <= 0x1FAFF then
        return 'emoji'
    end

    return 'other'
end

---@param codepoint integer|nil
---@return tagtool_char_type
function _M.char_type(codepoint)
    return get_char_type(codepoint)
end

---@param str string
---@param weights? table<tagtool_char_type, number> character type weight overrides
---@return number
function _M.string_weight(str, weights)
    local total = 0
    local i = 1
    local len = #str

    while i <= len do
        local b1 = string.byte(str, i)
        local b2 = string.byte(str, i + 1)
        local b3 = string.byte(str, i + 2)
        local b4 = string.byte(str, i + 3)
        local codepoint, size = decode_utf8_char(b1, b2, b3, b4)
        local char_type = get_char_type(codepoint)
        local weight = weights and weights[char_type] or nil

        if weight == nil then
            weight = _M.default_weights[char_type] or _M.default_weights.other
        end

        total = total + weight
        i = i + size
    end

    return total
end

_M.weight = _M.string_weight

return _M
