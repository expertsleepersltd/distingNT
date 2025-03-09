-- Clep Disting
-- A step-based CV generator with selectable random, step, and LFO modes.
--[[
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
]] -- Define integer constants for modes and directions
local MODE_STEP = 1
local MODE_RANDOM = 2
local MODE_LFO = 3

local DIR_UP = 1
local DIR_DOWN = 2
local DIR_UPDOWN = 3

local OUTPUT_BIPOLAR = 1
local OUTPUT_UNIPOLAR = 2

local kModes = {"Step", "Random", "LFO"}
local kOutputType = {"Bipolar", "Unipolar"}
local stepCount = 8
local direction = DIR_UP
local mode = MODE_STEP
local outputType = OUTPUT_BIPOLAR
local cvValues = {}
local currentStep = 1
local lfoPhase = 0
local stepSize = 1
local outputValue = 0
local outputTable = {0, 0} -- Pre-allocated table (Main CV, Trigger output)
local directionState = 1 -- 1 for up, -1 for down (used for DIR_UPDOWN mode)

-- Initialize a 32-step CV sequence
local function randomizeCV()
    for i = 1, 32 do
        cvValues[i] = math.random() * 10.0 -- Random CV values between 0.0 and 10.0V
    end
end

local function processStep()
    if direction == DIR_UP then
        currentStep = (currentStep % stepCount) + 1
    elseif direction == DIR_DOWN then
        currentStep = (currentStep - 2) % stepCount + 1
        if currentStep == 0 then currentStep = stepCount end
    elseif direction == DIR_UPDOWN then
        currentStep = currentStep + directionState
        if currentStep >= stepCount then
            directionState = -1 -- Change direction to down
        elseif currentStep <= 1 then
            directionState = 1 -- Change direction to up
        end
    end

    if mode == MODE_STEP then
        outputValue = cvValues[currentStep]
    elseif mode == MODE_RANDOM then
        outputValue = math.random() * 10.0
    elseif mode == MODE_LFO then
        stepSize = math.pi * 2 / stepCount
        lfoPhase = (lfoPhase + stepSize) % (math.pi * 2)
        if outputType == OUTPUT_BIPOLAR then
            -- Direct bipolar sine: -5V to +5V.
            outputValue = math.sin(lfoPhase) * 5
        else
            -- Unipolar sine: 0V to 5V.
            outputValue = (math.sin(lfoPhase) + 1) * 2.5
        end
    end

    if mode ~= MODE_LFO then
        -- For non-LFO modes, apply the conversion as before:
        if outputType == OUTPUT_BIPOLAR then
            outputTable[1] = outputValue - 5 -- Bipolar Output (-5V to +5V)
        else
            outputTable[1] = outputValue / 2 -- Unipolar Output (0V to 5V)
        end
    else
        -- For LFO mode, we already computed the proper voltage.
        outputTable[1] = outputValue
    end

    outputTable[2] = (currentStep == 1) and 10 or 0 -- Trigger output at step 1
end

return {
    name = "Clep Disting",
    author = "Thorinside | 4o",

    init = function(self)
        randomizeCV()
        return {
            inputs = {kGate, kTrigger},
            outputs = {kLinear, kTrigger},
            inputNames = {"Clock", "Reset"},
            outputNames = {"CV Output", "BOC Trigger Output"},
            parameters = {
                {"Mode", kModes, 1}, {"Steps", 1, 32, 8, kInteger},
                {"Direction", {"Up", "Down", "UpDown"}, 1},
                {"Randomize", {"Off", "On"}, 1}, {"Output Type", kOutputType, 1}
            }
        }
    end,

    gate = function(self, input, rising)
        if input == 1 and rising then -- Clock Input
            mode = self.parameters[1]
            stepCount = self.parameters[2]
            direction = self.parameters[3]
            outputType = self.parameters[5]

            if mode == MODE_STEP and currentStep == 1 and self.parameters[4] ==
                2 then randomizeCV() end
            processStep()
        end
    end,

    trigger = function(self, input)
        if input == 2 then -- Reset Input
            currentStep = 1
            directionState = 1 -- Reset to moving up for UPDOWN mode
            outputTable[2] = 1 -- Send trigger pulse
        end
    end,

    step = function(self, dt, inputs)
        return outputTable -- Return pre-allocated table with CV and Trigger output
    end,

    draw = function(self)
        -- Draw mode indicator
        drawText(10, 25, "Mode: " .. kModes[self.parameters[1]])
        drawText(10, 35, "Step: " .. currentStep)
        drawText(10, 45,
                 "Output: " .. string.format("%+0.2fV", outputTable[1]) ..
                     " Type: " .. kOutputType[self.parameters[5]] ..
                     " Trigger: " .. outputTable[2])

        -- Visual representation of steps
        local stepWidth = 256 / stepCount
        for i = 1, stepCount do
            local x = (i - 1) * stepWidth
            local color = (i == currentStep) and 15 or 2 -- Highlight current step
            drawRectangle(x, 54, x + stepWidth - 2, 64, color)
        end
    end
}
