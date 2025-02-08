-- AE Random Stepped Voltage
-- Generates a single stepped random voltage sequence.

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

For more information, please refer to <https://unlicense.org>
]] -- 

local MAX_STEPS = 32

local sequence = {
    steps = {},
    stepCount = 8,
    minVoltage = 0,
    maxVoltage = 5,
    polarity = 1, -- 1 = Positive, 2 = Bipolar, 3 = Negative
    currentStep = 1,
    randomize = 0,
    freeze = 0,
    valueResolution = 16,
    cachedVoltage = 0,
    output = {0}  -- pre-allocated output table for the step function
}

-- Preallocate the steps table up to MAX_STEPS.
for i = 1, MAX_STEPS do
    sequence.steps[i] = 0
end

local polarityNames = {"Positive", "Bipolar", "Negative"}

-- Computes the effective output range based on the polarity setting.
local function getEffectiveRange()
    local effectiveMin, effectiveMax
    if sequence.polarity == 1 then
        effectiveMin = sequence.minVoltage
        effectiveMax = sequence.maxVoltage
    elseif sequence.polarity == 2 then
        effectiveMin = sequence.minVoltage - (sequence.maxVoltage - sequence.minVoltage) / 2
        effectiveMax = sequence.maxVoltage - (sequence.maxVoltage - sequence.minVoltage) / 2
    elseif sequence.polarity == 3 then
        effectiveMin = -sequence.maxVoltage
        effectiveMax = -sequence.minVoltage
    end
    return effectiveMin, effectiveMax
end

-- Quantizes a voltage value to the specified bit resolution within a defined range.
local function quantizeVoltage(value, resolutionBits, effectiveMin, effectiveMax)
    local levels = (2 ^ resolutionBits) - 1
    local rangeEffective = effectiveMax - effectiveMin
    local stepSize = rangeEffective / levels
    local index = math.floor((value - effectiveMin) / stepSize + 0.5)
    local quantizedValue = index * stepSize + effectiveMin
    if quantizedValue < effectiveMin then quantizedValue = effectiveMin end
    if quantizedValue > effectiveMax then quantizedValue = effectiveMax end
    return quantizedValue
end

-- Updates the cached quantized voltage for the current step.
local function updateCachedVoltage(self)
    local rawValue = sequence.steps[sequence.currentStep]
    if rawValue then
        local resolutionBits = math.max(1, self.parameters[5])
        local effectiveMin, effectiveMax = getEffectiveRange()
        sequence.cachedVoltage = quantizeVoltage(rawValue, resolutionBits, effectiveMin, effectiveMax)
    end
end

-- Generates a random voltage value using full 16-bit resolution.
local function generateRandomValue()
    local range = sequence.maxVoltage - sequence.minVoltage
    local full16bit = 65535
    local randomInt = math.random(0, full16bit)
    local value = randomInt / full16bit * range + sequence.minVoltage
    if sequence.polarity == 2 then
        value = value - (range / 2)
    elseif sequence.polarity == 3 then
        value = -value
    end
    return value
end

-- Randomizes all steps in the voltage sequence.
local function randomizeSequence()
    for i = 1, sequence.stepCount do
        sequence.steps[i] = generateRandomValue()
    end
end

-- Initialize the sequence with random voltage values.
randomizeSequence()
do
    local effectiveMin, effectiveMax = getEffectiveRange()
    sequence.cachedVoltage = quantizeVoltage(sequence.steps[sequence.currentStep], sequence.valueResolution, effectiveMin, effectiveMax)
end

return {
    name = "AE Random Stepped Voltage",
    author = "Andras Eichstaedt / Thorinside / 4o",

    init = function(self)
        return {
            inputs = {kGate, kTrigger},
            outputs = {kStepped},
            encoders = {1, 2},
            parameters = {
                {"Number of Steps", 1, MAX_STEPS, 8, kInt},
                {"Min Voltage", -100, 100, -100, kVolts, kBy10},
                {"Max Voltage", -100, 100, 200, kVolts, kBy10},
                {"Polarity", polarityNames, 1},
                {"Value Resolution (bits)", 2, 16, 16, kInt},
                {"Freeze", {"Off", "On"}, 1, kEnum},
                {"Randomize", {"Off", "On"}, 1, kEnum},
            }
        }
    end,

    gate = function(self, input, rising)
        -- Update parameters.
        sequence.stepCount  = self.parameters[1]
        sequence.minVoltage = self.parameters[2]
        sequence.maxVoltage = self.parameters[3]
        sequence.polarity   = self.parameters[4]

        -- Advance the sequence on clock input when freeze is off.
        if input == 1 and rising and self.parameters[6] == 1 then
            sequence.currentStep = sequence.currentStep + 1
            if sequence.currentStep > sequence.stepCount then
                sequence.currentStep = 1
                if self.parameters[7] == 2 then
                    randomizeSequence()
                end
            end
            if sequence.steps[sequence.currentStep] == nil then
                sequence.steps[sequence.currentStep] = generateRandomValue()
            end
            updateCachedVoltage(self)
        end
    end,

    trigger = function(self, input)
        if input == 2 then
            sequence.currentStep = 1
            updateCachedVoltage(self)
        end
    end,

    ui = function(self) return true end,

    -- The step function simply returns the cached voltage value, using a preallocated output table.
    step = function(self, dt, inputs)
        sequence.output[1] = sequence.cachedVoltage
        return sequence.output
    end,

    encoder2Push = function(self)
        randomizeSequence()
        updateCachedVoltage(self)
    end,

    pot2Turn = function(self, x)
        local alg = getCurrentAlgorithm()
        local p = self.parameterOffset + 1 + x * 7.5
        focusParameter(alg, p)
    end,

    pot3Turn = function(self, x)
        standardPot3Turn(x)
    end,

    -- Displays the current step, cached voltage, polarity, resolution, and other settings.
    draw = function(self)
        drawText(10, 20, "Step: " .. sequence.currentStep ..
                    " -> " .. string.format("%.2fV", sequence.cachedVoltage))
        drawText(10, 30, "Freeze: " .. (self.parameters[6] == 2 and "ON" or "OFF"))
        drawText(10, 40, "Randomize: " .. (self.parameters[7] == 2 and "ON" or "OFF"))
        drawText(10, 50, "Polarity: " .. polarityNames[self.parameters[4]])
        drawText(10, 60, "Resolution: " .. self.parameters[5] .. " bits")
    end
}
