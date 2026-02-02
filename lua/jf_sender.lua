-- Just Friends Sender
-- Combines simple note sending with clock-based voice playing
-- Supports Standard and Synth modes
-- JF i2c address
local JF_ADDR = 0x70

-- JF ii commands
local JF_TRIGGER    = 1
local JF_RUN_MODE   = 2
local JF_RUN        = 3
local JF_MODE       = 6
local JF_PLAY_VOICE = 8
local JF_PLAY_NOTE  = 9
local JF_RETUNE     = 11
local JF_PITCH      = 13

-- Mode constants
local MODE_STANDARD = 0
local MODE_SYNTH    = 1

-- JF Mode parameter values
local JF_MODE_STANDARD = 1
local JF_MODE_SYNTH    = 2

----------------------------------------------------------------
-- Crow-accurate s16V conversion
-- Uses Teletype standard: 1.0V -> 1638.3
----------------------------------------------------------------
local function pack_s16V_bytes(volts)
    local i = volts * 1638.3

    if i >= 0 then
        i = math.floor(i + 0.5)
    else
        i = math.ceil(i - 0.5)
    end

    if i > 32767 then i = 32767 end
    if i < -32768 then i = -32768 end

    if i < 0 then
        i = i + 65536
    end

    local hi = (i >> 8) & 0xFF
    local lo = i & 0xFF

    return hi, lo
end

----------------------------------------------------------------
-- Convert signed 8-bit to unsigned byte
----------------------------------------------------------------
local function toUnsigned8(val)
    val = math.max(-128, math.min(127, val))
    return val < 0 and (val + 256) or val
end

----------------------------------------------------------------
-- Send JF play_voice command (specific voice channel)
----------------------------------------------------------------
local function sendVoice(channel, volts_pitch, volts_level)
    channel = math.max(1, math.min(6, channel))

    local p_hi, p_lo = pack_s16V_bytes(volts_pitch)
    local l_hi, l_lo = pack_s16V_bytes(volts_level)

    sendI2CCommand(JF_ADDR, JF_PLAY_VOICE, channel, p_hi, p_lo, l_hi, l_lo)
end

----------------------------------------------------------------
-- Send JF play_note command (polyphonic voice allocation)
----------------------------------------------------------------
local function sendNote(volts_pitch, volts_level)
    local p_hi, p_lo = pack_s16V_bytes(volts_pitch)
    local l_hi, l_lo = pack_s16V_bytes(volts_level)

    sendI2CCommand(JF_ADDR, JF_PLAY_NOTE, p_hi, p_lo, l_hi, l_lo)
end

----------------------------------------------------------------
-- Retune a channel to a custom ratio (microtonal tuning)
----------------------------------------------------------------
local function retune(channel, numerator, denominator)
    channel = channel or 0
    numerator = numerator or 0
    denominator = denominator or 0

    channel = math.max(-128, math.min(127, channel))
    numerator = math.max(-128, math.min(127, numerator))
    denominator = math.max(-128, math.min(127, denominator))

    sendI2CCommand(JF_ADDR, JF_RETUNE,
                   toUnsigned8(channel),
                   toUnsigned8(numerator),
                   toUnsigned8(denominator))
end

----------------------------------------------------------------
-- Set pitch of a specific voice (without triggering)
----------------------------------------------------------------
local function setPitch(channel, volts_pitch)
    channel = math.max(1, math.min(6, channel))

    local p_hi, p_lo = pack_s16V_bytes(volts_pitch)
    sendI2CCommand(JF_ADDR, JF_PITCH, toUnsigned8(channel), p_hi, p_lo)
end

----------------------------------------------------------------
-- Set JF mode (0 = Standard, 1 = Synth/Geode)
----------------------------------------------------------------
local function setMode(mode)
    sendI2CCommand(JF_ADDR, JF_MODE, toUnsigned8(mode))
end

----------------------------------------------------------------
-- Set JF run mode (0 = off, 1 = on - enables virtual RUN control)
----------------------------------------------------------------
local function setRunMode(enabled)
    local mode = enabled and 1 or 0
    sendI2CCommand(JF_ADDR, JF_RUN_MODE, toUnsigned8(mode))
end

----------------------------------------------------------------
-- Set JF run voltage (-5V to +5V)
----------------------------------------------------------------
local function setRunVoltage(volts)
    local hi, lo = pack_s16V_bytes(volts)
    sendI2CCommand(JF_ADDR, JF_RUN, hi, lo)
end

----------------------------------------------------------------
-- Send trigger to a specific channel (for Standard mode)
-- channel: 1-6, state: true/false
----------------------------------------------------------------
local function sendTrigger(channel, state)
    channel = math.max(1, math.min(6, channel))
    local s = state and 1 or 0
    sendI2CCommand(JF_ADDR, JF_TRIGGER, toUnsigned8(channel), toUnsigned8(s))
end

----------------------------------------------------------------
-- State
----------------------------------------------------------------
local lastGate = false
local currentCV = 0
local lastCV = 0
local clockTimer = 0
local randomSeed = 12345
local currentVoiceIndex = 1
local pitchSlots = {}
local currentSlotIndex = 1
local initDone = false

-- parameter cache to avoid spamming i2c bus
local lastParams = {}

-- simple random number generator
local function random(min, max)
    randomSeed = (randomSeed * 1103515245 + 12345) & 0x7FFFFFFF
    local rand = (randomSeed >> 16) & 0x7FFF
    return min + (rand % (max - min + 1))
end

-- random volume helper with min/max range
local function randomVolume(minVol, maxVol)
    local range = math.floor((maxVol - minVol) * 100)
    if range <= 0 then return minVol end
    return minVol + (random(0, range) / 100.0)
end

-- Helper to check if parameter changed
local function paramChanged(params, index, threshold)
    threshold = threshold or 0.01
    local current = params[index]
    local last = lastParams[index]
    if last == nil then return true end
    if type(current) == "number" then
        return math.abs(current - last) > threshold
    else
        return current ~= last
    end
end

----------------------------------------------------------------
-- Input source constants
----------------------------------------------------------------
local INPUT_CV_GATE  = 1  -- CV+Gate (direct trigger)
local INPUT_CV_SLOTS = 2  -- CV+Gate with pitch slot accumulation
local INPUT_MIDI     = 3  -- MIDI input

----------------------------------------------------------------
-- Parameter indices
----------------------------------------------------------------
local P_INPUT_SRC     = 1
local P_MIDI_CH       = 2
local P_CLOCK         = 3
local P_VOICE_MODE    = 4
local P_RANDOM_VOL    = 5
local P_CLOCK_RATE    = 6
local P_CLOCK_RANDOM  = 7
local P_LEVEL         = 8
local P_VOL_MIN       = 9
local P_VOL_MAX       = 10
local P_JF_MODE       = 11
local P_RUN_MODE      = 12
local P_RUN_V         = 13

----------------------------------------------------------------
-- Main object
----------------------------------------------------------------
return {
    name   = "JF Sender",
    author = "Mark IJzerman",

    init = function(self)
        initDone = false
        clockTimer = 0
        lastParams = {}

        for i = 1, 6 do
            pitchSlots[i] = 0.0
        end
        currentSlotIndex = 1
        currentVoiceIndex = 1

        return {
            inputs  = {kGate, kLinear},
            outputs = {},

            inputNames  = {"Gate/Trig", "Pitch CV"},
            outputNames = {},

            parameters = {
                {"Input Source", {"CV+Gate", "CV+Slots", "MIDI"}, 1, kEnum},
                {"MIDI Channel", 0, 16, 0, kInteger},
                {"Clock", {"Off", "On"}, 1, kEnum},
                {"Voice Mode", {"Note (poly)", "Round-robin"}, 1, kEnum},
                {"Random Volume", {"Off", "On"}, 1, kEnum},
                {"Clock Rate (ms)", 1, 500, 120, kInteger},
                {"Clock Random (%)", 0, 50, 0, kInteger},
                {"Level (V)", 0, 5, 2, kVolts},
                {"Vol Min (V)", 0, 5, 1, kVolts},
                {"Vol Max (V)", 0, 5, 3, kVolts},
                {"JF Mode", {"Standard", "Synth"}, 2, kEnum},
                {"Run Mode", {"Off", "On"}, 1, kEnum},
                {"Run V", -5, 5, 0, kVolts}
            },
            midi = { channelParameter = P_MIDI_CH, messages = { "note" } }
        }
    end,

    ----------------------------------------------------------------
    -- Continuous processing
    ----------------------------------------------------------------
    step = function(self, dt, inputs)
        currentCV = inputs[2]

        local inputSrc     = self.parameters[P_INPUT_SRC]
        local clockEnabled = self.parameters[P_CLOCK] == 2
        local voiceMode    = self.parameters[P_VOICE_MODE]
        local randomVol    = self.parameters[P_RANDOM_VOL] == 2
        local clockRate    = self.parameters[P_CLOCK_RATE] / 1000.0
        local clockRandom  = self.parameters[P_CLOCK_RANDOM]
        local level        = self.parameters[P_LEVEL]
        local volMin       = self.parameters[P_VOL_MIN]
        local volMax       = self.parameters[P_VOL_MAX]
        local jfMode       = self.parameters[P_JF_MODE]
        local runMode      = self.parameters[P_RUN_MODE] == 2
        local runV         = self.parameters[P_RUN_V]

        local isSynth   = (jfMode == JF_MODE_SYNTH)
        local isStandard = (jfMode == JF_MODE_STANDARD)
        local isMidiInput = (inputSrc == INPUT_MIDI)

        -- Initialize on first frame
        if not initDone then
            local modeVal = isStandard and MODE_STANDARD or MODE_SYNTH
            setMode(modeVal)
            setRunMode(runMode)
            if runMode then
                setRunVoltage(runV)
            end
            if isSynth then
                retune(0, 0, 0)
            end
            initDone = true
        end

        -- Update JF mode when it changes
        if paramChanged(self.parameters, P_JF_MODE, 0) then
            local modeVal = isStandard and MODE_STANDARD or MODE_SYNTH
            setMode(modeVal)
            lastParams[P_JF_MODE] = self.parameters[P_JF_MODE]
            if isSynth then
                retune(0, 0, 0)
            end
        end

        -- Update run mode when it changes
        if paramChanged(self.parameters, P_RUN_MODE, 0) then
            setRunMode(runMode)
            lastParams[P_RUN_MODE] = self.parameters[P_RUN_MODE]
            if runMode then
                setRunVoltage(runV)
                lastParams[P_RUN_V] = runV
            end
        end

        -- Update run voltage when it changes (only if run mode is on)
        if runMode and paramChanged(self.parameters, P_RUN_V) then
            setRunVoltage(runV)
            lastParams[P_RUN_V] = runV
        end

        local actualLevel = randomVol and randomVolume(volMin, volMax) or level

        -- Detect CV change for slot accumulation
        local cvChanged = math.abs(currentCV - lastCV) > 0.01

        -- Only process CV/Gate when not in MIDI mode
        if not isMidiInput then
            -- When clock is ON
            if clockEnabled then
                -- Update pitch slots from CV changes (for Synth mode)
                if cvChanged then
                    pitchSlots[currentSlotIndex] = currentCV
                    currentSlotIndex = currentSlotIndex + 1
                    if currentSlotIndex > 6 then currentSlotIndex = 1 end
                    lastCV = currentCV
                end

                -- Clock timer
                clockTimer = clockTimer + dt

                local actualClockRate = clockRate
                if clockRandom > 0 then
                    local randomOffset = (random(0, clockRandom * 2) - clockRandom) / 100.0
                    actualClockRate = clockRate * (1.0 + randomOffset)
                end

                if clockTimer >= actualClockRate then
                    clockTimer = 0

                    if isSynth then
                        -- Synth mode: send notes
                        local pitch = pitchSlots[currentVoiceIndex]
                        actualLevel = randomVol and randomVolume(volMin, volMax) or level

                        if voiceMode == 1 then
                            sendNote(pitch, actualLevel)
                        else
                            sendVoice(currentVoiceIndex, pitch, actualLevel)
                        end

                        currentVoiceIndex = currentVoiceIndex + 1
                        if currentVoiceIndex > 6 then currentVoiceIndex = 1 end
                    else
                        -- Standard mode: send triggers
                        sendTrigger(currentVoiceIndex, true)

                        currentVoiceIndex = currentVoiceIndex + 1
                        if currentVoiceIndex > 6 then currentVoiceIndex = 1 end
                    end
                end

            -- When clock is OFF: CV modes handle triggering
            else
                if isSynth then
                    -- Synth mode: CV+Gate behavior
                    if inputSrc == INPUT_CV_GATE then
                        local gate = inputs[1] > 2.5

                        if gate and not lastGate then
                            if voiceMode == 1 then
                                sendNote(currentCV, actualLevel)
                            else
                                sendVoice(currentVoiceIndex, currentCV, actualLevel)
                                currentVoiceIndex = currentVoiceIndex + 1
                                if currentVoiceIndex > 6 then currentVoiceIndex = 1 end
                            end
                        end

                        lastGate = gate

                    elseif inputSrc == INPUT_CV_SLOTS then
                        if cvChanged then
                            pitchSlots[currentSlotIndex] = currentCV
                            currentSlotIndex = currentSlotIndex + 1
                            if currentSlotIndex > 6 then currentSlotIndex = 1 end
                            lastCV = currentCV
                        end

                        local gate = inputs[1] > 2.5

                        if gate and not lastGate then
                            local pitch = pitchSlots[currentVoiceIndex]

                            if voiceMode == 1 then
                                sendNote(pitch, actualLevel)
                            else
                                sendVoice(currentVoiceIndex, pitch, actualLevel)
                            end

                            currentVoiceIndex = currentVoiceIndex + 1
                            if currentVoiceIndex > 6 then currentVoiceIndex = 1 end
                        end

                        lastGate = gate
                    end

                else
                    -- Standard mode: gate sends trigger to current voice
                    local gate = inputs[1] > 2.5

                    if gate and not lastGate then
                        sendTrigger(currentVoiceIndex, true)

                        currentVoiceIndex = currentVoiceIndex + 1
                        if currentVoiceIndex > 6 then currentVoiceIndex = 1 end
                    end

                    lastGate = gate
                end
            end
        end

        return {}
    end,

    ----------------------------------------------------------------
    -- MIDI input handling
    ----------------------------------------------------------------
    midiMessage = function(self, message)
        -- Only process MIDI when Input Source is set to MIDI
        local inputSrc = self.parameters[P_INPUT_SRC]
        if inputSrc ~= INPUT_MIDI then return end

        local status = message[1] & 0xF0
        local note = message[2]
        local velocity = message[3]

        local jfMode = self.parameters[P_JF_MODE]
        local voiceMode = self.parameters[P_VOICE_MODE]
        local randomVol = self.parameters[P_RANDOM_VOL] == 2
        local level = self.parameters[P_LEVEL]
        local volMin = self.parameters[P_VOL_MIN]
        local volMax = self.parameters[P_VOL_MAX]

        local isSynth = (jfMode == JF_MODE_SYNTH)

        if status == 0x90 and velocity > 0 then
            -- Note On
            -- Convert MIDI note to V/Oct (note 60 = 0V)
            local pitch = (note - 60) / 12.0

            -- Convert velocity to level (0-127 -> volMin-volMax or use level)
            local actualLevel
            if randomVol then
                actualLevel = randomVolume(volMin, volMax)
            else
                actualLevel = (velocity / 127.0) * level
            end

            if isSynth then
                if voiceMode == 1 then
                    sendNote(pitch, actualLevel)
                else
                    sendVoice(currentVoiceIndex, pitch, actualLevel)
                    currentVoiceIndex = currentVoiceIndex + 1
                    if currentVoiceIndex > 6 then currentVoiceIndex = 1 end
                end
            else
                -- Standard mode: trigger
                sendTrigger(currentVoiceIndex, true)
                currentVoiceIndex = currentVoiceIndex + 1
                if currentVoiceIndex > 6 then currentVoiceIndex = 1 end
            end
        end
        -- Note Off (0x80) or Note On with velocity 0 - JF handles note decay internally
    end,

    ----------------------------------------------------------------
    -- UI drawing
    ----------------------------------------------------------------
    draw = function(self)
        local jfMode       = self.parameters[P_JF_MODE]
        local runMode      = self.parameters[P_RUN_MODE] == 2
        local inputSrc     = self.parameters[P_INPUT_SRC]
        local clockEnabled = self.parameters[P_CLOCK] == 2
        local voiceMode    = self.parameters[P_VOICE_MODE]
        local randomVol    = self.parameters[P_RANDOM_VOL] == 2
        local voiceText    = (voiceMode == 1) and "Poly" or "RR"
        local isMidiInput = (inputSrc == INPUT_MIDI)

        -- Title with mode
        local modeText = (jfMode == JF_MODE_SYNTH) and "Synth" or "Standard"
        drawText(10, 20, string.format("JF Sender [%s]", modeText))

        -- Show run mode status
        if runMode then
            drawText(10, 36, string.format("Run: %+.1fV", self.parameters[P_RUN_V]))
        else
            drawText(10, 36, "Run: Off")
        end

        -- Show clock status
        local clockText = clockEnabled and "Clk ON" or "Clk OFF"
        drawText(80, 36, clockText)

        -- Input source display
        local inputText
        if isMidiInput then
            local midiCh = self.parameters[P_MIDI_CH]
            inputText = midiCh == 0 and "In: MIDI Omni" or string.format("In: MIDI Ch%d", midiCh)
        elseif inputSrc == INPUT_CV_GATE then
            inputText = "In: CV+Gate"
        else
            inputText = "In: CV+Slots"
        end
        drawText(10, 52, inputText)
        drawText(150, 52, string.format("Mode: %s", voiceText))

        if isMidiInput then
            drawText(10, 68, string.format("Voice: %d", currentVoiceIndex))
        else
            drawText(10, 68, string.format("CV: %+.2fV", currentCV))

            if clockEnabled or inputSrc == INPUT_CV_SLOTS then
                drawText(10, 82, string.format("Slot: %d  Voice: %d", currentSlotIndex, currentVoiceIndex))
            else
                drawText(10, 82, string.format("Voice: %d", currentVoiceIndex))
            end
        end

        local volText
        if randomVol then
            volText = string.format("Rnd %.1f-%.1fV", self.parameters[P_VOL_MIN], self.parameters[P_VOL_MAX])
        else
            volText = string.format("%.1fV", self.parameters[P_LEVEL])
        end
        drawText(10, 96, string.format("Level: %s", volText))

        if clockEnabled then
            drawText(10, 110, string.format("Rate: %dms", self.parameters[P_CLOCK_RATE]))
        end
    end
}
