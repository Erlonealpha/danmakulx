local std = require 'elxlibs.std'
local utils = require 'modules/utils'

local M = {}

---@alias DanmakuTrack {
---     time: number,
---     width: number,
---     v: number,
--- }

---@class DanmakuTracks : std.object
---@field tracks DanmakuTrack[]
---@field _max_tracks int
---@field max_tracks int
---@overload fun(res_x: int, res_y: int, height: number, max_tracks?: int, max_overlapped?: int):self
local DanmakuTracks = std.class.new("DanmakuTracks")
---@param res_x int
---@param res_y int
---@param height number
---@param max_tracks int
---@param max_overlapped? int
function DanmakuTracks:__init(res_x, res_y, height, max_tracks, max_overlapped)
    self.res_x = res_x
    self.res_y = res_y
    self.height = height
    self._max_tracks = self:_get_max_tracks()
    if max_tracks ~= nil and max_tracks > 0 then
        self._max_tracks_from_user = true
        self.max_tracks = math.min(self._max_tracks, max_tracks)
    else
        self.max_tracks = self._max_tracks
    end
    debug_msgf('DanmakuTracks:__init max_tracks %d of %d', self.max_tracks, self._max_tracks)
    self.tracks = {}
    self.overlapped_tracks = {}
    self.max_overlapped = max_overlapped or 6
end

function DanmakuTracks:_get_max_tracks()
    return math.max(math.floor(self.res_y / self.height), 1)
end

function DanmakuTracks:clear()
    self.tracks = {}
    self.overlapped_tracks = {}
end

---@param opts Partial<{
---     height: number,
---     res_x: number,
---     res_y: number,
---     max_tracks: int,
---     max_overlapped: int
--- }>
function DanmakuTracks:update(opts)
    for k, v in pairs(opts) do
        self:_update(k, v)
    end
end

---@param k string
---@param v any
function DanmakuTracks:_update(k, v)
    if k == "res_x" then
        self.res_x = v
    elseif k == "res_y" or k == "height" then
        self[k] = v
        self._max_tracks = self:_get_max_tracks()
        if self.max_tracks > self._max_tracks or not self._max_tracks_from_user then
            self.max_tracks = self._max_tracks
        end
    elseif k == "max_tracks" then
        self.max_tracks = math.min(self._max_tracks, v)
        self._max_tracks_from_user = true
    elseif k == "max_overlapped" then
        self.max_overlapped = v
    end
end

---@param n int
---@param overlap_n int?
function DanmakuTracks:get(n, overlap_n)
    local tracks
    if overlap_n ~= nil and overlap_n > 0 then
        tracks = self.overlapped_tracks[overlap_n]
        if tracks == nil then
            tracks = {}
            self.overlapped_tracks[overlap_n] = tracks
        end
    else
        tracks = self.tracks
    end
    local track = tracks[n]
    if track == nil then
        track = {time = -1, width = -1, v = -1}
        ---@cast track DanmakuTrack
        tracks[n] = track
    end
    return track
end

---@param start int?
---@param end_ int?
---@param step int?
---@param overlap boolean?
function DanmakuTracks:iter(start, end_, step, overlap)
    local i = start or 1
    local e = end_ or self.max_tracks
    local s = step or 1
    local f = s > 0
    local overlap_n = 0
    return function ()
        if (f and i > e) or (not f and i < e) then
            if overlap then
                i = start or 1
                overlap_n = overlap_n + 1
                if overlap_n > self.max_overlapped then
                    return
                end
            else
                return
            end
        end
        local _i = i
        local track = self:get(i, overlap_n)
        i = i + s
        return _i, track
    end
end

---@param n int
function DanmakuTracks:track_y(n)
    return 1 + (n - 1) * self.height
end

M.DanmakuTracks = DanmakuTracks

---@param tracks DanmakuTracks
---@param width number
---@param start_time number
---@param scrolltime number
---@param density "normal" | "more" | "overlap"
---@return number?
function M.get_scroll_y(tracks, width, start_time, scrolltime, density)
    local min_bias, min_diff_x, overlap
    if density == "normal" then
        min_bias = scrolltime * 0.05
        min_diff_x = tracks.res_x * 0.02
    elseif density == "more" then
        min_bias = 0
        min_diff_x = 0
    elseif density == "overlap" then
        min_bias = 0
        min_diff_x = 0
        overlap = true
    else
        error(string.format('unknown danmaku tracks density option %s', density))
    end

    local res_x = tracks.res_x
    local v = (width + res_x) / scrolltime
    for i, track in tracks:iter(1, nil, 1, overlap) do
        if track.time < 0 then
            track.time = start_time
            track.width = width
            track.v = v
            return tracks:track_y(i)
        end

        if track.v < 0 then
            track.v = (track.width + res_x) / scrolltime
        end

        local prev_width = track.width
        local prev_time = track.time
        local prev_v = track.v
        local diff_v = v - prev_v
        local diff_x = (start_time - prev_time) * prev_v - (prev_width + width) / 2

        if diff_x > min_diff_x then
            if diff_v <= 0 then
                track.time = start_time
                track.width = width
                track.v = v
                return tracks:track_y(i)
            end
            local diff_t = diff_x / diff_v
            local bias = start_time - prev_time - diff_t
            local catch_time = prev_time + diff_t
            local distance_prev = prev_v * (catch_time - prev_time)
            if distance_prev > res_x then
                track.time = start_time
                track.width = width
                track.v = v
                return tracks:track_y(i)
            end
            if bias >= min_bias then
                track.time = start_time
                track.width = width
                track.v = v
                return tracks:track_y(i)
            end
        end
    end
end

---@param tracks DanmakuTracks
---@param start_time number
---@param fixedtime number
---@param bottom boolean
---@param density "normal" | "more" | "overlap"
function M.get_fixed_y(tracks, start_time, fixedtime, bottom, density)
    local min_bias, overlap
    local start, end_, step
    if density == "normal" then
        min_bias = fixedtime * 0.05
    elseif density == "more" then
        min_bias = 0
    elseif density == "overlap" then
        min_bias = 0
        overlap = true
    else
        error(string.format('unknown danmaku tracks density option %s', density))
    end
    if bottom then
        start = tracks._max_tracks
        local end_track = tracks._max_tracks - tracks.max_tracks + 1
        if end_track < 1 then
            end_ = 1
        else
            end_ = end_track
        end
        step = -1
    else
        start = 1
        end_ = tracks.max_tracks
        step = 1
    end

    for i, track in tracks:iter(start, end_, step, overlap) do
        local prev_time = track.time
        if prev_time < 0 then
            track.time = start_time
            track.width = 0
            return tracks:track_y(i)
        else
            local bias = start_time - prev_time
            ---@diagnostic disable-next-line: need-check-nil
            if bias > fixedtime + min_bias then
                track.time = start_time
                track.width = 0
                return tracks:track_y(i)
            end
        end
    end
end

---@alias DanmakuScreen {
---     scroll: DanmakuTracks,
---     fixed: DanmakuTracks,
--- }

---@return DanmakuScreen
function M.new_screen(res_x, res_y, height, max_tracks)
    return {
        scroll = DanmakuTracks(res_x, res_y, height, max_tracks),
        fixed = DanmakuTracks(res_x, res_y, height, max_tracks),
    }
end

---@alias _PreparedT { prepared: true, start_time: number, end_time: number, escaped_text: string }
---@alias _PreparedDanmaku (Danmaku & _PreparedT)

---@param event Danmaku
---@return boolean
function M.validate(event)
    return not (event.type == nil or event.type < 0 or event.type > 2)
end

---@param event Danmaku IN OUT
---@param scrolltime number
---@param fixedtime number
---@return _PreparedDanmaku?
function M.prepare(event, scrolltime, fixedtime)
    ---@cast event _PreparedDanmaku
    event.escaped_text = utils.ass_escape(event.text)
    event.start_time = event.time + (event.delay or 0)
    if event.type == 0 then
        event.end_time = event.time + scrolltime + (event.delay or 0)
    elseif event.type == 1 or event.type == 2 then
        event.end_time = event.time + fixedtime + (event.delay or 0)
    else
        return
    end
    event.prepared = true
    return event
end

---@alias _CalcedT {
---     layout_dirty?: boolean,
---     is_move?: boolean, 
---     move?: {x1: number, x2: number, y1: number, y2: number},
---     pos?: {x: number, y: number},
--- }
---@alias _CalcedDanmaku (_PreparedDanmaku & _CalcedT)

---@param event Danmaku & {
---     prepared?: boolean, 
---     layout_dirty?: boolean,
---     start_time?: number,
---     end_time?: number,
---     is_move?: boolean,
---     move?: {x1: number, x2: number, y1: number, y2: number},
---     pos?: {x: number, y: number},
--- } IN OUT
---@param screen DanmakuScreen
---@param opts {
---     scrolltime: number,
---     fixedtime: number,
---     res_x: int,
---     res_y: int,
---     density: "normal" | "more" | "overlap",
--- }
---@return _CalcedDanmaku?
function M.calc_danmaku(event, screen, opts)
    -- debug_msgf('calc_danmaku (%.1f, %.1f) %d %s', event.start_time, event.end_time, event.type, event.text)
    local danmaku = event
    ---@cast danmaku _CalcedDanmaku
    if not event.prepared then
        M.prepare(danmaku, opts.scrolltime, opts.fixedtime)
    end

    if event.layout_dirty ~= false then
        local res_x = opts.res_x
        local text_width = utils.get_str_width(event.text, screen.scroll.height)
        if event.type == 0 then
            local y = M.get_scroll_y(
                screen.scroll, 
                text_width, 
                danmaku.start_time, 
                opts.scrolltime, 
                opts.density
            )
            local x1 = res_x
            local x2 = -text_width
            if y ~= nil then
                danmaku.move = { x1 = x1, x2 = x2, y1 = y, y2 = y}
                danmaku.is_move = true
            end
        elseif event.type == 1 then
            local y = M.get_fixed_y(
                screen.fixed,
                danmaku.start_time,
                opts.fixedtime,
                false,
                opts.density
            )
            local x = res_x / 2
            if y ~= nil then
                danmaku.pos = { x = x, y = y }
                danmaku.is_move = false
            end
        elseif event.type == 2 then
            local y = M.get_fixed_y(
                screen.fixed,
                danmaku.start_time,
                opts.fixedtime,
                true,
                opts.density
            )
            local x = res_x / 2
            if y ~= nil then
                danmaku.pos = { x = x, y = y }
                danmaku.is_move = false
            end
        end
        if danmaku.is_move ~= nil then
            danmaku.layout_dirty = false
        end
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return danmaku
end

return M
