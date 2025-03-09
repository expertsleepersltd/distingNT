-- Octa LFO
-- Eight equally phased sine wave LFO outputs (45° apart).
--[[
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org>]] --
local phase = 0.0
local TWO_PI = 2 * math.pi
local NUM_LFOS = 8

return {
    name = "8 LFOs",
    author = "Thorinside",

    init = function(self)
        -- Pre-allocate the output table with eight zeros.
        self.outs = {}
        for i = 1, NUM_LFOS do self.outs[i] = 0 end
        return {inputs = 1, inputNames = {"FM"}, outputs = NUM_LFOS}
    end,

    step = function(self, dt, inputs)
        -- Use input 1 (if provided) to modulate frequency; base frequency is 1 Hz.
        local freq = 1 + (inputs[1] or 0)
        phase = phase + dt * freq
        -- Wrap phase within [0,1).
        if phase >= 1 then
            phase = phase - 1
        elseif phase < 0 then
            phase = phase + 1
        end

        -- Compute each LFO output with an offset of (i-1)/NUM_LFOS.
        for i = 1, NUM_LFOS do
            local offset = (i - 1) / NUM_LFOS
            local p = phase + offset
            if p >= 1 then p = p - 1 end
            self.outs[i] = 5 * math.sin(p * TWO_PI)
        end

        return self.outs
    end,

    draw = function(self)
        -- Display eight outputs in two columns (4 rows each).
        for i = 1, NUM_LFOS do
            local col = (i <= 4) and 1 or 2
            local row = (i <= 4) and i or i - 4
            local x = (col == 1) and 10 or 80
            local y = 20 + (row - 1) * 15
            drawText(x, y, "LFO " .. i .. ": " ..
                         string.format("%.2f", self.outs[i]) .. " V")
        end
        -- Return true to indicate custom drawing.
        return true
    end
}
