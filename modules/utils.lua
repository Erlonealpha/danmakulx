local rex = require 'elxlibs.rex'
local wwidth = require 'modules/w'

local M = {}

local url_query_pattern = rex.safe_new('([^&=?#]+)=([^&#]*)')
---@param url string
function M.parse_query(url)
    local query = {}
    for key, val in rex.unsafe.gmatch(url, url_query_pattern) do
        query[key] = val
    end
    return query
end

---@param string string
---@return int?
function M.tointeger(string)
    local n = tonumber(string)
    if n == nil or n % 1 ~= 0 then
        return
    end
    return n
end

---@param color number
---@return string
function M.hex_rgb2bgr(color)
    color = math.max(0, math.min(color, 0XFFFFFF))
    local hex = string.format("%06X", color)
    return hex:sub(5, 6) .. hex:sub(3, 4) .. hex:sub(1, 2)
end

local _a = 0.53 -- 1.0 * 0.53
local _b = 0.92 -- 1.7 * 0.53
local str_weight_t = {
    ascii = _a,
    latin = _a,
    combining_mark = 0,
    korean_jamo = _b,
    cjk = _b,
    korean_syllable = _b,
    cjk_compat = _b,
    vertical_punctuation = _b,
    cjk_symbol = _b,
    fullwidth_ascii = _b,
    cjk_extension = _b,
    emoji = _b,
    other = _a,
    invalid = _a,
}

---@param text string
---@param font_size number
function M.get_str_width(text, font_size)
    return wwidth.string_weight(text, str_weight_t) * font_size
end

local xml_unescape_patt = rex.safe_new('&(quot|apos|gt|lt|amp);')
local xml_unescape_repl = {
    quot = '"',
    apos = "'",
    gt = '>',
    lt = '<',
    amp = '&',
}
---@param s string
function M.xml_unescape(s)
    return rex.unsafe.gsub(s, xml_unescape_patt, xml_unescape_repl)
end

local ass_escape_patt = rex.safe_new('(\\|{|}|\n)')
local ass_escape_repl = {
    ['\\'] = '\\\\',
    ['{'] = '\\{',
    ['}'] = '\\}',
    ['\n'] = '\\N',
}
---@param s string
function M.ass_escape(s)
    return rex.unsafe.gsub(s, ass_escape_patt, ass_escape_repl)
end

return M