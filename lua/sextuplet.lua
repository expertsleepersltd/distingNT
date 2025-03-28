-- Sextuplet
--[[ 6-channel Sample and Hold

 Six channels of sample and hold.
 Each pair of inputs consists of a CV and a Gate.
 When a gate is triggered, the corresponding CV is sampled.

]] --[[
This is free and unencumbered software released into the public domain.
Anyone is free to copy, modify, publish, use, compile, sell, or distribute this
software, either in source code form or as a compiled binary, for any purpose,
commercial or non-commercial, and by any means.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]] local samples = {nil, nil, nil, nil, nil, nil}

return {
    name = "Sextuplet",
    author = "Claude, directed by Thorinside",
    description = "6-channel Sample and Hold",

    init = function(self)
        return {
            inputs = {
                kCV, kGate, -- Channel 1
                kCV, kGate, -- Channel 2
                kCV, kGate, -- Channel 3
                kCV, kGate, -- Channel 4
                kCV, kGate, -- Channel 5
                kCV, kGate -- Channel 6
            },
            outputs = 6, -- 6 Sample and Hold outputs
            inputNames = {
                "CV 1", "Gate 1", "CV 2", "Gate 2", "CV 3", "Gate 3", "CV 4",
                "Gate 4", "CV 5", "Gate 5", "CV 6", "Gate 6"
            },
            outputNames = {"Out 1", "Out 2", "Out 3", "Out 4", "Out 5", "Out 6"},
            parameters = {{"Scale", 0, 100, 100, kPercent}}
        }
    end,

    setupUi = function(self) return {nil, self.parameters[1] or 1, nil} end,

    gate = function(self, input, rising)
        -- Handle gates for inputs 2, 4, 6, 8, 10, 12
        if input % 2 == 0 then -- Even numbered inputs are gates
            if rising then
                local idx = input / 2 -- Convert to 1, 2, 3, 4, 5, or 6
                local cvInput = input - 1 -- Corresponding CV input

                -- Get current algorithm index
                local algIndex = getCurrentAlgorithm()

                -- Get the bus voltage for the CV input (zero-based index)
                local voltage = getBusVoltage(algIndex, cvInput - 1)

                -- Store the sampled value in the corresponding output
                samples[idx] = voltage
            end
        end
    end,

    step = function(self, dt, inputs)
        -- Get the scale parameter (0-100%)
        local scale = self.parameters[1] / 100.0

        -- Apply scaling to all outputs
        local outputs = {}
        for i = 1, 6 do
            if samples[i] ~= nil then
                outputs[i] = samples[i] * scale
            else
                outputs[i] = 0
            end
        end

        -- Return the scaled outputs
        return outputs
    end,

    ui = function(self) return true end,

    pot2Turn = function(self, x)
        local alg = getCurrentAlgorithm()
        setParameterNormalized(alg, self.parameterOffset + 1, x)
    end,

    draw = function(self)
        drawTinyText(10, 10, "Sextuplet - 6-Channel S&H")

        -- Draw scale value
        drawTinyText(160, 10, string.format("Scale: %d%%", self.parameters[1]))

        -- Define the visualization area
        local maxVoltage = 10 -- Maximum expected magnitude of CV voltage
        local zeroY = 35 -- Y-coordinate for zero voltage 
        local scale = 20 / maxVoltage -- Scale factor for visualization
        local blockWidth = 30 -- Width of each block
        local blockSpacing = 5 -- Space between blocks

        -- Get the attenuation scale factor
        local attenScale = self.parameters[1] / 100.0

        -- Draw sample values
        for i = 1, 6 do
            local rawVoltage = samples[i] or 0
            local voltage = rawVoltage * attenScale -- Apply attenuation for display

            local x1 = 10 + (i - 1) * (blockWidth + blockSpacing)
            local x2 = x1 + blockWidth

            -- Calculate block dimensions based on voltage
            local blockHeight = math.abs(math.floor(voltage * scale))
            local y1, y2

            if voltage >= 0 then
                y1 = zeroY - blockHeight
                y2 = zeroY
            else
                y1 = zeroY
                y2 = zeroY + blockHeight
            end

            -- Draw zero line indicator
            drawRectangle(x1, zeroY - 1, x2, zeroY + 1, 2)

            -- Draw the voltage level block 
            local brightness
            if samples[i] == nil then
                -- Dimmer if no sample has been taken yet
                brightness = 5
            else
                brightness = math.floor((math.abs(voltage) / maxVoltage) * 15)
            end

            drawRectangle(x1, y1, x2, y2, brightness)

            -- Format the voltage text
            local voltageText = string.format("%.1fV", voltage)

            -- Calculate the text width and center position
            local charWidth = 5 -- Assuming each character is 5 pixels wide
            local textWidth = string.len(voltageText) * charWidth
            local centerX = x1 + (blockWidth / 2)
            local textX = centerX - (textWidth / 2) + 2 -- Added 2 pixels to shift right

            -- Show voltage value (centered in the block and shifted 2px right)
            drawTinyText(textX, y2 + 9, voltageText)
        end

        return true -- Take over the screen
    end
}
