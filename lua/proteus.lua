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
local scaleNames = {
    "Major", "Minor", "Phrygian", "Maj Penta", "Min Penta", "Miyako Bushi", "Prometheus"
}
local scaleIndex = 1 -- Default to Major scale
local scale = scales[scaleIndex] -- Current scale
local rootNote = 0 -- C
local rootNoteNames = {"C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"}
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
            inputNames = {"Clock"},
            outputNames = {"V/OCT Output", "Gate Output"},
            parameters = {
                {"Sequence Length", 1, 32, sequenceLength, kInt},
                {"Rest Probability", 0, 100, restProbability, kPercent},
                {"Sequence Probability", 0, 100, sequenceProbability, kPercent},
                {"Gate Duration", 100, 2000, gateDuration, kMs},
                {"Base Octave", -2, 5, baseOctave, kInt}, 
                {"Scale", scaleNames, scaleIndex, kEnum},
                {"Root Note", rootNoteNames, 1, kEnum},
                {"Generate New", 0, 1, 0, kBool}
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
        rootNote = math.floor(self.parameters[7])
        scale = scales[scaleIndex] -- Update scale dynamically

        -- Check if we should generate a new sequence based on parameter
        if self.parameters[8] == 1 then
            generateSequence()
        end

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

    ui = function(self) return true end,

    setupUi = function(self)
        return {
            ((self and self.parameters and self.parameters[2]) or restProbability) / 100.0,
            ((self and self.parameters and self.parameters[3]) or sequenceProbability) / 100.0,
            ((self and self.parameters and self.parameters[4]) or gateDuration) / 2000.0
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

    encoder1Push = function(self, value) 
        -- Toggle the scale type
        algorithm = getCurrentAlgorithm()
        scaleIndex = scaleIndex % #scales + 1
        setParameter(algorithm, self.parameterOffset + 6, scaleIndex)
    end,

    encoder2Push = function(self, value)
        generateSequence()
    end,

    draw = function(self)
        -- Set margin
        local margin = 4
        
        -- Title and sequence info
        local titleX = margin
        local titleY = 10
        local seqInfoX = margin
        local seqInfoY = 25
        local stepInfoX = 150
        local stepInfoY = 25

        drawTinyText(titleX, titleY, "Proteus Generative Sequencer")
        
        -- Show current scale and root note
        local scaleText = rootNoteNames[(rootNote % 12) + 1] .. " " .. scaleNames[scaleIndex]
        drawText(seqInfoX, seqInfoY, scaleText)
        
        -- Improved sequence visualization
        local gridX = margin
        local gridY = 35  -- Decreased by 1 more pixel (from 36 to 35)
        local cellWidth = 12
        local cellHeight = 12
        local spacing = 2
        local cellsPerRow = 8
        
        for i = 1, sequenceLength do
            local stepData = sequence[i]
            local row = math.floor((i-1) / cellsPerRow)
            local col = (i-1) % cellsPerRow
            
            local x = gridX + col * (cellWidth + spacing)
            local y = gridY + row * (cellHeight + spacing)
            
            -- Cell brightness based on gate and current step
            local brightness = 1
            if stepData.gate then brightness = 8 end
            if i == currentStep then brightness = 15 end
            
            -- Draw cell
            drawRectangle(x, y, x + cellWidth, y + cellHeight, brightness)
            
            -- If this is a note (not a rest), indicate the pitch height
            if stepData.gate then
                local pitchValue = (stepData.pitch * 12) % 12
                local pitchHeight = math.floor((cellHeight - 4) * (pitchValue / 12))
                drawLine(x + 2, y + pitchHeight + 2, x + cellWidth - 2, y + pitchHeight + 2, 0)
            end
        end
        
        -- Display parameter information
        local paramsX = 150
        local paramsY = 26
        local lineHeight = 8
        
        drawTinyText(paramsX, paramsY, "Step: " .. currentStep .. "/" .. sequenceLength)
        drawTinyText(paramsX, paramsY + lineHeight, "Rest: " .. restProbability .. "%")
        drawTinyText(paramsX, paramsY + lineHeight*2, "Seq Prob: " .. sequenceProbability .. "%")
        drawTinyText(paramsX, paramsY + lineHeight*3, "Gate: " .. gateDuration .. "ms")
        drawTinyText(paramsX, paramsY + lineHeight*4, "Octave: " .. baseOctave)
        
        -- Display sequence count and indicator
        drawTinyText(paramsX, paramsY + lineHeight*6, "Sequences: " .. sequenceCount)
        if showNewSequenceIndicator then
            drawText(paramsX + 75, paramsY + lineHeight*6, "*")
        end
        return true
    end
}
