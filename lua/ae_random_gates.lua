-- AE Random Gates
-- Generates a random gate sequence with thresholding
local sequence = {
    steps = {},
    numSteps = 16,
    threshold = 50,
    gateLength = 50,
    stepIndex = 1,
    gateRemainingSteps = 0,  -- used as the sole timer/flag for gate activity
}

-- Preallocate the output buffer so that we never create a new table in step
local OUTPUT_BUFFER = { 0 }

-- Preallocate the steps table with 32 entries
for i = 1, 32 do
    sequence.steps[i] = 0
end

local function randomizeSequence()
    for i = 1, 32 do
        sequence.steps[i] = math.random(100)
    end
end

-- Initialize the sequence
randomizeSequence()

return {
    name = "AE Random Gates",
    author = "Andras Eichstaedt with code by Thorinside and 4o",

    init = function(self)
        return {
            inputs = { kGate, kTrigger },
            outputs = { kGate },
            parameters = {
                {"Number of Steps", 1, 32, 16, kInt},
                {"Threshold", 1, 100, 50, kPercent},
                {"Gate Length", 5, 1000, 100, kMs},
                {"Freeze", {"Off", "On"}, 1, kEnum},
                {"Randomize", {"Off", "On"}, 1, kEnum},
            }
        }
    end,

    trigger = function(self, input)
        if input == 2 then -- kTrigger
            sequence.stepIndex = 1
        end
    end,

    gate = function(self, input, rising)
        -- Update parameters (so that step() stays allocation–free)
        sequence.numSteps  = self.parameters[1]
        sequence.threshold = self.parameters[2]
        sequence.gateLength = self.parameters[3]

        if input == 1 and rising and self.parameters[4] == 1 then
            sequence.stepIndex = sequence.stepIndex + 1
            if sequence.stepIndex > sequence.numSteps then
                sequence.stepIndex = 1
                if self.parameters[5] > 0 then
                    randomizeSequence()
                end
            end

            if sequence.steps[sequence.stepIndex] >= sequence.threshold then
                -- With step() running at 1000Hz (1ms per call),
                -- gateLength (in ms) is directly the number of steps.
                sequence.gateRemainingSteps = sequence.gateLength
            end
        end
    end,

    step = function(self, dt, inputs)
        -- Instead of checking a separate boolean flag,
        -- we use gateRemainingSteps as the indicator.
        if sequence.gateRemainingSteps > 0 then
            sequence.gateRemainingSteps = sequence.gateRemainingSteps - 1
            OUTPUT_BUFFER[1] = 5
        else
            OUTPUT_BUFFER[1] = 0
        end
        return OUTPUT_BUFFER
    end,

    ui = function(self) return true end,

    encoder2Push = function(self)
        randomizeSequence()
    end,

    pot2Turn = function(self, x)
        local alg = getCurrentAlgorithm()
        local p = self.parameterOffset + 1 + (x * 5.5)
        focusParameter(alg, p)
    end,

    pot3Turn = function(self, x)
        standardPot3Turn(x)
    end,

    draw = function(self)
        local yOffset = 20
        drawText(10, yOffset, "Step: " .. sequence.stepIndex .. "/" .. sequence.numSteps)
        drawText(10, yOffset + 10, "Threshold: " .. sequence.threshold)
        drawText(10, yOffset + 20, "Gate Length: " .. sequence.gateLength)
        drawText(10, yOffset + 30, "Freeze: " .. (self.parameters[4] == 2 and "ON" or "OFF"))
        drawText(10, yOffset + 40, "Gate State: " .. (sequence.gateRemainingSteps > 0 and "ON" or "OFF"))
    end,
}
