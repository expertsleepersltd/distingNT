-- Quad Bernoulli Gate
--[[
Four incoming gates are probabilistically passed to the outputs. Release
can be immediate (when gate goes low) or sticky, when probability allows.
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

For more information, please refer to <https://unlicense.org>
]] -- 
local gateStates = {0, 0, 0, 0}

return {
    name = "QuadBernoulli",
    author = "Thorinside",

    init = function(self)
        return {
            inputs = {kGate, kGate, kGate, kGate}, -- Four Gate inputs
            outputs = 4, -- Number of output Gates
            parameters = {
                {"P1", 0, 100, 50, kPercent}, {"P2", 0, 100, 50, kPercent},
                {"P3", 0, 100, 50, kPercent}, {"P4", 0, 100, 50, kPercent},
                {"Release", {"Immediate", "Sticky"}, 0}
            }
        }
    end,

    gate = function(self, input, rising)
        local probability = self.parameters[input]
        local rnd = math.random(100)

        if rising then
            if rnd <= probability then gateStates[input] = rising end
        else
            if self.parameters[5] == 0 then -- Immediately release the gate
                gateStates[input] = rising
            else
                if rnd <= probability then -- Sticky only release the gate if probable
                    gateStates[input] = rising
                end
            end
        end
    end,

    step = function(self, dt, inputs)
        return {
            gateStates[1] and 10 or 0, gateStates[2] and 10 or 0,
            gateStates[3] and 10 or 0, gateStates[4] and 10 or 0
        }
    end,

    draw = function(self)
        -- Draw four states as text
        drawText(10, 20, "Gate 1: " .. (gateStates[1] and "HIGH" or "LOW"))
        drawText(10, 30, "Gate 2: " .. (gateStates[2] and "HIGH" or "LOW"))
        drawText(10, 40, "Gate 3: " .. (gateStates[3] and "HIGH" or "LOW"))
        drawText(10, 50, "Gate 4: " .. (gateStates[4] and "HIGH" or "LOW"))
    end
}
