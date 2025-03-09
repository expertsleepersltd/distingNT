-- AE Sequencer
-- A simple generative sequencer with independent voltage and gate sequences.
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
local NUM_SEQUENCES = 20
local MAX_STEPS = 32

local OUTPUT_BUFFER = {0, 0} -- Preallocated output buffer for step()
local lastActiveVoltIndex = 1 -- Tracks last active voltage sequence index

-- Tables to hold 20 voltage sequences and 20 gate sequences.
local voltageSequences = {}
local gateSequences = {}

-- Generate a random 16-bit raw value in the range [-32768, 32767]
local function generateRandomRawValue() return math.random(-32768, 32767) end

-- Randomize a voltage sequence by filling its steps with raw values.
local function randomizeVoltageSequence(seq)
    for i = 1, seq.stepCount do seq.steps[i] = generateRandomRawValue() end
end

-- Randomize a gate sequence.
local function randomizeGateSequence(seq)
    for i = 1, MAX_STEPS do seq.steps[i] = math.random(100) end
end

-- Compute the effective voltage range based on polarity.
-- Polarity: 1 = Positive, 2 = Bipolar, 3 = Negative.
local function getEffectiveRange(minV, maxV, polarity)
    if polarity == 1 then
        return 0, maxV
    elseif polarity == 3 then
        return minV, 0
    else
        return minV, maxV
    end
end

-- Quantize a voltage value to the specified resolution.
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

-- Update the cached voltage for the current step by mapping the raw value.
local function updateVoltageCached(seq, resolution, minV, maxV, polarity)
    local raw = seq.steps[seq.currentStep]
    local effectiveMin, effectiveMax = getEffectiveRange(minV, maxV, polarity)
    local fraction
    if polarity == 2 then
        fraction = (raw + 32768) / 65535
    elseif polarity == 1 then
        local clamped = raw < 0 and 0 or raw
        fraction = clamped / 32767
    elseif polarity == 3 then
        local clamped = raw > 0 and 0 or raw
        fraction = (clamped + 32768) / 32768
    end
    local value = fraction * (effectiveMax - effectiveMin) + effectiveMin
    seq.cachedVoltage = quantizeVoltage(value, resolution, effectiveMin,
                                        effectiveMax)
end

-- Initialize the 20 sequences if not already done.
local function initSequences()
    if #voltageSequences < NUM_SEQUENCES then
        for i = 1, NUM_SEQUENCES do
            voltageSequences[i] = {
                currentStep = 1,
                stepCount = 8,
                cachedVoltage = 0,
                steps = {}
            }
            for j = 1, MAX_STEPS do
                voltageSequences[i].steps[j] = generateRandomRawValue()
            end
            updateVoltageCached(voltageSequences[i], 16, -1, 1, 2)

            gateSequences[i] = {
                stepIndex = 1,
                numSteps = 16,
                gateRemainingSteps = 0,
                steps = {}
            }
            for j = 1, MAX_STEPS do
                gateSequences[i].steps[j] = math.random(100)
            end
        end
    end
end

-- Global randomize function to randomize all sequences.
local function globalRandomize(self)
    for i = 1, NUM_SEQUENCES do
        randomizeVoltageSequence(voltageSequences[i])
        updateVoltageCached(voltageSequences[i], self.parameters[7],
                            self.parameters[4], self.parameters[5],
                            self.parameters[6])
        randomizeGateSequence(gateSequences[i])
    end
end

return {
    name = "AE Sequencer",
    author = "Andras Eichstaedt / Thorinside / 4o",

    init = function(self)
        initSequences()
        return {
            -- Three inputs:
            -- 1 = clock (stepping), 2 = reset trigger, 3 = global randomize trigger
            inputs = {kGate, kTrigger, kTrigger},
            outputs = {kStepped, kGate},
            inputNames = {"Clock", "Reset", "Randomize"},
            outputNames = {"CV Output", "Gate Output"},
            parameters = {
                {"CV Sequence", 1, NUM_SEQUENCES, 1, kInt},
                {"Gate Sequence", 1, NUM_SEQUENCES, 1, kInt},
                {"CV Steps", 1, MAX_STEPS, 8, kInt},
                {"Min CV", -10, 10, -1, kVolts}, {"Max CV", -10, 10, 1, kVolts},
                {"Polarity", {"Positive", "Bipolar", "Negative"}, 2, kEnum},
                {"Bit Depth (CV)", 2, 16, 16, kInt},
                {"Gate Steps", 1, MAX_STEPS, 16, kInt},
                {"Threshold", 1, 100, 50, kPercent},
                {"Gate Length", 5, 1000, 100, kMs}
            }
        }
    end,

    gate = function(self, input, rising)
        local voltIdx = self.parameters[1]
        local gateIdx = self.parameters[2]
        if input == 1 and rising then
            -- Advance voltage sequence.
            local voltSeq = voltageSequences[voltIdx]
            voltSeq.stepCount = self.parameters[3]
            voltSeq.currentStep = voltSeq.currentStep + 1
            if voltSeq.currentStep > voltSeq.stepCount then
                voltSeq.currentStep = 1
            end
            updateVoltageCached(voltSeq, self.parameters[7], self.parameters[4],
                                self.parameters[5], self.parameters[6])

            -- Advance gate sequence.
            local gateSeq = gateSequences[gateIdx]
            gateSeq.numSteps = self.parameters[8]
            gateSeq.stepIndex = gateSeq.stepIndex + 1
            if gateSeq.stepIndex > gateSeq.numSteps then
                gateSeq.stepIndex = 1
            end
            if gateSeq.steps[gateSeq.stepIndex] >= self.parameters[9] then
                gateSeq.gateRemainingSteps = self.parameters[10]
            end
        end
    end,

    trigger = function(self, input)
        local voltIdx = self.parameters[1]
        local gateIdx = self.parameters[2]
        if input == 2 then
            -- Reset active voltage sequence.
            voltageSequences[voltIdx].currentStep = 1
            updateVoltageCached(voltageSequences[voltIdx], self.parameters[7],
                                self.parameters[4], self.parameters[5],
                                self.parameters[6])
            -- Reset active gate sequence.
            gateSequences[gateIdx].stepIndex = 1
        elseif input == 3 then
            -- Global randomize all sequences.
            globalRandomize(self)
        end
    end,

    step = function(self, dt, inputs)
        local voltIdx = self.parameters[1]
        local gateIdx = self.parameters[2]
        if voltIdx ~= lastActiveVoltIndex then
            lastActiveVoltIndex = voltIdx
            updateVoltageCached(voltageSequences[voltIdx], self.parameters[7],
                                self.parameters[4], self.parameters[5],
                                self.parameters[6])
        end
        OUTPUT_BUFFER[1] = voltageSequences[voltIdx].cachedVoltage
        local gateSeq = gateSequences[gateIdx]
        if gateSeq.gateRemainingSteps > 0 then
            gateSeq.gateRemainingSteps = gateSeq.gateRemainingSteps - 1
            OUTPUT_BUFFER[2] = 5
        else
            OUTPUT_BUFFER[2] = 0
        end
        return OUTPUT_BUFFER
    end,

    ui = function(self) return true end,

    encoder2Push = function(self) globalRandomize(self) end,

    pot2Turn = function(self, x)
        local alg = getCurrentAlgorithm()
        local p = self.parameterOffset + 1 + x * 10.5
        focusParameter(alg, p)
    end,

    pot3Turn = function(self, x) standardPot3Turn(x) end,

    draw = function(self)
        local voltIdx = self.parameters[1]
        local gateIdx = self.parameters[2]
        -- Leave top 20px unused (for header)

        -- Draw gate sequence blocks starting at y = 25.
        local gateSeq = gateSequences[gateIdx]
        local numGate = self.parameters[8]
        local gateBlockWidth = math.floor(256 / numGate)
        local gateBlockHeight = 10
        local gateY = 25
        for i = 1, numGate do
            local x = (i - 1) * gateBlockWidth
            -- If this is the active gate step, draw a white border first.
            if i == gateSeq.stepIndex then
                drawRectangle(x - 1, gateY - 1, x + gateBlockWidth - 1,
                              gateY + gateBlockHeight + 1, 15)
            end
            -- Draw the block.
            if gateSeq.steps[i] >= self.parameters[9] then
                drawRectangle(x, gateY, x + gateBlockWidth - 2,
                              gateY + gateBlockHeight, 15)
            else
                drawRectangle(x, gateY, x + gateBlockWidth - 2,
                              gateY + gateBlockHeight, 3)
            end
        end

        -- Draw voltage sequence blocks starting at y = 40.
        local voltSeq = voltageSequences[voltIdx]
        local numVolt = self.parameters[3]
        local voltBlockWidth = math.floor(256 / numVolt)
        local voltBlockHeight = 10
        local voltY = 40
        local effectiveMin, effectiveMax =
            getEffectiveRange(self.parameters[4], self.parameters[5],
                              self.parameters[6])
        for i = 1, numVolt do
            local x = (i - 1) * voltBlockWidth
            local raw = voltSeq.steps[i]
            local voltage
            if self.parameters[6] == 2 then
                voltage =
                    (raw + 32768) / 65535 * (effectiveMax - effectiveMin) +
                        effectiveMin
            elseif self.parameters[6] == 1 then
                voltage = (raw < 0 and 0 or raw) / 32767 *
                              (effectiveMax - effectiveMin) + effectiveMin
            elseif self.parameters[6] == 3 then
                voltage = ((raw > 0 and 0 or raw) + 32768) / 32768 *
                              (effectiveMax - effectiveMin) + effectiveMin
            end
            local norm = (voltage - effectiveMin) /
                             (effectiveMax - effectiveMin)
            if norm < 0 then norm = 0 end
            if norm > 1 then norm = 1 end
            local colorIndex = math.floor(norm * 14) + 1
            if i == voltSeq.currentStep then
                drawRectangle(x - 1, voltY - 1, x + voltBlockWidth - 1,
                              voltY + voltBlockHeight + 1, 15)
            end
            drawRectangle(x, voltY, x + voltBlockWidth - 2,
                          voltY + voltBlockHeight, colorIndex)
        end
    end
}
