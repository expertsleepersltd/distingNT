-- Markov Chain Sequencer
--[[
A probabilistic sequencer that generates musical patterns using Markov chains.
• Input 1: Clock gate - advances sequence
• Input 2: Reset trigger - returns to step 1
• Input 3: Mutation trigger - changes notes, keeps rhythm
• Input 4: Regenerate trigger - completely new sequence

Outputs: 1=Pitch CV, 2=Gate, 3=Velocity CV

"Emotion" parameter influences the musical character:
- Low values: Melancholic/pensive (minor keys, descending patterns)
- Mid values: Neutral/balanced (mixed directions, moderate intervals)
- High values: Uplifting/energetic (major keys, rising patterns)
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

For more information, please refer to <https://unlicense.org>]] --
local NUM_STEPS = 16
local ROOT_NAMES = {
    "C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"
}
local SCALES = {
    {0, 2, 4, 5, 7, 9, 11}, {0, 2, 3, 5, 7, 8, 10}, {0, 2, 3, 5, 7, 8, 11},
    {0, 2, 4, 7, 9}, {0, 3, 5, 7, 10}, {0, 1, 5, 7, 8}, {0, 2, 4, 6, 11},
    {0, 1, 4, 5, 7, 8, 11}, {0, 2, 3, 6, 7, 8, 11}, {0, 2, 4, 6, 8, 10}
}
local SCALE_NAMES = {
    "Major", "Natural Minor", "Harmonic Minor", "Major Pentatonic",
    "Minor Pentatonic", "Miyako Bushi", "Prometheus", "Hungarian Minor",
    "Double Harmonic", "Whole Tone"
}

local function get_transition_matrix(scaleIndex, emotion)
    local scaleLength = #SCALES[scaleIndex]
    local matrix
    local emotionFactor = emotion / 100
    if scaleIndex == 6 then
        matrix = {
            [1] = {0.1, 0.4, 0.1, 0.3, 0.1},
            [2] = {0.3, 0.1, 0.3, 0.1, 0.2},
            [3] = {0.1, 0.4, 0.1, 0.3, 0.1},
            [4] = {0.3, 0.1, 0.4, 0.1, 0.1},
            [5] = {0.5, 0.2, 0.1, 0.1, 0.1}
        }
    elseif scaleIndex == 7 then
        matrix = {
            [1] = {0.1, 0.3, 0.2, 0.3, 0.1},
            [2] = {0.2, 0.1, 0.3, 0.1, 0.3},
            [3] = {0.1, 0.2, 0.1, 0.4, 0.2},
            [4] = {0.2, 0.2, 0.2, 0.1, 0.3},
            [5] = {0.4, 0.1, 0.2, 0.2, 0.1}
        }
    elseif scaleLength == 5 then
        matrix = {
            [1] = {0.2, 0.3, 0.2, 0.2, 0.1},
            [2] = {0.2, 0.1, 0.3, 0.2, 0.2},
            [3] = {0.1, 0.2, 0.1, 0.4, 0.2},
            [4] = {0.3, 0.1, 0.2, 0.1, 0.3},
            [5] = {0.4, 0.2, 0.1, 0.2, 0.1}
        }
    elseif scaleLength == 6 then
        matrix = {
            [1] = {0.1, 0.2, 0.3, 0.2, 0.1, 0.1},
            [2] = {0.2, 0.1, 0.2, 0.2, 0.2, 0.1},
            [3] = {0.1, 0.2, 0.1, 0.3, 0.2, 0.1},
            [4] = {0.1, 0.1, 0.2, 0.1, 0.3, 0.2},
            [5] = {0.2, 0.1, 0.1, 0.2, 0.1, 0.3},
            [6] = {0.3, 0.1, 0.2, 0.1, 0.2, 0.1}
        }
    else
        matrix = {
            [1] = {0.1, 0.3, 0.2, 0.2, 0.1, 0.05, 0.05},
            [2] = {0.2, 0.1, 0.3, 0.1, 0.2, 0.05, 0.05},
            [3] = {0.1, 0.2, 0.1, 0.3, 0.1, 0.15, 0.05},
            [4] = {0.3, 0.1, 0.2, 0.1, 0.2, 0.05, 0.05},
            [5] = {0.3, 0.1, 0.05, 0.2, 0.1, 0.2, 0.05},
            [6] = {0.05, 0.2, 0.2, 0.05, 0.2, 0.1, 0.2},
            [7] = {0.4, 0.05, 0.05, 0.1, 0.2, 0.1, 0.1}
        }
    end
    local modifiedMatrix = {}
    for i = 1, #matrix do
        modifiedMatrix[i] = {}
        local totalProb = 0
        for j = 1, #matrix[i] do totalProb = totalProb + matrix[i][j] end
        for j = 1, #matrix[i] do
            local emotionInfluence
            if emotionFactor < 0.5 then
                if j < i then
                    emotionInfluence = 1 + (0.5 - emotionFactor) * 1.5
                elseif j > i then
                    emotionInfluence = 1 - (0.5 - emotionFactor) * 1.5
                else
                    emotionInfluence = 1
                end
            else
                if j > i then
                    emotionInfluence = 1 + (emotionFactor - 0.5) * 1.5
                elseif j < i then
                    emotionInfluence = 1 - (emotionFactor - 0.5) * 1.5
                else
                    emotionInfluence = 1
                end
            end
            modifiedMatrix[i][j] = matrix[i][j] * emotionInfluence
        end
        local newTotal = 0
        for j = 1, #modifiedMatrix[i] do
            newTotal = newTotal + modifiedMatrix[i][j]
        end
        for j = 1, #modifiedMatrix[i] do
            modifiedMatrix[i][j] = modifiedMatrix[i][j] * (totalProb / newTotal)
        end
    end
    return modifiedMatrix
end

local RHYTHM_PATTERNS = {
    {1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0},
    {1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0},
    {1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1},
    {1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0},
    {1, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0},
    {1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 0},
    {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1},
    {1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1}
}

local sequence = {}
local lastNoteIndex = 1
local currentStep = 1
local mutationPending = false
local regeneratePending = false
local randomizePending = false
local currentRhythm = {}
local outputTable = {0.0, 0.0, 0.0}

local function init_sequence(self)
    for i = 1, NUM_STEPS do
        sequence[i] = {pitch = 0, active = 1, velocity = 100, octave = 0}
    end
    local emotion = (self and self.parameters and self.parameters[3]) or 50
    local patternIndex
    if emotion > 70 then
        patternIndex = math.random(5, 8)
    elseif emotion < 30 then
        patternIndex = math.random(1, 4)
    else
        patternIndex = math.random(1, #RHYTHM_PATTERNS)
    end
    currentRhythm = {}
    for i = 1, NUM_STEPS do
        currentRhythm[i] = RHYTHM_PATTERNS[patternIndex][i]
    end
    for i = 1, NUM_STEPS do sequence[i].active = currentRhythm[i] end
    lastNoteIndex = 1
end

local function full_generate_sequence(self)
    local new_seq = {}
    local root = self.parameters[1]
    local scaleIndex = self.parameters[2]
    local scale = SCALES[scaleIndex]
    local emotion = self.parameters[3]
    local range = self.parameters[4]
    local jumpiness = self.parameters[5]
    local baseOctave = self.parameters[7]
    local tm = get_transition_matrix(scaleIndex, emotion)
    local local_last = lastNoteIndex
    for i = 1, NUM_STEPS do
        local probs = tm[local_last]
        local r = math.random()
        local cum = 0
        local nextIndex = local_last
        for j = 1, #scale do
            cum = cum + probs[j]
            if r <= cum then
                nextIndex = j
                break
            end
        end
        local octaveShift = 0
        if range > 1 then
            local jumpUp = (jumpiness / 100) * (emotion / 100)
            local jumpDown = (jumpiness / 100) * (1 - (emotion / 100))
            if math.random() < jumpUp then
                octaveShift = 1
            elseif math.random() < jumpDown then
                octaveShift = -1
            end
        end
        local midiNote = root + scale[nextIndex] +
                             ((baseOctave + octaveShift) * 12)
        local vMin = 80 + math.abs(emotion - 50)
        local vMax = 127
        if vMin > vMax then vMin = vMax - 10 end
        new_seq[i] = {
            pitch = midiNote,
            active = sequence[i].active,
            velocity = math.random(vMin, vMax),
            octave = octaveShift
        }
        local_last = nextIndex
    end
    return new_seq, local_last
end

local function generate_sequence(self)
    local new_seq, new_last = full_generate_sequence(self)
    for i = 1, NUM_STEPS do sequence[i] = new_seq[i] end
    lastNoteIndex = new_last
end

local function mutate_sequence(self)
    local new_seq, new_last = full_generate_sequence(self)
    for i = 1, NUM_STEPS do
        if math.random() < ((self.parameters[6] / 100) / NUM_STEPS) then
            sequence[i] = new_seq[i]
        end
    end
    lastNoteIndex = new_last
end

local function draw_seq(self)
    local text = ROOT_NAMES[(self.parameters[1] % 12) + 1] .. " " ..
                     SCALE_NAMES[self.parameters[2]]
    local gridX = 8;
    local gridY = 30;
    local cw = 15;
    local ch = 15

    drawText(gridX, 20, text)

    for i = 1, NUM_STEPS do
        local x = gridX + ((i - 1) % 8) * cw
        local y = gridY + math.floor((i - 1) / 8) * ch
        local bright = sequence[i].active == 1 and 10 or 3

        if i == currentStep then bright = 15 end

        drawRectangle(x, y, x + cw - 2, y + ch - 2, bright)

        if sequence[i].active == 1 then
            local ph = math.floor((127 - (sequence[i].pitch % 12) * 5) / 15)
            drawLine(x + 2, y + ph, x + cw - 4, y + ph, 1)
        end
    end
    drawText(10, 55, "Step: " .. currentStep .. "/" .. NUM_STEPS)
end

local function init_params(self)
    local params = {
        inputs = {kGate, kTrigger, kTrigger, kTrigger},
        outputs = 3,
        inputNames = {"Clock", "Reset", "Randomize", "Regenerate"},
        outputNames = {"V/Oct", "Gate", "Velocity"},
        parameters = {
            {"Root Note", 0, 127, 60, kMIDINote}, {"Scale", SCALE_NAMES, 1},
            {"Emotion", 0, 100, 50, kPercent}, {"Range", 1, 3, 2},
            {"Jumpiness", 0, 100, 30, kPercent},
            {"Mutation Rate", 0, 100, 20, kPercent}, {"Octave", -2, 2, 0},
            {"Randomize", 0, 1, 0}, {"Regenerate", 0, 1, 0}
        }
    }
    return params
end

local function ensure_initialized(self)
    if #sequence == 0 then
        init_sequence(self)
        lastNoteIndex = 1
        generate_sequence(self)
    end
end

return {
    name = 'SeqMarkov',
    author = 'Thorinside | Claude | ChatGPT o3-mini-high',
    init = function(self)
        local params = init_params(self)
        return params
    end,

    gate = function(self, input, rising)
        ensure_initialized(self)
        if input == 1 and rising then
            currentStep = currentStep + 1
            if currentStep > NUM_STEPS then
                currentStep = 1
                if math.random() < (self.parameters[6] / 100) then
                    mutationPending = true
                end
            end
            if mutationPending and currentStep == 1 then
                mutate_sequence(self)
                mutationPending = false
            end
            if regeneratePending and currentStep == 1 then
                init_sequence(self)
                lastNoteIndex = 1
                generate_sequence(self)
                regeneratePending = false
            end
            if randomizePending and currentStep == 1 then
                generate_sequence(self)
                randomizePending = false
            end
        end
    end,

    trigger = function(self, input)
        ensure_initialized(self)
        if input == 2 then
            currentStep = 1
        elseif input == 3 then
            generate_sequence(self)
        elseif input == 4 then
            init_sequence(self)
            lastNoteIndex = 1
            generate_sequence(self)
            currentStep = 1
        end
    end,

    step = function(self, dt, inputs)
        ensure_initialized(self)
        if self.parameters[8] == 1 then randomizePending = true end
        if self.parameters[9] == 1 then regeneratePending = true end
        if sequence[currentStep] and sequence[currentStep].active == 1 then
            outputTable[1] = sequence[currentStep].pitch / 12
            outputTable[2] = inputs[1] > 1.0 and 5.0 or 0.0
            outputTable[3] = (sequence[currentStep].velocity / 127) * 10.0
        else
            outputTable[1] = sequence[currentStep].pitch / 12
            outputTable[2] = 0.0
            outputTable[3] = 0.0
        end
        return outputTable
    end,

    draw = function(self)
        ensure_initialized(self)
        local status, err = pcall(function() draw_seq(self) end)
        if not status then debug("Error in draw: " .. tostring(err)) end
    end
}
