-- A six element shift register
--[[
Input a CV and a Gate, the CV value will shift down the outputs at each gate.
]] --[[
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
local stack = {0, 0, 0, 0, 0, 0}
local gateHigh = false
local sampled = false

return {
    name = "ShiftRegister",
    author = "Thorinside",

    init = function(self)
        return {
            inputs = {kCV, kGate}, -- CV input and Gate/Trigger input
            outputs = 6, -- Number of output CV slots (stack size)
            inputNames = {"CV", "Gate"},
            outputNames = {"CV 1", "CV 2", "CV 3", "CV 4", "CV 5", "CV 6"},
            parameters = {}
        }
    end,

    gate = function(self, input, rising)
        if input == 2 then
            if rising then
                gateHigh = true
                sampled = false
            else
                gateHigh = false
            end
        end
    end,

    step = function(self, dt, inputs)
        if gateHigh and not sampled then
            -- Store the current sample value at the beginning of the stack
            table.insert(stack, 1, inputs[1]) -- Insert the new CV voltage at the start

            -- Keep only the last 6 samples
            while #stack > 6 do table.remove(stack) end -- Remove from the end if stack exceeds 6

            sampled = true
        end

        return stack
    end,

    draw = function(self)
        drawTinyText(10, 10, "Shift Register")
        -- Display gate status at the top-left corner
        drawTinyText(225, 34, gateHigh and "GATE" or "")

        -- Define the stack visualization area
        local maxVoltage = 12 -- Maximum expected magnitude of CV voltage
        local zeroY = 32 -- Y-coordinate for zero voltage (mid-height for 64-pixel screen)
        local scale = 25 / maxVoltage -- Scale factor for visualization (fit within ±30 pixels)
        local blockWidth = 30 -- Width of each block
        local blockSpacing = 5 -- Space between blocks

        -- Start drawing the stack visualization
        for i = 1, 6 do
            local voltage = stack[i] or 0 -- Safely get the voltage, defaulting to 0 if nil
            local x1 = 10 + (i - 1) * (blockWidth + blockSpacing) -- Left of the block
            local x2 = x1 + blockWidth -- Right of the block

            -- Calculate the block height and Y-coordinates based on the voltage
            local blockHeight = math.abs(math.floor(voltage * scale)) -- Height proportional to voltage magnitude
            local y1, y2
            if voltage >= 0 then
                y1 = zeroY - blockHeight -- Positive voltage extends upward
                y2 = zeroY -- Bottom of the block is at the zero line
            else
                y1 = zeroY -- Top of the block is at the zero line
                y2 = zeroY + blockHeight -- Negative voltage extends downward
            end

            -- Ensure the block doesn't draw offscreen
            if x2 <= 256 and y2 <= 64 and y1 >= 0 then
                -- Draw the block background (for visibility)
                drawRectangle(x1, zeroY - 1, x2, zeroY + 1, 2) -- Zero line indicator

                -- Draw the voltage level as a filled block
                local brightness = math.floor(
                                       (math.abs(voltage) / maxVoltage) * 15)
                drawRectangle(x1, y1, x2, y2, brightness)
            end
        end
        return true -- Take over the screen
    end
}
