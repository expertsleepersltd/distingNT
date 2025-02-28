-- Looper Takeover
--[[
 Looper Takeover (Quantum Recording + Fade to Clear, No "Play" Param)

 1) "Arm" trigger => schedule recording at next bar boundary.
 2) Record for the entire quantum (Bars*4 beats), stopping ~1ms before
    the next boundary.
 3) "Stop" trigger => if not recording, fade clear by setting
    "Fade to clear"=1 for 0.1s, then 0.
 4) No references to "Play" param or play-off timers.
 5) Starts with cue=false => 0V output at startup.
]]
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
]]
-- Constants
local END_DELAY_TIME  = 0.0005 -- stop recording ~1ms before boundary
local FADE_CLEAR_TIME = 0.1    -- duration (s) to hold "Fade to clear"=1

--------------------------------------------------------------------------------
-- Find Looper + parameters
--------------------------------------------------------------------------------
local looper          = findAlgorithm("Looper")
if not looper then
  error("Looper algorithm not found.")
  return {}
end

local recordParam = findParameter(looper, "Record")
if not recordParam then
  error("Record param not found.")
  return {}
end

-- We use "Fade to clear" to clear the loop
local fadeParam = findParameter(looper, "Fade to clear")
if not fadeParam then
  error("'Fade to clear' param not found.")
  return {}
end

--------------------------------------------------------------------------------
-- Script State
--------------------------------------------------------------------------------
local NOOP              = {}    -- empty table to return if no updates
local currentTime       = 0     -- accumulates dt in step()
local globalBeat        = 1     -- increments on rising clock edges
local pendingArm        = false -- set true by "Arm" trigger
local recording         = false
local cue               = false -- false => 0V gate at startup

local beatAccumulator   = 0     -- measure each beat's length
local beatDuration      = 0

-- Times for scheduled events (-1 => none)
local stopRecordingTime = -1
local fadeOffTime       = -1

-- Single output (cue gate)
local out               = { 0 }

--------------------------------------------------------------------------------
-- Helper: find local position within the quantum
--------------------------------------------------------------------------------
local function getLocalPos(bars)
  local quantumLength = bars * 4
  local pos = ((globalBeat - 1) % quantumLength) + 1
  return pos, quantumLength
end

--------------------------------------------------------------------------------
return {
  name    = "Looper Takeover",
  author  = "Thorinside",

  init    = function(self)
    return {
      -- Inputs: 1=Clock (Gate), 2=Reset, 3=Arm, 4=Stop
      inputs     = { kGate, kTrigger, kTrigger, kTrigger },
      outputs    = 1,
      parameters = {
        { "Bars", 1, 16, 4, kInteger }
      }
    }
  end,

  ------------------------------------------------------------------------------
  -- gate(): Handle clock pulses (Input 1)
  ------------------------------------------------------------------------------
  gate    = function(self, input, rising)
    if input == 1 and rising then
      -- Measure last beat length
      if beatAccumulator > 0 then
        beatDuration = beatAccumulator
      end
      beatAccumulator = 0
      globalBeat = globalBeat + 1

      -- Check if we are at a quantum boundary
      local pos, qLen = getLocalPos(self.parameters[1])

      -- If we are armed at pos=1 => start recording
      if pos == 1 and pendingArm and not recording then
        setParameter(looper, recordParam, 1)
        recording  = true
        pendingArm = false
        cue        = false
      end

      -- If we are recording and just hit the last beat => schedule stopping
      if recording and pos == qLen and beatDuration > 0 then
        local stopDelay = beatDuration - END_DELAY_TIME
        if stopDelay < 0 then stopDelay = 0 end
        stopRecordingTime = currentTime + stopDelay
      end
    end
  end,

  ------------------------------------------------------------------------------
  -- trigger(): 2=Reset, 3=Arm, 4=Stop
  ------------------------------------------------------------------------------
  trigger = function(self, input)
    if input == 2 then
      -- Reset
      pendingArm = false
      if recording then
        setParameter(looper, recordParam, 0)
      end
      recording         = false
      cue               = false
      stopRecordingTime = -1
    elseif input == 3 then
      -- Arm
      if not recording then
        pendingArm = true
      end
    elseif input == 4 then
      -- Stop => if not recording, fade clear
      if not recording then
        cue = false
        setParameter(looper, fadeParam, 1) -- begin fade
        fadeOffTime = currentTime + FADE_CLEAR_TIME
      end
    end
  end,

  ------------------------------------------------------------------------------
  -- step(): ~1000x/sec. dt= time since last step
  ------------------------------------------------------------------------------
  step    = function(self, dt, inputs)
    currentTime     = currentTime + dt
    beatAccumulator = beatAccumulator + dt
    local didUpdate = false

    -- 1) If time to stop recording
    if stopRecordingTime >= 0 and currentTime >= stopRecordingTime then
      setParameter(looper, recordParam, 0)
      recording         = false
      cue               = true -- Switch to cue=ON after finishing
      stopRecordingTime = -1
      didUpdate         = true
    end

    -- 2) If time to turn off the fade param
    if fadeOffTime >= 0 and currentTime >= fadeOffTime then
      setParameter(looper, fadeParam, 0)
      fadeOffTime = -1
      didUpdate   = true
      -- We do NOT re-enable cue here. That is up to you if you want it.
    end

    -- 3) Possibly update the gate output
    local newGate = cue and 10 or 0
    if newGate ~= out[1] then
      out[1]    = newGate
      didUpdate = true
    end

    -- 4) Return either an updated output or NOOP
    if didUpdate then
      return out
    else
      return NOOP
    end
  end,

  ------------------------------------------------------------------------------
  -- draw(): Minimal status
  ------------------------------------------------------------------------------
  draw    = function(self)
    local pos, qLen = getLocalPos(self.parameters[1])
    local localBar  = math.floor((pos - 1) / 4) + 1
    local localBeat = ((pos - 1) % 4) + 1
    local y         = 25
    drawText(5, y, "Looper + FadeClear (No Play)")
    y = y + 10
    local status
    if recording then
      status = "Recording"
    elseif pendingArm then
      status = "Armed"
    elseif cue then
      status = "Cue(Playback)"
    else
      status = "Stopped"
    end
    drawText(5, y, "Status: " .. status)
    y = y + 10
    drawText(5, y, ("Bar %d Beat %d / %d"):format(localBar, localBeat, qLen))
  end
}
