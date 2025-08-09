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
local density = 80 -- percentage (higher = more notes, lower = more rests)
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

-- Advanced mutation system constants
local DONT_MUTATE = 0
local CHANGE_NOTES = 1
local OCTAVE_UP = 2
local OCTAVE_DOWN = 3

local NM_REPEAT = 0
local NM_UP = 1
local NM_DOWN = 2
local NM_NEW = 3

-- Enhanced state variables
local repetitionCount = 0
local octaveOffset = 0
local maxOctaveOffsetUp = 2
local maxOctaveOffsetDown = 2
local octaveChangeProbability = 20
local noteChangeProbability = 20
local mutate = true
local accumulate = true
local poissonLambda = 12
local noteOptionWeights = {5, 5, 5, 10} -- weights for NM_REPEAT, NM_UP, NM_DOWN, NM_NEW
local prevNote = {pitch = 0, muted = false}
local restOrder = {} -- Shuffled array for distributing rests
local numRestNotes = 0

-- Enhanced scale system with weighted tone selection (matching C++ implementation)
-- IMPORTANT: Scales use 1-indexed semitones (1=C, 12=B) matching original C++ 
local scales = {
    {1, 3, 5, 6, 8, 10, 12}, -- Major
    {1, 3, 4, 6, 8, 9, 11}, -- Natural Minor  
    {1, 3, 4, 6, 8, 9, 12}, -- Harmonic Minor
    {1, 3, 5, 8, 10}, -- Major Pentatonic
    {1, 4, 6, 8, 11}, -- Minor Pentatonic
    {1, 3, 4, 6, 8, 10, 11}, -- Dorian
    {1, 3, 5, 6, 8, 10, 11}, -- Mixolydian
    {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}, -- Chromatic
    {1}, -- Tuning
    {1, 2, 4, 6, 8, 9, 11}, -- Bhairavi
    {1, 2, 5, 6, 8, 10, 11} -- Ahir Bhairav
}

local scaleNames = {
    "Major", "Natural Minor", "Harmonic Minor", "Major Pentatonic", "Minor Pentatonic", 
    "Dorian", "Mixolydian", "Chromatic", "Tuning", "Bhairavi", "Ahir Bhairav"
}

-- Weighted probabilities for each scale degree (higher = more likely)
local scaleWeights = {
    {3, 2, 3, 3, 3, 2, 1}, -- Major
    {3, 2, 3, 3, 3, 2, 1}, -- Natural Minor
    {3, 2, 3, 3, 3, 2, 1}, -- Harmonic Minor
    {2, 1, 1, 1, 1}, -- Major Pentatonic
    {1, 1, 1, 1, 1}, -- Minor Pentatonic
    {3, 2, 3, 3, 3, 2, 1}, -- Dorian
    {3, 2, 3, 3, 3, 2, 1}, -- Mixolydian
    {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}, -- Chromatic
    {1}, -- Tuning
    {3, 1, 1, 1, 2, 1, 1}, -- Bhairavi
    {3, 1, 1, 1, 2, 1, 1} -- Ahir Bhairav
}
local scaleIndex = 1 -- Default to Major scale
local scale = scales[scaleIndex]
local rootNote = 0 -- C
local rootNoteNames = {
    "C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"
}
local showNewSequenceIndicator = false

-- Utility functions
local function weightedRandom(weights)
    local sumOfWeight = 0
    for i = 1, #weights do
        sumOfWeight = sumOfWeight + weights[i]
    end
    
    local rnd = math.random(sumOfWeight)
    
    for i = 1, #weights do
        if rnd <= weights[i] then
            return i
        end
        rnd = rnd - weights[i]
    end
    return 1 -- fallback
end

-- Simplified Poisson CDF approximation
local function poissonCDF(k, lambda)
    -- For small lambda, use exact calculation
    if lambda < 30 then
        local sum = 0
        local term = math.exp(-lambda)
        sum = sum + term
        
        for i = 1, k do
            term = term * lambda / i
            sum = sum + term
        end
        return sum
    else
        -- For larger lambda, use normal approximation with error function approximation
        local mu = lambda
        local sigma = math.sqrt(lambda)
        local z = (k + 0.5 - mu) / sigma
        
        -- Approximation of erf function for normal CDF
        -- Using Abramowitz and Stegun approximation
        local a1 =  0.254829592
        local a2 = -0.284496736
        local a3 =  1.421413741
        local a4 = -1.453152027
        local a5 =  1.061405429
        local p  =  0.3275911
        
        local sign = 1
        if z < 0 then
            sign = -1
        end
        z = math.abs(z) / math.sqrt(2)
        
        local t = 1.0 / (1.0 + p * z)
        local y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-z * z)
        
        return 0.5 * (1.0 + sign * y)
    end
end

local function generateNote()
    local currentWeights = scaleWeights[scaleIndex]
    local scaleDegree = weightedRandom(currentWeights)
    local ourSemitone = scale[scaleDegree]
    -- Calculate MIDI note number (C4 = 60)
    local baseMidiNote = 60 + rootNote -- rootNote is offset from C
    local newNoteMIDI = baseMidiNote + ourSemitone - 1
    -- Add random octave variation
    local octaveVariation = math.random(-1, 1)
    newNoteMIDI = newNoteMIDI + (octaveOffset + octaveVariation) * 12
    -- Convert to V/Oct (C4 = 0V)
    return (newNoteMIDI - 60) / 12
end

local function findScaleDegreeIndex(noteValue)
    -- Convert V/Oct back to MIDI and find which scale tone it belongs to
    local midiNote = noteValue * 12 + 60
    local noteInScale = (midiNote - 60 - rootNote) % 12 + 1 -- Get semitone within octave (1-12)
    
    for i, degree in ipairs(scale) do
        if degree == noteInScale then
            return i
        end
    end
    return 1 -- fallback to root
end

local function generateNoteWithRelationship(noteKind, previousNote)
    if noteKind == NM_REPEAT and previousNote then
        return previousNote
    elseif noteKind == NM_UP and previousNote then
        -- Find current position in scale and move up
        local prevMidi = previousNote * 12 + 60
        local prevOctave = math.floor((prevMidi - 60 - rootNote) / 12)
        local scaleDegreeIndex = findScaleDegreeIndex(previousNote)
        
        scaleDegreeIndex = scaleDegreeIndex + 1
        if scaleDegreeIndex > #scale then
            scaleDegreeIndex = 1
            prevOctave = prevOctave + 1
        end
        
        local newMidi = 60 + rootNote + scale[scaleDegreeIndex] - 1 + prevOctave * 12
        return (newMidi - 60) / 12
    elseif noteKind == NM_DOWN and previousNote then
        -- Find current position in scale and move down
        local prevMidi = previousNote * 12 + 60
        local prevOctave = math.floor((prevMidi - 60 - rootNote) / 12)
        local scaleDegreeIndex = findScaleDegreeIndex(previousNote)
        
        scaleDegreeIndex = scaleDegreeIndex - 1
        if scaleDegreeIndex < 1 then
            scaleDegreeIndex = #scale
            prevOctave = prevOctave - 1
        end
        
        local newMidi = 60 + rootNote + scale[scaleDegreeIndex] - 1 + prevOctave * 12
        return (newMidi - 60) / 12
    else
        return generateNote()
    end
end

local function changeOctave(octaveChange)
    if octaveOffset + octaveChange > maxOctaveOffsetUp then
        return -- Can't go higher
    elseif octaveOffset + octaveChange < -maxOctaveOffsetDown then
        return -- Can't go lower
    else
        -- Update existing sequence notes by transposing them
        for i = 1, maxSteps do
            if sequence[i] and sequence[i].pitch then
                -- Transpose pitch by octave (1 octave = 1V in V/Oct)
                sequence[i].pitch = sequence[i].pitch + octaveChange
            end
        end
        octaveOffset = octaveOffset + octaveChange
    end
end

local function changeNotes()
    -- Substitute notes in the melody with new notes (matching original C++)
    local noteToChange = math.random(1, sequenceLength)
    local newNotePitch = generateNote()
    
    -- New notes should follow density (random decision, NOT restorder system)
    local restProbability = 100 - density
    local noteOnChoice = math.random(100)
    local isMuted = noteOnChoice <= restProbability
    
    sequence[noteToChange] = {
        pitch = newNotePitch,
        muted = isMuted
    }
end

local function updateRests()
    -- Calculate how many notes should be rests based on density
    local restProbability = 100 - density
    numRestNotes = math.ceil(sequenceLength * (restProbability / 100))
    if numRestNotes == sequenceLength then
        numRestNotes = numRestNotes - 1 -- Always leave at least one note
    end
    
    -- Apply muted status using the shuffled rest order (matching original C++)
    for i = 1, sequenceLength do
        local stepIndex = restOrder[i]
        if stepIndex and stepIndex <= maxSteps then
            if i <= numRestNotes then
                -- This step should be muted
                sequence[stepIndex].muted = true
            else
                -- This step should play
                sequence[stepIndex].muted = false
            end
        end
    end
end

local function generateSequence()
    octaveOffset = 0
    repetitionCount = 0
    
    -- Generate shuffled rest order
    for i = 1, sequenceLength do
        restOrder[i] = i
    end
    
    -- Simple shuffle algorithm
    for i = sequenceLength, 2, -1 do
        local j = math.random(i)
        restOrder[i], restOrder[j] = restOrder[j], restOrder[i]
    end
    
    -- Calculate number of rest notes
    local restProbability = 100 - density
    numRestNotes = math.ceil(sequenceLength * (restProbability / 100))
    if numRestNotes == sequenceLength then
        numRestNotes = numRestNotes - 1 -- Always leave at least one note
    end
    
    -- Generate all notes first (no rests yet, matching original C++)
    for i = 1, maxSteps do
        local noteKind
        local noteValue
        
        -- First note is always new, others follow weighted relationship logic
        if i == 1 then
            noteKind = NM_NEW
        else
            -- weightedRandom returns 1-based index, convert to 0-based for noteKind
            noteKind = weightedRandom(noteOptionWeights) - 1
        end
        
        if noteKind == NM_REPEAT and prevNote then
            noteValue = prevNote.pitch
        elseif (noteKind == NM_UP or noteKind == NM_DOWN) and prevNote then
            noteValue = generateNoteWithRelationship(noteKind, prevNote.pitch)
        else -- NM_NEW
            noteValue = generateNote()
        end
        
        -- All notes start as active, muted status applied later
        sequence[i] = {pitch = noteValue, muted = false}
        prevNote = sequence[i] -- Update prevNote after EVERY note (matching original)
    end
    
    -- Now apply muted status using the sophisticated rest distribution system
    updateRests()
    
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
                {"Density", 0, 100, density, kPercent},
                {"Sequence Probability", 0, 100, sequenceProbability, kPercent},
                {"Gate Duration", 20, 2000, gateDuration, kMs},
                {"Base Octave", -2, 5, baseOctave, kInt},
                {"Scale", scaleNames, scaleIndex, kEnum},
                {"Root Note", rootNoteNames, 0, kEnum},
                {"Patience", 1, 50, poissonLambda, kInt},
                {"Octave Change %", 0, 100, octaveChangeProbability, kPercent},
                {"Note Change %", 0, 100, noteChangeProbability, kPercent},
                {"Octave Range", {"None", "±1", "±2"}, 3, kEnum},
                {"Mutation Mode", {"Normal", "Regen Only", "Locked"}, 1, kEnum},
                {"Generate New", 0, 1, 0, kBool}
            }
        }
    end,

    gate = function(self, input, rising)
        if input == 1 and rising then
            currentStep = currentStep + 1
            if currentStep > sequenceLength then
                currentStep = 1
                
                local melodyChanged = false
                
                -- Advanced sequence regeneration using Poisson distribution
                if accumulate then
                    repetitionCount = repetitionCount + 1
                    
                    -- Calculate Poisson CDF for current repetition count
                    local p = poissonCDF(repetitionCount, poissonLambda)
                    
                    -- Use probability to decide if we get a new melody
                    local choice = math.random(100)
                    if choice < p * 100 then
                        generateSequence()
                        melodyChanged = true
                    end
                else
                    -- Simple probability-based regeneration for non-accumulating mode
                    if math.random(100) <= sequenceProbability then
                        generateSequence()
                        melodyChanged = true
                    end
                end
                
                -- Apply mutations if sequence wasn't regenerated and mutations are enabled
                if not melodyChanged and mutate then
                    -- Octave changes with bouncing logic
                    local octaveChoice = math.random(100)
                    if octaveChoice < octaveChangeProbability then
                        local coinFlip = math.random(100)
                        if coinFlip < 50 then
                            if octaveOffset <= -maxOctaveOffsetDown then
                                changeOctave(1) -- bounce up
                            else
                                changeOctave(-1)
                            end
                        else
                            if octaveOffset >= maxOctaveOffsetUp then
                                changeOctave(-1) -- bounce down
                            else
                                changeOctave(1)
                            end
                        end
                    end
                    
                    -- Note changes
                    local noteChoice = math.random(100)
                    if noteChoice < noteChangeProbability then
                        changeNotes()
                    end
                end
            end

            local stepData = sequence[currentStep]
            if stepData and not stepData.muted then
                -- If this note is not muted, activate gate and set release timer
                gateActive = true
                gateDuration = nextGateDuration
                -- Set gate release time to the current gate duration in seconds
                gateReleaseTime = gateDuration / 1000
            end
        end
    end,

    trigger = function(self, input) if input == 2 then currentStep = 1 end end,

    step = function(self, dt, inputs)
        local prevDensity = density
        local prevSequenceLength = sequenceLength
        
        sequenceLength = self.parameters[1]
        density = self.parameters[2]
        sequenceProbability = self.parameters[3]
        nextGateDuration = self.parameters[4]
        baseOctave = self.parameters[5]
        scaleIndex = self.parameters[6]
        rootNote = self.parameters[7] - 1
        poissonLambda = self.parameters[8]
        octaveChangeProbability = self.parameters[9]
        noteChangeProbability = self.parameters[10]
        
        -- Update rest distribution if density changed (but keep same rest order)
        if density ~= prevDensity then
            updateRests() -- This only updates muted status, doesn't reshuffle
        end
        
        -- Only regenerate rest order if sequence length changed
        if sequenceLength ~= prevSequenceLength then
            -- Need to regenerate rest order for new length
            for i = 1, sequenceLength do
                restOrder[i] = i
            end
            for i = sequenceLength, 2, -1 do
                local j = math.random(i)
                restOrder[i], restOrder[j] = restOrder[j], restOrder[i]
            end
            updateRests()
        end
        
        -- Handle octave range setting
        local octaveRangeSetting = self.parameters[11]
        if octaveRangeSetting == 1 then
            maxOctaveOffsetUp = 0
            maxOctaveOffsetDown = 0
        elseif octaveRangeSetting == 2 then
            maxOctaveOffsetUp = 1
            maxOctaveOffsetDown = 1
        else -- octaveRangeSetting == 3
            maxOctaveOffsetUp = 2
            maxOctaveOffsetDown = 2
        end
        
        -- Handle mutation mode setting
        local mutationMode = self.parameters[12]
        if mutationMode == 1 then -- Normal
            mutate = true
            accumulate = true
        elseif mutationMode == 2 then -- Regen Only
            mutate = true
            accumulate = false
        else -- mutationMode == 3, Locked
            mutate = false
            accumulate = false
        end
        
        scale = scales[scaleIndex]

        if self.parameters[13] == 1 then generateSequence() end

        if gateDuration <= 0 then gateDuration = nextGateDuration end

        -- Count down the gate release timer
        if gateActive and gateReleaseTime > 0 then
            gateReleaseTime = gateReleaseTime - dt

            -- Check if gate should be released
            if gateReleaseTime <= 0 then gateActive = false end
        end

        -- Output pitch and gate based on muted status
        local currentNote = sequence[currentStep]
        if currentNote and not currentNote.muted then
            output[1] = currentNote.pitch
        else
            -- Keep previous pitch when muted (standard behavior)
            output[1] = output[1] or 0
        end
        output[2] = gateActive and 5 or 0

        return output
    end,

    ui = function(self) return true end,

    setupUi = function(self)
        return {
            ((self and self.parameters and self.parameters[2]) or
                density) / 100.0, -- Pot 1: Density
            ((self and self.parameters and self.parameters[8]) or
                poissonLambda - 1) / 49.0, -- Pot 2: Patience (scaled 0-1)
            ((self and self.parameters and self.parameters[10]) or 
                noteChangeProbability) / 100.0 -- Pot 3: Note Change Probability
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
        setParameter(algorithm, self.parameterOffset + 2, value * 100.0) -- Density
    end,

    pot2Turn = function(self, value)
        algorithm = getCurrentAlgorithm()
        setParameter(algorithm, self.parameterOffset + 8, value * 49 + 1) -- Patience (1-50)
    end,

    pot2Push = function(self, value) exit() end,

    pot3Turn = function(self, value)
        algorithm = getCurrentAlgorithm()
        setParameter(algorithm, self.parameterOffset + 10, value * 100.0) -- Note Change Probability
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
            if not stepData.muted then brightness = 8 end
            if i == currentStep then brightness = 15 end

            drawRectangle(x, y, x + cellWidth, y + cellHeight, brightness)

            -- Draw pitch line for all notes (muted ones will be dimmer)
            if stepData.pitch then
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
                     "Density: " .. density .. "%")
        drawTinyText(paramsX, paramsY + lineHeight * 2,
                     "Patience: " .. poissonLambda)
        drawTinyText(paramsX, paramsY + lineHeight * 3,
                     "Mutate: " .. noteChangeProbability .. "%")
        drawTinyText(paramsX, paramsY + lineHeight * 4, 
                     "Oct: " .. baseOctave .. " (" .. octaveOffset .. ")")
        drawTinyText(paramsX, paramsY + lineHeight * 5,
                     "Reps: " .. repetitionCount)

        -- Show mutation status
        local modeText = "Normal"
        if not mutate and not accumulate then
            modeText = "Locked"
        elseif mutate and not accumulate then
            modeText = "Regen"
        end
        drawTinyText(paramsX, paramsY + lineHeight * 6,
                     "Mode: " .. modeText)

        drawTinyText(paramsX, paramsY + lineHeight * 7,
                     "Sequences: " .. sequenceCount)
        if showNewSequenceIndicator then
            drawText(paramsX + 75, paramsY + lineHeight * 7, "*")
        end

        return true
    end
}
