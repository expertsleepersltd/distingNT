-- TODO: Add gain control
local granulator
local p_delay_mean, p_delay_spread
local p_size_mean, p_size_spread
local p_pitch_mean, p_pitch_spread
local p_lfo_speed, p_lfo_depth
local p_record, p_buffer_size
local p_dry_gain, p_gran_gain
local p_reverse, p_lfo_shape, p_grain_shape
local p_grain_limit

-- Modes as booleans: true = mean/speed, false = spread/depth
local delayMode = true   -- true: mean, false: spread
local sizeMode = true    -- true: mean, false: spread
local pitchMode = true   -- true: mean, false: spread
local lfoMode = true     -- true: speed, false: depth

local button1Held = false
local button2Held = false
local button3Held = false
local button4Held = false

local button2PartnerTriggered = false  -- set if Button 1 is pressed while Button 2 is held
local button3PartnerTriggered = false  -- set if Button 4 is pressed while Button 3 is held

return {
  name = 'Granulator UI script',
  author = 'Tsurba',
  description = 'UI mapping for Granulator with mean/spread on pots, Buffer/Record on left encoder, LFO Speed/Depth on right encoder, Dry/Gran gain toggle, Reverse and Shape controls on buttons.',
  
  init = function()
    granulator = findAlgorithm("Granulator")
    if granulator == nil then
      return "Could not find 'Granulator'"
    end

    p_delay_mean    = findParameter(granulator, "Delay mean")
    p_delay_spread  = findParameter(granulator, "Delay spread")
    p_size_mean     = findParameter(granulator, "Size mean")
    p_size_spread   = findParameter(granulator, "Size spread")
    p_pitch_mean    = findParameter(granulator, "Pitch mean")
    p_pitch_spread  = findParameter(granulator, "Pitch spread")
    p_lfo_speed     = findParameter(granulator, "LFO speed")
    p_lfo_depth     = findParameter(granulator, "LFO depth")
    p_lfo_shape     = findParameter(granulator, "LFO shape")
    p_record        = findParameter(granulator, "Record")
    p_buffer_size   = findParameter(granulator, "Buffer size")
    p_dry_gain      = findParameter(granulator, "Dry gain")
    p_gran_gain     = findParameter(granulator, "Granulator gain")
    p_reverse       = findParameter(granulator, "Reverse")
    p_grain_shape   = findParameter(granulator, "Shape")
    p_drone1_enable = findParameter(granulator, "Drone 1 enable")
    p_grain_limit   = findParameter(granulator, "Grain limit")
    
    if not (p_delay_mean and p_delay_spread and p_size_mean and p_size_spread 
       and p_pitch_mean and p_pitch_spread and p_lfo_speed and p_lfo_depth 
       and p_lfo_shape and p_record and p_buffer_size and p_dry_gain and p_gran_gain
       and p_reverse and p_grain_shape and p_grain_limit) then
      return "Could not find one or more Granulator parameters"
    end

    return true
  end,

  pot1Turn = function(value)
    if delayMode then
      setParameterNormalized(granulator, p_delay_mean, 1.0 - value)
    else
      setParameterNormalized(granulator, p_delay_spread, value)
    end
  end,
  pot1Push = function()
    delayMode = not delayMode
  end,

  pot2Turn = function(value)
    if button2Held then
      local grainLimit = getParameter(granulator, p_grain_limit)
      setParameterNormalized(granulator, p_grain_limit, value)
      button2PartnerTriggered = true
    else
      if sizeMode then
        setParameterNormalized(granulator, p_size_mean, value)
      else
        setParameterNormalized(granulator, p_size_spread, value)
      end
    end
  end,
  pot2Push = function()
    sizeMode = not sizeMode
  end,

  pot3Turn = function(value)
    if pitchMode then
      setParameterNormalized(granulator, p_pitch_mean, value)
    else
      setParameterNormalized(granulator, p_pitch_spread, value)
    end
  end,
  pot3Push = function()
    pitchMode = not pitchMode
  end,

  encoder1Push = function()
    if getParameter(granulator, p_record) == 0 then
      setParameter(granulator, p_record, 1)
    else
      setParameter(granulator, p_record, 0)
    end
  end,
  encoder1Turn = function(whichWay)
    local step = 50.0
    local current = getParameter(granulator, p_buffer_size)
    local newVal = current + whichWay * step
    setParameter(granulator, p_buffer_size, newVal)
  end,

  encoder2Push = function()
    lfoMode = not lfoMode
  end,
  encoder2Turn = function(whichWay)
    local step = 5
    if lfoMode then
      local current = getParameter(granulator, p_lfo_speed)
      local newVal = current + whichWay * step
      setParameter(granulator, p_lfo_speed, newVal)
    else
      local current = getParameter(granulator, p_lfo_depth)
      local newVal = current + whichWay * step
      setParameter(granulator, p_lfo_depth, newVal)
    end
  end,

  -- Button 1: On push, if Button 2 is held then toggle Drone 1 enable and flag partner;
  -- otherwise, toggle Dry gain.
  button1Push = function()
    button1Held = true
    if button2Held then
      local drone = getParameter(granulator, p_drone1_enable)
      setParameter(granulator, p_drone1_enable, (drone < 0.5) and 1 or 0)
      button2PartnerTriggered = true
    else
      local dry = getParameter(granulator, p_dry_gain)
      setParameter(granulator, p_dry_gain, (dry >= 0) and -40 or 0)
    end
  end,
  button1Release = function()
    button1Held = false
  end,

  -- Button 2: On push, simply record that Button 2 is held.
  -- On release, if no Button 1 press occurred during its hold period then toggle Granulator gain;
  -- otherwise do nothing.
  button2Push = function()
    button2Held = true
  end,
  button2Release = function()
    if not button2PartnerTriggered then
      local granGain = getParameter(granulator, p_gran_gain)
      setParameter(granulator, p_gran_gain, (granGain >= 0) and -40 or 0)
    end
    button2Held = false
    button2PartnerTriggered = false
  end,

  -- Button 3: On push, record that Button 3 is held.
  -- On release, if no Button 4 press occurred during its hold period then advance Reverse by 25% steps;
  -- otherwise do nothing.
  button3Push = function()
    button3Held = true
  end,
  button3Release = function()
    if not button3PartnerTriggered then
      local rev = getParameter(granulator, p_reverse)
      local newVal = (rev + 25) % 125
      setParameter(granulator, p_reverse, newVal)
    end
    button3Held = false
    button3PartnerTriggered = false
  end,

  -- Button 4: On push, record that Button 4 is held.
  -- If Button 3 is held then cycle the Grain shape (parameter "Shape") and flag Button 3 partner;
  -- otherwise, cycle the LFO shape (parameter "LFO shape").
  button4Push = function()
    button4Held = true
    if button3Held then
      local current = getParameter(granulator, p_grain_shape)
      local newVal = current + 1
      if newVal >= 6 then newVal = 0 end
      setParameter(granulator, p_grain_shape, newVal)
      button3PartnerTriggered = true
    else
      local current = getParameter(granulator, p_lfo_shape)
      local newVal = current + 1
      if newVal >= 3 then newVal = 0 end
      setParameter(granulator, p_lfo_shape, newVal)
    end
  end,
  button4Release = function()
    button4Held = false
  end,

  draw = function()
    drawStandardParameterLine()
    drawAlgorithmUI(granulator)
    
    local delayStr = (delayMode and "Mean  " or "Spread")
    local sizeStr  = (sizeMode  and "Mean  " or "Spread")
    local pitchStr = (pitchMode and "Mean  " or "Spread")
    local lfoStr   = (lfoMode   and "Speed " or "Depth ")
    local modeStr = "Delay:" .. delayStr .. " | Size:" .. sizeStr .. " | Pitch:" .. pitchStr .. " | LFO:" .. lfoStr
    drawTinyText(10, 56, modeStr)
    
    local dM = math.floor(getParameter(granulator, p_delay_mean))
    local dS = math.floor(getParameter(granulator, p_delay_spread))
    local sM = math.floor(getParameter(granulator, p_size_mean))
    local sS = math.floor(getParameter(granulator, p_size_spread))
    local pM = math.floor(getParameter(granulator, p_pitch_mean))
    local pS = math.floor(getParameter(granulator, p_pitch_spread))
    local lSpeed = string.format("%.2f", getParameter(granulator, p_lfo_speed) / 255.00)
    local lDepth = math.floor(getParameter(granulator, p_lfo_depth))
    local valueStr = "M:" .. dM .. "% S:" .. dS .. "%     M:" .. sM .. "% S:" .. sS .. "%   M:" .. pM .. "st S:" .. pS .. "ct   Spd:" .. lSpeed .. "% D:" .. lDepth .. "%"
    drawTinyText(10, 64, valueStr)
  end,
}
