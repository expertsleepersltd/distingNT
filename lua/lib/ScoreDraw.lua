-- score_draw.lua ------------------------------------------------------------
-- Converts a list of note events into drawing primitives for a 256×64 display
-- Author: ChatGPT (2025‑04‑20)
local ScoreDraw = {}

--------------------------------------------------------------------------------
-- Defaults
--------------------------------------------------------------------------------
local DEFAULTS = {
    -- Canvas dimensions
    width = 255, -- total pixels horizontally
    height = 64, -- total pixels vertically
    left_margin = 8, -- px before the first staff line starts
    right_margin = 8, -- px after last note

    -- Staff layout
    staff_top = 22, -- y‑pixel of the top staff line
    staff_spacing = 4, -- distance in px between adjacent staff lines
    semitone_px = 2, -- vertical distance per semitone
    ledger_limit = 2, -- how many ledger lines above/below before clipping

    -- Note appearance
    ledger_line_extent_w = 5, -- width of ledger line extensions in px
    note_head_h = 3 -- height of a note head in px
}

--------------------------------------------------------------------------------
-- Utility helpers
--------------------------------------------------------------------------------
local function merge(a, b)
    local t = {}
    for k, v in pairs(a) do t[k] = v end
    if b then for k, v in pairs(b) do t[k] = v end end
    return t
end

local function max(a, b) return (a > b) and a or b end
local function min(a, b) return (a < b) and a or b end

local function ensure_times(tbl)
    if tbl[1] and tbl[1].time ~= nil then return end -- nothing to do
    for i, ev in ipairs(tbl) do
        ev.time = i - 1 -- 0‑based timeline
        ev.duration = ev.duration or 1
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------
---@param events table[]  -- {time,duration,pitch,velocity}
---@param opts   table?   -- override DEFAULTS
---@return table[]        -- list of drawing instruction tables
function ScoreDraw.generate(events, opts)
    opts = merge(DEFAULTS, opts or {})
    ensure_times(events) -- Add sequential times if the user didn't supply them
    assert(#events > 0, "events table may not be empty")

    --------------------------------------------------------------------------
    -- 1. Determine time & pitch range
    --------------------------------------------------------------------------
    local last_beat, lo_pitch, hi_pitch = 0, events[1].pitch, events[1].pitch
    for _, ev in ipairs(events) do
        last_beat = max(last_beat, ev.time + ev.duration)
        lo_pitch = min(lo_pitch, ev.pitch)
        hi_pitch = max(hi_pitch, ev.pitch)
    end

    -- Expand pitch range so the outermost note sits nicely inside the staff
    local mid_pitch = math.floor((lo_pitch + hi_pitch) / 2 + 0.5)
    local staff_middle = mid_pitch -- MIDI number

    --------------------------------------------------------------------------
    -- 2. Mapping helpers
    --------------------------------------------------------------------------
    local usable_w = opts.width - opts.left_margin - opts.right_margin
    local function time2x(t)
        return opts.left_margin + (t / last_beat) * usable_w
    end

    -- Calculate the Y coordinate of the actual middle staff line (line index 2)
    local middle_line_y = opts.staff_top + (opts.staff_spacing * 2)

    local function pitch2y(p)
        -- Positive direction: down the screen

        -- 1. Calculate raw vertical offset based on semitones from middle pitch
        local raw_offset = (staff_middle - p) * opts.semitone_px

        -- 2. Calculate how many "half-spaces" this offset represents
        --    (A half-space is the distance from a line to a space center, or vice-versa)
        local half_space_distance = opts.staff_spacing / 2
        local half_space_steps = raw_offset / half_space_distance

        -- 3. Round to the nearest integer number of half-steps
        local quantized_steps = math.floor(half_space_steps + 0.5)

        -- 4. Calculate the final Y based on the middle line and quantized steps
        local final_y = middle_line_y + quantized_steps * half_space_distance

        return final_y
    end

    --------------------------------------------------------------------------
    -- 3. Start drawing list with staff lines
    --------------------------------------------------------------------------
    local inst = {}
    local staff_y0 = opts.staff_top
    for i = 0, 4 do
        local y = staff_y0 + i * opts.staff_spacing
        inst[#inst + 1] = {
            type = "line",
            x1 = opts.left_margin,
            y1 = y,
            x2 = opts.width - opts.right_margin,
            y2 = y
        }
    end

    --------------------------------------------------------------------------
    -- 4. Notes & ledger lines
    --------------------------------------------------------------------------
    for _, ev in ipairs(events) do
        -- Calculate screen coordinates and dimensions
        local start_x = time2x(ev.time)
        local end_x = time2x(ev.time + ev.duration)
        local y = pitch2y(ev.pitch)
        local head_h = opts.note_head_h
        local note_width = max(1, end_x - start_x) -- Ensure minimum width of 1px

        -- Map velocity (0-127) to grayscale (1 to 14)
        -- Maps 0 -> 1 (dark), 127 -> 14 (light gray)
        -- Higher velocity = lighter color (higher index)
        local color_val = 1 + math.floor(ev.velocity * 14 / 128)
        -- Clamp to range [1, 14] (redundant now but safe)
        color_val = max(1, min(14, color_val))

        -- Add instruction to draw the filled note rectangle with color 'c'
        inst[#inst + 1] = {
            type = "filled_rect",
            x = start_x,
            y = y - head_h / 2,
            w = note_width,
            h = head_h,
            c = color_val -- Use calculated grayscale color
        }

        ----------------------------------------------------------------------
        -- Ledger lines if needed (adjust x reference)
        ----------------------------------------------------------------------
        local ledger_pitch = ev.pitch -- Keep using pitch for calculation relative to middle
        local ledger_x = start_x -- Use start_x for ledger line horizontal position
        local ledger_half_w = opts.ledger_line_extent_w / 2 -- Use renamed option for ledger line extent

        -- Calculate the Y positions of the top and bottom staff lines
        local staff_y0 = opts.staff_top
        local staff_y4 = staff_y0 + 4 * opts.staff_spacing

        -- Check if the note's Y position is outside the main staff lines
        if y < staff_y0 or y > staff_y4 then
            -- Determine if the note's Y position corresponds to a line or a space
            -- Relative to the middle line, lines occur at even numbers of half_space_steps
            local raw_offset_check = (staff_middle - ledger_pitch) *
                                         opts.semitone_px
            local half_space_steps_check = raw_offset_check /
                                               (opts.staff_spacing / 2)
            local quantized_steps_check = math.floor(
                                              half_space_steps_check + 0.5)

            -- Only draw ledger lines if the note is supposed to be ON a line (even steps from middle)
            if quantized_steps_check % 2 == 0 then
                local lines_drawn = 0
                local current_line_y

                if y < staff_y0 then -- Note is above the staff
                    current_line_y = staff_y0 - opts.staff_spacing -- Start checking from the line above the top staff line
                    while current_line_y >= y and lines_drawn <
                        opts.ledger_limit do
                        -- Check if this ledger line's Y position is close enough to the note's Y
                        if math.abs(current_line_y - y) <
                            (opts.staff_spacing / 4) then
                            inst[#inst + 1] = {
                                type = "line",
                                x1 = ledger_x - ledger_half_w,
                                y1 = current_line_y,
                                x2 = ledger_x + ledger_half_w,
                                y2 = current_line_y,
                                c = 15 -- White color for ledger lines
                            }
                        end
                        lines_drawn = lines_drawn + 1
                        current_line_y = current_line_y - opts.staff_spacing -- Move to the next potential ledger line up
                    end
                else -- Note is below the staff
                    current_line_y = staff_y4 + opts.staff_spacing -- Start checking from the line below the bottom staff line
                    while current_line_y <= y and lines_drawn <
                        opts.ledger_limit do
                        -- Check if this ledger line's Y position is close enough to the note's Y
                        if math.abs(current_line_y - y) <
                            (opts.staff_spacing / 4) then
                            inst[#inst + 1] = {
                                type = "line",
                                x1 = ledger_x - ledger_half_w,
                                y1 = current_line_y,
                                x2 = ledger_x + ledger_half_w,
                                y2 = current_line_y,
                                c = 15 -- White color for ledger lines
                            }
                        end
                        lines_drawn = lines_drawn + 1
                        current_line_y = current_line_y + opts.staff_spacing -- Move to the next potential ledger line down
                    end
                end
            end
        end
    end

    return inst, time2x, pitch2y, opts -- Return mapping functions and options too
end

return ScoreDraw
