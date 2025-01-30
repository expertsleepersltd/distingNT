-- ADSR Envelope with Minimal GC
--[[
An Attack Decay Sustain Release envelope with either linear or exponential stages.
Input a gate. Outputs a CV.
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
-------------------------------------------------
-- ADSR Envelope with Minimal GC
-------------------------------------------------
-- PHASE DEFINITIONS
local IDLE = -1
local ATTACK = 0
local DECAY = 1
local SUSTAIN = 2
local RELEASE = 3

-- CONSTANTS
local EXP_FACTOR = -5
local SUSTAIN_LINE_PX = 20 -- fixed horizontal length of the sustain segment

-- MODULE STATE
local gateState = false
local phase = IDLE
local envelope = 0
local timeInPhase = 0
local startLevel = 0
local modeIndex = 1 -- 1 = Linear, 2 = Exponential

-- Pre-allocated output table for step()
-- so we don't create a new table every step
local stepOutputs = {0}

-- Pre-allocated points table for draw()
-- (5 points: start baseline, attack peak, decay end, sustain end, release end)
local points = {{0, 0}, {0, 0}, {0, 0}, {0, 0}, {0, 0}}

-------------------------------------------------
-- ENVELOPE CALCULATION
-------------------------------------------------
local function calculateEnvelope(dt, attack, decay, sustain, release)
    timeInPhase = timeInPhase + dt

    if phase == ATTACK then
        if modeIndex == 2 then
            -- Exponential
            envelope = startLevel + (1 - startLevel) *
                           (1 - math.exp(EXP_FACTOR * (timeInPhase / attack)))
        else
            -- Linear
            envelope = startLevel + (1 - startLevel) * (timeInPhase / attack)
        end

        if timeInPhase >= attack then
            envelope = 1
            timeInPhase = 0
            startLevel = 1
            phase = DECAY
        end

    elseif phase == DECAY then
        if modeIndex == 2 then
            -- Exponential decay
            envelope = sustain + (1 - sustain) *
                           math.exp(EXP_FACTOR * (timeInPhase / decay))
        else
            -- Linear decay
            envelope = 1 - (timeInPhase / decay) * (1 - sustain)
        end

        if timeInPhase >= decay then
            envelope = sustain
            timeInPhase = 0
            startLevel = sustain
            phase = SUSTAIN
        end

    elseif phase == SUSTAIN then
        -- Constant sustain
        envelope = sustain

    elseif phase == RELEASE then
        if modeIndex == 2 then
            -- Exponential release
            envelope = startLevel *
                           math.exp(EXP_FACTOR * (timeInPhase / release))
        else
            -- Linear release
            envelope = startLevel * (1 - timeInPhase / release)
        end

        if timeInPhase >= release then
            envelope = 0
            timeInPhase = 0
            startLevel = 0
            phase = IDLE
        end
    end

    return envelope
end

-------------------------------------------------
-- SCRIPT DEFINITION
-------------------------------------------------
return {
    name = "ADSR Envelope",
    author = "Your Name",

    init = function(self)
        return {
            inputs = {kGate},
            outputs = {kLinear},
            parameters = {
                {"Attack", 5, 3000, 250, kMilliseconds},
                {"Decay", 5, 3000, 100, kMilliseconds},
                {"Sustain", 0, 100, 70, kPercent},
                {"Release", 5, 3000, 500, kMilliseconds},
                {"Mode", {"Linear", "Exponential"}, 1}
            }
        }
    end,

    gate = function(self, input, rising)
        if input == 1 then
            gateState = rising
            if rising then
                -- Begin Attack
                startLevel = envelope
                phase = ATTACK
                timeInPhase = 0
            else
                -- Begin Release
                startLevel = envelope
                phase = RELEASE
                timeInPhase = 0
            end
        end
    end,

    step = function(self, dt, inputs)
        local attack = self.parameters[1] / 1000
        local decay = self.parameters[2] / 1000
        local sustain = self.parameters[3] / 100
        local release = self.parameters[4] / 1000

        modeIndex = self.parameters[5] -- 1=Linear, 2=Exponential

        local env = calculateEnvelope(dt, attack, decay, sustain, release)

        -- Reuse the 'stepOutputs' table
        stepOutputs[1] = env * 10 -- 0-10V
        return stepOutputs
    end,

    draw = function(self)
        local width = 256
        local height = 64
        local headerHeight = 12
        local textHeight = 12
        local baselineY = height - 2
        local maxAmplitude = baselineY - headerHeight - textHeight

        -- Parameters
        local attack = self.parameters[1] / 1000
        local decay = self.parameters[2] / 1000
        local sustain = self.parameters[3] / 100
        local release = self.parameters[4] / 1000
        modeIndex = self.parameters[5] -- In case it's needed, though we only check 'phase' here

        local totalTime = attack + decay + release
        local availableWidth = (width - 20) - SUSTAIN_LINE_PX
        local scaleX = availableWidth / totalTime
        local scaleY = maxAmplitude

        -----------------------------------------
        -- Update the existing 'points' in place
        -----------------------------------------

        -- (1) Start: baseline
        points[1][1] = 10
        points[1][2] = baselineY

        -- (2) Attack peak
        local attackX = points[1][1] + (attack * scaleX)
        local attackY = baselineY - scaleY
        points[2][1] = attackX
        points[2][2] = attackY

        -- (3) Decay end => sustain start
        local decayX = points[2][1] + (decay * scaleX)
        local decayY = baselineY - (scaleY * sustain)
        points[3][1] = decayX
        points[3][2] = decayY

        -- (4) Sustain end => horizontal line
        points[4][1] = decayX + SUSTAIN_LINE_PX
        points[4][2] = decayY

        -- (5) Release end => back to baseline
        points[5][1] = points[4][1] + (release * scaleX)
        points[5][2] = baselineY

        -----------------------------------------
        -- Draw lines with highlighting
        -----------------------------------------
        --
        -- Lines:
        --  (1->2) Attack
        --  (2->3) Decay
        --  (3->4) Sustain
        --  (4->5) Release
        --
        for i = 1, 4 do
            local color = 7 -- default dim color

            if (i == 1 and phase == ATTACK) or (i == 2 and phase == DECAY) then
                color = 15
            elseif i == 3 and phase == SUSTAIN then
                color = 15
            elseif i == 4 and phase == RELEASE then
                color = 15
            end

            drawSmoothLine(points[i][1], points[i][2], points[i + 1][1],
                           points[i + 1][2], color)
        end

        -----------------------------------------
        -- Label the segments near each endpoint
        -----------------------------------------
        -- Attack near points[2], Decay near points[3], etc.
        drawText(points[2][1], points[2][2] - 5, "A")
        drawText(points[3][1], points[3][2] - 5, "D")
        drawText(points[4][1], points[4][2] - 5, "S")
        drawText(points[5][1], points[5][2] - 5, "R")
    end
}
