-- Proteus Generative Sequencer
--[[
    I've always loved @abluenautilus and his Proteus sequencer for VCV Rack. This is a port of some of the C++ code to LUA. It
    carries the same license as the original code.

    Clock -> Input 1
    Pitch -> Output 1
    Gate -> Output 2    
]] --[[
MIT License

Copyright (c) 2022 Seaside Modular

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]] --
local sequence = {}
local maxSteps = 32
local sequenceLength = 16
local restProbability = 20 -- percentage
local sequenceProbability = 50 -- Percentage of generating a new sequence
local currentStep = 1
local gateDuration = 200 -- Default to 200ms
local nextGateDuration = 200 -- Default to 200ms
local timeSinceGate = 0
local gateActive = false
local clockPrevState = 0
local newSequenceGenerated = false
local baseOctave = 0
local sequenceCount = 0 -- Track the number of sequences generated

local scales = {
    {0, 2, 4, 5, 7, 9, 11}, -- Major
    {0, 2, 3, 5, 7, 8, 10}, -- Minor
    {0, 1, 3, 5, 7, 8, 10}, -- Phrygian
    {0, 2, 4, 7, 9}, -- Major Pentatonic
    {0, 3, 5, 7, 10}, -- Minor Pentatonic
    {0, 1, 5, 7, 8}, -- Miyako Bushi
    {0, 2, 4, 6, 11} -- Prometheus
}
local scaleIndex = 1 -- Default to Major scale
local scale = scales[scaleIndex] -- Current scale
local rootNote = 0 -- C
local showNewSequenceIndicator = false -- Toggle for sequence indicator

-- Utility functions
local function generateNote()
    local scaleDegree = math.random(1, #scale)
    local octave = baseOctave + math.random(-1, 1)
    local note = rootNote + scale[scaleDegree] + octave * 12
    return note / 12 -- Convert MIDI note to volts (volt-per-octave)
end

local function generateSequence()
    for i = 1, maxSteps do
        local isRest = math.random(100) <= restProbability
        if isRest then
            sequence[i] = {pitch = 0, gate = false}
        else
            sequence[i] = {pitch = generateNote(), gate = true}
        end
    end
    sequenceCount = sequenceCount + 1
    showNewSequenceIndicator = not showNewSequenceIndicator -- Toggle the indicator
end

-- Generate initial sequence
generateSequence()

return {
    name = "Proteus Generative Sequencer",
    author = "Originally by Blue Nautilus, ported and mangled by Thorinside",

    init = function(self)
        return {
            inputs = 1, -- Add clock input
            outputs = 2,
            parameters = {
                {"Sequence Length", 1, 32, sequenceLength, kInt},
                {"Rest Probability", 0, 100, restProbability, kPercent},
                {"Sequence Probability", 0, 100, sequenceProbability, kPercent},
                {"Gate Duration", 100, 2000, gateDuration, kMilliseconds},
                {"Base Octave", -2, 5, baseOctave, kInt},
                {"Scale", 1, 7, scaleIndex, kInt}
            }
        }
    end,

    step = function(self, dt, inputs)
        local clockInput = inputs[1] > 2.5 and 1 or 0 -- High signal threshold

        -- Update parameters dynamically
        sequenceLength = math.floor(self.parameters[1])
        restProbability = math.floor(self.parameters[2])
        sequenceProbability = math.floor(self.parameters[3])
        nextGateDuration = math.floor(self.parameters[4])
        baseOctave = math.floor(self.parameters[5])
        scaleIndex = math.floor(self.parameters[6])
        scale = scales[scaleIndex] -- Update scale dynamically

        -- Ensure gateDuration is correctly initialized
        if gateDuration <= 0 then gateDuration = nextGateDuration end

        -- Detect clock rising edge
        if clockInput == 1 and clockPrevState == 0 then
            currentStep = currentStep + 1
            if currentStep > sequenceLength then
                currentStep = 1
                if math.random(100) <= sequenceProbability then
                    generateSequence() -- Optionally regenerate the sequence
                end
            end

            local stepData = sequence[currentStep]
            if stepData.gate then
                gateActive = true
                timeSinceGate = 0
                gateDuration = nextGateDuration -- Update gate duration
            else
                gateActive = false
            end
        end

        clockPrevState = clockInput

        -- Update gate duration timing
        if gateActive then
            timeSinceGate = timeSinceGate + dt
            if timeSinceGate >= gateDuration / 1000 then
                gateActive = false
            end
        end

        -- Outputs
        local pitchOut = sequence[currentStep].pitch
        local gateOut = gateActive and 5 or 0 -- 5V for gate high, 0V for gate low

        return {pitchOut, gateOut}
    end,

    draw = function(self)
        -- Improved representation of the sequence
        local xStart = 0
        local yStart = 50 -- Adjusted to free up space for sequence squares
        local stepWidth = 6
        local stepHeight = 12
        local spacing = 2

        -- Display sequence indicator and count
        if showNewSequenceIndicator then
            drawText(0, yStart - 15, "*") -- Draw asterisk above the sequence
        end
        drawText(0, yStart - 30, "Seq: " .. sequenceCount) -- Display sequence count

        for i = 1, sequenceLength do
            local stepData = sequence[i]
            local x = xStart + (i - 1) * (stepWidth + spacing)
            local y = yStart

            if stepData.gate then
                drawRectangle(x, y, x + stepWidth, y + stepHeight, 1)
            else
                drawRectangle(x, y, x + stepWidth, y + stepHeight, 0)
            end

            if i == currentStep then
                drawRectangle(x - 1, y - 1, x + stepWidth + 1,
                              y + stepHeight + 1, 2)
            end
        end
    end
}
