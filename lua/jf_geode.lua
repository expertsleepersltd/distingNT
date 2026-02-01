-- Just Friends Geode Mode
-- Rhythmic envelope generator with per-voice control
-- Supports Standard and Geode modes

-- JF i2c address
local JF_ADDR = 0x70

-- JF ii commands
local JF_TRIGGER    = 1
local JF_RUN_MODE   = 2
local JF_RUN        = 3
local JF_MODE       = 6
local JF_TICK       = 7
local JF_PLAY_VOICE = 8
local JF_PLAY_NOTE  = 9
local JF_QUANTIZE   = 12

-- Mode constants
local MODE_STANDARD = 0
local MODE_GEODE    = 1

-- Parameter values
local JF_MODE_STANDARD = 1
local JF_MODE_GEODE    = 2

-- Input source constants
local INPUT_CV_GATE  = 1
local INPUT_MIDI     = 2
local INPUT_CLOCK    = 3

-- Trigger mode constants
local TRIG_ALL    = 1
local TRIG_CYCLE  = 2
local TRIG_RANDOM = 3
local TRIG_POLY   = 4

----------------------------------------------------------------
-- Parameter indices
----------------------------------------------------------------
local P_JF_MODE      = 1
local P_INPUT_SRC    = 2
local P_MIDI_CH      = 3
local P_BPM          = 4
local P_QUANTIZE     = 5
local P_CLOCK_RATE   = 6
local P_V1_DIV       = 7
local P_V1_REP       = 8
local P_V2_DIV       = 9
local P_V2_REP       = 10
local P_V3_DIV       = 11
local P_V3_REP       = 12
local P_V4_DIV       = 13
local P_V4_REP       = 14
local P_V5_DIV       = 15
local P_V5_REP       = 16
local P_V6_DIV       = 17
local P_V6_REP       = 18
local P_TRIG_MODE    = 19
local P_RUN_MODE     = 20
local P_RUN_V        = 21
local P_JF_ADDR      = 22

----------------------------------------------------------------
-- Crow-accurate s16V conversion
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
    if i < 0 then i = i + 65536 end
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
-- Set JF mode
----------------------------------------------------------------
local function setMode(mode)
    sendI2CCommand(JF_ADDR, JF_MODE, toUnsigned8(mode))
end

----------------------------------------------------------------
-- Set tempo (49-255 BPM) or tap tempo (1-48)
----------------------------------------------------------------
local function setTick(value)
    sendI2CCommand(JF_ADDR, JF_TICK, toUnsigned8(value))
end

----------------------------------------------------------------
-- Set quantization (1-32 divisions, 0 = off)
----------------------------------------------------------------
local function setQuantize(divisions)
    sendI2CCommand(JF_ADDR, JF_QUANTIZE, toUnsigned8(divisions))
end

----------------------------------------------------------------
-- Set run mode
----------------------------------------------------------------
local function setRunMode(enabled)
    local mode = enabled and 1 or 0
    sendI2CCommand(JF_ADDR, JF_RUN_MODE, toUnsigned8(mode))
end

----------------------------------------------------------------
-- Set run voltage
----------------------------------------------------------------
local function setRunVoltage(volts)
    local hi, lo = pack_s16V_bytes(volts)
    sendI2CCommand(JF_ADDR, JF_RUN, hi, lo)
end

----------------------------------------------------------------
-- Play voice (JF.VOX) - channel specific rhythm
-- channel: 1-6 (0 = all)
-- divs: rhythmic division (as voltage)
-- repeats: number of repeats (as voltage, -1 = infinite)
----------------------------------------------------------------
local function playVoice(channel, divs, repeats)
    channel = math.max(0, math.min(6, channel))
    local d_hi, d_lo = pack_s16V_bytes(divs)
    local r_hi, r_lo = pack_s16V_bytes(repeats)
    sendI2CCommand(JF_ADDR, JF_PLAY_VOICE, toUnsigned8(channel), d_hi, d_lo, r_hi, r_lo)
end

----------------------------------------------------------------
-- Play note (JF.NOTE) - polyphonic allocation
----------------------------------------------------------------
local function playNote(divs, repeats)
    local d_hi, d_lo = pack_s16V_bytes(divs)
    local r_hi, r_lo = pack_s16V_bytes(repeats)
    sendI2CCommand(JF_ADDR, JF_PLAY_NOTE, d_hi, d_lo, r_hi, r_lo)
end

----------------------------------------------------------------
-- Send trigger (for Standard mode)
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
local clockTimer = 0
local randomSeed = 23456
local currentVoiceIndex = 1
local initDone = false
local lastParams = {}

-- Simple random number generator
local function random(min, max)
    randomSeed = (randomSeed * 1103515245 + 12345) & 0x7FFFFFFF
    local rand = (randomSeed >> 16) & 0x7FFF
    return min + (rand % (max - min + 1))
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

-- Get division value for a voice (parameter value to voltage)
local function getVoiceDiv(params, voice)
    local paramIndex = P_V1_DIV + (voice - 1) * 2
    return params[paramIndex]
end

-- Get repeat value for a voice (parameter value, 17 = infinite = -1)
local function getVoiceRep(params, voice)
    local paramIndex = P_V1_REP + (voice - 1) * 2
    local rep = params[paramIndex]
    if rep == 17 then return -1 end  -- Infinite
    return rep
end

-- Quantize options mapping (index to division value)
local quantizeValues = {0, 2, 4, 8, 16, 32}

----------------------------------------------------------------
-- Trigger a voice based on current settings
----------------------------------------------------------------
local function triggerVoice(params, voice, isGeode)
    local divs = getVoiceDiv(params, voice)
    local reps = getVoiceRep(params, voice)

    if isGeode then
        playVoice(voice, divs, reps)
    else
        sendTrigger(voice, true)
    end
end

----------------------------------------------------------------
-- Trigger based on mode
----------------------------------------------------------------
local function triggerByMode(params, trigMode, isGeode)
    if trigMode == TRIG_ALL then
        -- Trigger all voices with their individual settings
        if isGeode then
            for i = 1, 6 do
                local divs = getVoiceDiv(params, i)
                local reps = getVoiceRep(params, i)
                playVoice(i, divs, reps)
            end
        else
            for i = 1, 6 do
                sendTrigger(i, true)
            end
        end
    elseif trigMode == TRIG_CYCLE then
        triggerVoice(params, currentVoiceIndex, isGeode)
        currentVoiceIndex = currentVoiceIndex + 1
        if currentVoiceIndex > 6 then currentVoiceIndex = 1 end
    elseif trigMode == TRIG_RANDOM then
        local voice = random(1, 6)
        triggerVoice(params, voice, isGeode)
    elseif trigMode == TRIG_POLY then
        if isGeode then
            -- Use voice 1's settings for poly mode
            local divs = getVoiceDiv(params, 1)
            local reps = getVoiceRep(params, 1)
            playNote(divs, reps)
        else
            sendTrigger(currentVoiceIndex, true)
            currentVoiceIndex = currentVoiceIndex + 1
            if currentVoiceIndex > 6 then currentVoiceIndex = 1 end
        end
    end
end

----------------------------------------------------------------
-- Main object
----------------------------------------------------------------
return {
    name   = "JF Geode",
    author = "Mark IJzerman",

    init = function(self)
        initDone = false
        clockTimer = 0
        lastParams = {}
        currentVoiceIndex = 1

        return {
            inputs  = {kGate},
            outputs = {},

            inputNames  = {"Gate/Trig"},
            outputNames = {},

            parameters = {
                -- Mode & Input (1-3)
                {"JF Mode", {"Standard", "Geode"}, 2, kEnum},
                {"Input Source", {"CV+Gate", "MIDI", "Int Clock"}, 1, kEnum},
                {"MIDI Channel", 0, 16, 0, kInteger},

                -- Timing (4-6)
                {"BPM", 49, 255, 120, kInteger},
                {"Quantize", {"Off", "/2", "/4", "/8", "/16", "/32"}, 1, kEnum},
                {"Clock Rate (ms)", 10, 2000, 500, kInteger},

                -- Voice 1 (7-8)
                {"V1 Divs", 1, 16, 2, kInteger},
                {"V1 Reps", 1, 17, 4, kInteger},  -- 17 = Infinite

                -- Voice 2 (9-10)
                {"V2 Divs", 1, 16, 3, kInteger},
                {"V2 Reps", 1, 17, 4, kInteger},

                -- Voice 3 (11-12)
                {"V3 Divs", 1, 16, 4, kInteger},
                {"V3 Reps", 1, 17, 2, kInteger},

                -- Voice 4 (13-14)
                {"V4 Divs", 1, 16, 6, kInteger},
                {"V4 Reps", 1, 17, 3, kInteger},

                -- Voice 5 (15-16)
                {"V5 Divs", 1, 16, 8, kInteger},
                {"V5 Reps", 1, 17, 2, kInteger},

                -- Voice 6 (17-18)
                {"V6 Divs", 1, 16, 12, kInteger},
                {"V6 Reps", 1, 17, 1, kInteger},

                -- Trigger Mode (19)
                {"Trigger Mode", {"All", "Cycle", "Random", "Poly"}, 2, kEnum},

                -- Run Control (20-21)
                {"Run Mode", {"Off", "On"}, 1, kEnum},
                {"Run V", -5, 5, 0, kVolts},

                -- System (22)
                {"JF Address", {"0x70", "0x75"}, 1, kEnum}
            },
            midi = { channelParameter = P_MIDI_CH, messages = { "note" } }
        }
    end,

    ----------------------------------------------------------------
    -- Continuous processing
    ----------------------------------------------------------------
    step = function(self, dt, inputs)
        -- Update address
        JF_ADDR = (self.parameters[P_JF_ADDR] == 1) and 0x70 or 0x75

        local jfMode = self.parameters[P_JF_MODE]
        local inputSrc = self.parameters[P_INPUT_SRC]
        local bpm = self.parameters[P_BPM]
        local quantize = self.parameters[P_QUANTIZE]
        local clockRate = self.parameters[P_CLOCK_RATE] / 1000.0
        local trigMode = self.parameters[P_TRIG_MODE]
        local runMode = self.parameters[P_RUN_MODE] == 2
        local runV = self.parameters[P_RUN_V]

        local isGeode = (jfMode == JF_MODE_GEODE)
        local isMidiInput = (inputSrc == INPUT_MIDI)
        local isClockInput = (inputSrc == INPUT_CLOCK)

        -- Initialize on first frame
        if not initDone then
            local modeVal = isGeode and MODE_GEODE or MODE_STANDARD
            setMode(modeVal)
            setTick(bpm)
            setQuantize(quantizeValues[quantize])
            setRunMode(runMode)
            if runMode then
                setRunVoltage(runV)
            end
            initDone = true
        end

        -- Update mode when changed
        if paramChanged(self.parameters, P_JF_MODE, 0) then
            local modeVal = isGeode and MODE_GEODE or MODE_STANDARD
            setMode(modeVal)
            lastParams[P_JF_MODE] = self.parameters[P_JF_MODE]
        end

        -- Update BPM when changed
        if paramChanged(self.parameters, P_BPM, 0) then
            setTick(bpm)
            lastParams[P_BPM] = bpm
        end

        -- Update quantize when changed
        if paramChanged(self.parameters, P_QUANTIZE, 0) then
            setQuantize(quantizeValues[quantize])
            lastParams[P_QUANTIZE] = quantize
        end

        -- Update run mode when changed
        if paramChanged(self.parameters, P_RUN_MODE, 0) then
            setRunMode(runMode)
            lastParams[P_RUN_MODE] = self.parameters[P_RUN_MODE]
            if runMode then
                setRunVoltage(runV)
                lastParams[P_RUN_V] = runV
            end
        end

        -- Update run voltage when changed
        if runMode and paramChanged(self.parameters, P_RUN_V) then
            setRunVoltage(runV)
            lastParams[P_RUN_V] = runV
        end

        -- Process input based on source
        if not isMidiInput then
            if isClockInput then
                -- Internal clock mode
                clockTimer = clockTimer + dt
                if clockTimer >= clockRate then
                    clockTimer = 0
                    triggerByMode(self.parameters, trigMode, isGeode)
                end
            else
                -- CV+Gate mode
                local gate = inputs[1] > 2.5
                if gate and not lastGate then
                    triggerByMode(self.parameters, trigMode, isGeode)
                end
                lastGate = gate
            end
        end

        return {}
    end,

    ----------------------------------------------------------------
    -- MIDI input handling
    ----------------------------------------------------------------
    midiMessage = function(self, message)
        local inputSrc = self.parameters[P_INPUT_SRC]
        if inputSrc ~= INPUT_MIDI then return end

        local status = message[1] & 0xF0
        local velocity = message[3]

        local jfMode = self.parameters[P_JF_MODE]
        local trigMode = self.parameters[P_TRIG_MODE]
        local isGeode = (jfMode == JF_MODE_GEODE)

        if status == 0x90 and velocity > 0 then
            triggerByMode(self.parameters, trigMode, isGeode)
        end
    end,

    ----------------------------------------------------------------
    -- UI drawing
    ----------------------------------------------------------------
    draw = function(self)
        local jfMode = self.parameters[P_JF_MODE]
        local inputSrc = self.parameters[P_INPUT_SRC]
        local bpm = self.parameters[P_BPM]
        local quantize = self.parameters[P_QUANTIZE]
        local trigMode = self.parameters[P_TRIG_MODE]
        local runMode = self.parameters[P_RUN_MODE] == 2
        local runV = self.parameters[P_RUN_V]

        local isGeode = (jfMode == JF_MODE_GEODE)
        local modeText = isGeode and "Geode" or "Standard"

        -- Title line
        local qtText = quantize == 1 and "Off" or string.format("/%d", quantizeValues[quantize])
        drawText(10, 16, string.format("JF Geode [%s]", modeText))
        drawText(160, 16, string.format("BPM:%d QT:%s", bpm, qtText))

        -- Input source and trigger mode
        local inputText
        if inputSrc == INPUT_MIDI then
            local midiCh = self.parameters[P_MIDI_CH]
            inputText = midiCh == 0 and "MIDI Omni" or string.format("MIDI Ch%d", midiCh)
        elseif inputSrc == INPUT_CLOCK then
            inputText = string.format("Clock %dms", self.parameters[P_CLOCK_RATE])
        else
            inputText = "CV+Gate"
        end

        local trigText = ({"All", "Cycle", "Random", "Poly"})[trigMode]
        drawText(10, 32, string.format("In: %s", inputText))
        drawText(160, 32, string.format("Trig: %s", trigText))

        -- Voice settings (2 rows of 3)
        local function repText(v)
            local rep = self.parameters[P_V1_REP + (v - 1) * 2]
            return rep == 17 and "Inf" or tostring(rep)
        end

        drawText(10, 48, string.format("V1:%d/%s", self.parameters[P_V1_DIV], repText(1)))
        drawText(90, 48, string.format("V2:%d/%s", self.parameters[P_V2_DIV], repText(2)))
        drawText(170, 48, string.format("V3:%d/%s", self.parameters[P_V3_DIV], repText(3)))

        drawText(10, 64, string.format("V4:%d/%s", self.parameters[P_V4_DIV], repText(4)))
        drawText(90, 64, string.format("V5:%d/%s", self.parameters[P_V5_DIV], repText(5)))
        drawText(170, 64, string.format("V6:%d/%s", self.parameters[P_V6_DIV], repText(6)))

        -- Run status and current voice
        local runText = runMode and string.format("Run: %+.1fV", runV) or "Run: Off"
        drawText(10, 80, runText)

        if trigMode == TRIG_CYCLE then
            drawText(120, 80, string.format("Next: V%d", currentVoiceIndex))
        end

        -- Address
        drawText(200, 80, string.format("0x%02X", JF_ADDR))
    end
}
