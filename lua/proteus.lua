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
local gateDuration = 200
local nextGateDuration = 200
local gateActive = false
local gateReleaseTime = 0 -- Seconds remaining until gate release
local newSequenceGenerated = false
local baseOctave = 0
local sequenceCount = 0 -- Track the number of sequences generated
local output = {}

local scales = {
    {0, 2, 4, 5, 7, 9, 11}, -- Major
    {0, 2, 3, 5, 7, 8, 10}, -- Minor
    {0, 1, 3, 5, 7, 8, 10}, -- Phrygian
    {0, 2, 4, 7, 9}, -- Major Pentatonic
    {0, 3, 5, 7, 10}, -- Minor Pentatonic
    {0, 1, 5, 7, 8}, -- Miyako Bushi
    {0, 2, 4, 6, 11} -- Prometheus
}
local scaleNames = {
    "Major", "Minor", "Phrygian", "Maj Penta", "Min Penta", "Miyako Bushi",
    "Prometheus"
}
local scaleIndex = 1 -- Default to Major scale
local scale = scales[scaleIndex]
local rootNote = 0 -- C
local rootNoteNames = {
    "C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"
}
local showNewSequenceIndicator = false

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
            -- Use nil to indicate no pitch for rests
            sequence[i] = {pitch = nil, gate = false}
        else
            sequence[i] = {pitch = generateNote(), gate = true}
        end
    end
    sequenceCount = sequenceCount + 1
    showNewSequenceIndicator = not showNewSequenceIndicator
end

generateSequence()

return {
    name = "Proteus Generative Sequencer",
    author = "Originally by Blue Nautilus, ported and mangled by Thorinside",

    init = function(self)
        return {
            inputs = {kGate, kTrigger},
            outputs = 2,
            inputNames = {"Clock Input", "Trigger Input"},
            outputNames = {"V/OCT Output", "Gate Output"},
            parameters = {
                {"Sequence Length", 1, 32, sequenceLength, kInt},
                {"Rest Probability", 0, 100, restProbability, kPercent},
                {"Sequence Probability", 0, 100, sequenceProbability, kPercent},
                {"Gate Duration", 20, 2000, gateDuration, kMs},
                {"Base Octave", -2, 5, baseOctave, kInt},
                {"Scale", scaleNames, scaleIndex, kEnum},
                {"Root Note", rootNoteNames, 0, kEnum},
                {"Generate New", 0, 1, 0, kBool}
            }
        }
    end,

    gate = function(self, input, rising)
        if input == 1 and rising then
            currentStep = currentStep + 1
            if currentStep > sequenceLength then
                currentStep = 1
                if math.random(100) <= sequenceProbability then
                    generateSequence()
                end
            end

            local stepData = sequence[currentStep]
            if stepData.gate then
                -- If this is a note, activate gate and set release timer
                gateActive = true
                gateDuration = nextGateDuration
                -- Set gate release time to the current gate duration in seconds
                gateReleaseTime = gateDuration / 1000
            end
        end
    end,

    trigger = function(self, input) if input == 2 then currentStep = 1 end end,

    step = function(self, dt, inputs)
        sequenceLength = self.parameters[1]
        restProbability = self.parameters[2]
        sequenceProbability = self.parameters[3]
        nextGateDuration = self.parameters[4]
        baseOctave = self.parameters[5]
        scaleIndex = self.parameters[6]
        rootNote = self.parameters[7] - 1
        scale = scales[scaleIndex]

        if self.parameters[8] == 1 then generateSequence() end

        if gateDuration <= 0 then gateDuration = nextGateDuration end

        -- Count down the gate release timer
        if gateActive and gateReleaseTime > 0 then
            gateReleaseTime = gateReleaseTime - dt

            -- Check if gate should be released
            if gateReleaseTime <= 0 then gateActive = false end
        end

        output[1] = sequence[currentStep].pitch
        output[2] = gateActive and 5 or 0

        return output
    end,

    ui = function(self) return true end,

    setupUi = function(self)
        return {
            ((self and self.parameters and self.parameters[2]) or
                restProbability) / 100.0,
            ((self and self.parameters and self.parameters[3]) or
                sequenceProbability) / 100.0,
            ((self and self.parameters and self.parameters[4]) or gateDuration) /
                2000.0
        }
    end,

    encoder1Turn = function(self, value)
        algorithm = getCurrentAlgorithm()
        setParameter(algorithm, self.parameterOffset + 6,
                     self.parameters[6] + value)
    end,

    encoder2Turn = function(self, value)
        algorithm = getCurrentAlgorithm()
        setParameter(algorithm, self.parameterOffset + 7,
                     self.parameters[7] + value)
    end,

    pot1Turn = function(self, value)
        algorithm = getCurrentAlgorithm()
        setParameter(algorithm, self.parameterOffset + 2, value * 100.0)
    end,

    pot2Turn = function(self, value)
        algorithm = getCurrentAlgorithm()
        setParameter(algorithm, self.parameterOffset + 3, value * 100.0)
    end,

    pot2Push = function(self, value) exit() end,

    pot3Turn = function(self, value)
        algorithm = getCurrentAlgorithm()
        setParameter(algorithm, self.parameterOffset + 4, value * 2000.0)
    end,

    encoder2Push = function(self, value) generateSequence() end,

    draw = function(self)
        local margin = 4

        local titleX = margin
        local titleY = 10
        local seqInfoX = margin
        local seqInfoY = 25
        local stepInfoX = 150
        local stepInfoY = 25

        drawTinyText(titleX, titleY, "Proteus Generative Sequencer")

        local scaleText = rootNoteNames[(rootNote % 12) + 1] .. " " ..
                              scaleNames[scaleIndex]
        drawText(seqInfoX, seqInfoY, scaleText)

        local gridX = margin
        local gridY = 35
        local cellWidth = 12
        local cellHeight = 12
        local spacing = 2
        local cellsPerRow = 8

        for i = 1, sequenceLength do
            local stepData = sequence[i]
            local row = math.floor((i - 1) / cellsPerRow)
            local col = (i - 1) % cellsPerRow

            local x = gridX + col * (cellWidth + spacing)
            local y = gridY + row * (cellHeight + spacing)

            local brightness = 1
            if stepData.gate then brightness = 8 end
            if i == currentStep then brightness = 15 end

            drawRectangle(x, y, x + cellWidth, y + cellHeight, brightness)

            -- Only draw pitch line for non-nil pitch values
            if stepData.pitch ~= nil then
                local pitchValue = (stepData.pitch * 12) % 12
                local pitchHeight = math.floor((cellHeight - 4) *
                                                   (pitchValue / 12))
                drawLine(x + 2, y + pitchHeight + 2, x + cellWidth - 2,
                         y + pitchHeight + 2, 0)
            end
        end

        local paramsX = 150
        local paramsY = 26
        local lineHeight = 8

        drawTinyText(paramsX, paramsY,
                     "Step: " .. currentStep .. "/" .. sequenceLength)
        drawTinyText(paramsX, paramsY + lineHeight,
                     "Rest: " .. restProbability .. "%")
        drawTinyText(paramsX, paramsY + lineHeight * 2,
                     "Seq Prob: " .. sequenceProbability .. "%")
        drawTinyText(paramsX, paramsY + lineHeight * 3,
                     "Gate: " .. gateDuration .. "ms")
        drawTinyText(paramsX, paramsY + lineHeight * 4, "Octave: " .. baseOctave)

        drawTinyText(paramsX, paramsY + lineHeight * 6,
                     "Sequences: " .. sequenceCount)
        if showNewSequenceIndicator then
            drawText(paramsX + 75, paramsY + lineHeight * 6, "*")
        end

        return true
    end
}
