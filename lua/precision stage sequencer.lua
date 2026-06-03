-- Precision Stage Sequencer
-- 3-lane, 8-stage precision CV programmer for Disting NT
-- Inputs:  In1 = Clock, In2 = Reset
-- Outputs: Out1 = Lane 1, Out2 = Lane 2, Out3 = Lane 3
--
-- Each lane/stage value is a direct voltage parameter:
--   0.00V to 10.00V, displayed/scaled using kVolts + kBy100.

local NUM_STAGES = 8
local NUM_LANES = 3

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

local function param_index(lane, stage)
  -- Parameters:
  -- 1 = Steps
  -- 2 = Stage
  -- 3..10  = Lane 1 Stage 1..8
  -- 11..18 = Lane 2 Stage 1..8
  -- 19..26 = Lane 3 Stage 1..8
  return 2 + ((lane - 1) * NUM_STAGES) + stage
end

return {
  name   = 'Precision Stage Sequencer',
  author = 'Nick Yablon + GPT-5',

  init = function(self)
    self.stage = 1

    local params = {
      {'Steps', 1, NUM_STAGES, NUM_STAGES, kInt},
      {'Stage', 1, NUM_STAGES, 1, kInt},
    }

    for lane = 1, NUM_LANES do
      for stage = 1, NUM_STAGES do
        table.insert(params, {
          'Lane ' .. lane .. ' Stage ' .. stage,
          0, 1000, 0, kVolts, kBy100
        })
      end
    end

    return {
      inputs      = { kGate, kGate },
      inputNames  = { 'Clock', 'Reset' },

      outputs     = { kStepped, kStepped, kStepped },
      outputNames = { 'Lane 1', 'Lane 2', 'Lane 3' },

      parameters  = params
    }
  end,

  _steps = function(self)
    return clamp(self.parameters[1] or NUM_STAGES, 1, NUM_STAGES)
  end,

  _set_stage = function(self, s)
    local steps = self:_steps()
    self.stage = clamp(s, 1, steps)
    self.parameters[2] = self.stage
  end,

  _outputs = function(self)
    local s = clamp(self.stage or 1, 1, NUM_STAGES)

    return {
      clamp(self.parameters[param_index(1, s)] or 0.0, 0.0, 10.0),
      clamp(self.parameters[param_index(2, s)] or 0.0, 0.0, 10.0),
      clamp(self.parameters[param_index(3, s)] or 0.0, 0.0, 10.0)
    }
  end,

  step = function(self, dt, inputs)
    -- Front-panel Stage parameter acts as manual stage select.
    local selected_stage = self.parameters[2] or self.stage or 1

    if selected_stage ~= self.stage then
      self:_set_stage(selected_stage)
    end

    if (self.stage or 1) > self:_steps() then
      self:_set_stage(self:_steps())
    end

    return self:_outputs()
  end,

  gate = function(self, input, rising)
    if not rising then return end

    if input == 1 then
      local s = (self.stage or 1) + 1
      if s > self:_steps() then s = 1 end
      self:_set_stage(s)

    elseif input == 2 then
      self:_set_stage(1)
    end
  end,

  draw = function(self)
    local s = self.stage or 1
    local steps = self:_steps()
    local outs = self:_outputs()

    drawText(2, 0,  'Precision Stage Sequencer')
    drawText(2, 14, 'Stage ' .. s .. ' / ' .. steps)
    drawText(2, 30, string.format('L1 %.2fV  L2 %.2fV', outs[1], outs[2]))
    drawText(2, 46, string.format('L3 %.2fV', outs[3]))
  end,
}
