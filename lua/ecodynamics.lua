-- Ecodynamics (Generator)
--[[
Probabilistic sequencer with ecological dynamics modeling erosion and regrowth.
]]
-- Copyright (c) 2025 Nick Yablon
-- Inputs:  In1 = Clock, In2 = Gate In, In3 = Pitch In
-- Outputs: Out1 = Pitch (V/oct), Out2 = Gate, Out3 = Avg p (0..5V)

local LN2  = math.log(2)

local function clamp(x, lo, hi)
  if x < lo then return lo end
  if x > hi then return hi end
  return x
end

-- Quantizer scales (semitone degrees relative to root)
local SCALES = {
  [1]  = {0,2,4,5,7,9,11},        -- Major (Ionian)
  [2]  = {0,2,3,5,7,8,10},        -- Natural Minor (Aeolian)
  [3]  = {0,2,3,5,7,9,10},        -- Dorian
  [4]  = {0,1,3,5,7,8,10},        -- Phrygian
  [5]  = {0,2,4,6,7,9,11},        -- Lydian
  [6]  = {0,2,4,5,7,9,10},        -- Mixolydian
  [7]  = {0,1,3,5,6,8,10},        -- Locrian
  [8]  = {0,2,3,5,7,8,11},        -- Harmonic Minor
  [9]  = {0,2,3,5,7,9,11},        -- Melodic Minor (ascending)
  [10] = {0,2,4,7,9},             -- Major Pentatonic
  [11] = {0,3,5,7,10},            -- Minor Pentatonic
  [12] = {0,1,2,3,4,5,6,7,8,9,10,11}, -- Chromatic
}

local function build_motif(len, scale_idx, range_oct)
  local scale = SCALES[scale_idx] or SCALES[1]
  local sc_n = #scale
  local range = range_oct or 2
  if range < 1 then range = 1 end
  if range > 5 then range = 5 end
  
  local m = {}
  for i = 1, len do
    local ix = math.random(1, sc_n)  -- Lua arrays are 1-indexed!
    local octave = math.random(0, range - 1)  -- Random octave within range
    m[i] = scale[ix] + (octave * 12)  -- Add octave offset
  end
  return m
end

return {
  name   = 'Ecodynamics (Generator)',
  author = 'Electrum Modular',

  init = function(self)
    self.pos      = 1
    self.pitch_v  = 0.0
    self.pitch_in_v = 0.0  -- Initialize pitch input cache
    self.gate_t   = 0.0
    self.avg_v    = 0.0

    -- Clock period estimate
    self.time_s         = 0.0
    self.last_clk_t     = nil
    self.step_period_s  = 0.5
    
    -- Gate delay buffer for note masking mode
    self.pending_gate = nil
    self.gate_delay_t = 0.0

    -- Probabilities
    self.p = {}
    for i = 1, 32 do self.p[i] = 0.85 end

    -- Motif state (motif_len will track Length)
    self.motif_len = 16
    self.root = 0
    self.scale_idx = 1
    self.range_v = 2
    self.motif = build_motif(self.motif_len, self.scale_idx, self.range_v)
    self.motif_range = 2  -- Track what range the motif was generated with

    return {
      inputs      = { kGate, kGate, kLinear },
      inputNames  = { 'Clock', 'Gate In', 'Pitch In' },

      outputs     = { kLinear, kLinear, kLinear },
      outputNames = { 'Pitch Out', 'Gate Out', 'Avg p' },

      parameters  = {
        {'MODE: Operation', {'Generator','Note masking'}, 1},
        {'MODE: Mask target', {'Step','Pitch cls','Interval cls'}, 1},

        -- ECO group
        {'ECO: Preset', {'Off','Forest','Glacier','Ice cap','Grassland','Tidal marsh','Coral reef','Mangrove','Predator','Pollinator'}, 1},
        {'ECO: Length', 4, 32, 16, kInt},
        {'ECO: Erosion', 0, 50, 25, kPercent},
        {'ECO: Regrow t1/2 (s)', 0, 60, 8, kSeconds},  -- 60 = INF
        {'ECO: Floor', 0, 80, 10, kPercent},
        {'ECO: Ceiling', 20, 100, 95, kPercent},
        {'ECO: Density offset', -40, 40, 0, kPercent},
        {'ECO: Erosion mode', {'Geometric','Arithmetic'}, 1},
        {'ECO: Stability traj', -100, 100, 0, kPercent},     -- signed
        {'ECO: Bounce-back', 0, 100, 10, kPercent},
        {'ECO: Bounce curve', {'Linear','Soft','Steep'}, 1},
        {'ECO: Erosion coupling', 0, 100, 0, kPercent},
        {'ECO: Regrow coupling', 0, 100, 0, kPercent},
        {'ECO: Restore (btn)', 0, 1, 0, kInt},

        -- GEN group
        {'GEN: Root', {'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'}, 1},
        {'GEN: Scale', {'Major','Minor','Dorian','Phrygian','Lydian','Mixolydian','Locrian','Harmonic Min','Melodic Min','Maj Pent','Min Pent','Chromatic'}, 1},
        {'GEN: Range', 1, 5, 2, kInt},  -- octaves
        {'GEN: Transpose', -12, 12, 0, kSemitones},  -- ±1 octave in semitones
        {'GEN: Reseed (btn)', 0, 1, 0, kInt},

        -- GATE group
        {'GATE: length', 1, 100, 10, kPercent},
        {'GATE: Dynamics', {'Off','p-scaled'}, 1},
      }
    }
  end,

  _do_restore = function(self, ceilP)
    local L = self._L or 16
    for i = 1, L do self.p[i] = ceilP end
  end,

  _reseed_motif = function(self)
    self.motif = build_motif(self.motif_len, self.scale_idx, self.range_v)
    self.motif_range = self.range_v  -- Remember what range this motif was generated with
  end,

  _apply_preset = function(self, idx)
    -- idx mapping: 1=Off, 2=Forest, 3=Glacier, 4=Ice cap,
    -- 5=Grassland, 6=Tidal marsh, 7=Coral reef, 8=Mangrove,
    -- 9=Predator, 10=Pollinator
    if idx == nil or idx <= 1 then
      return
    end

    -- Helper to set a script parameter (1-based index in parameters array)
    -- FIXED: Remove the -1 as per developer advice
    local function setScriptParam(param_idx, value)
      setParameter(self.algorithmIndex, self.parameterOffset + param_idx, value, false)
    end
    
    -- Parameter indices:
    -- p[4]=Length, p[5]=Erosion, p[6]=Regrow, p[7]=Floor, p[8]=Ceiling
    -- p[9]=Density, p[10]=Erosion mode (1-2), p[11]=Stability (-100 to 100)
    -- p[12]=Bounce-back, p[13]=Bounce curve (1-3), p[14]=Erosion coupling, p[15]=Regrow coupling

    if idx == 2 then
      -- Forest
      setScriptParam(4, 16); setScriptParam(5, 12); setScriptParam(6, 25); setScriptParam(7, 10); setScriptParam(8, 95)
      setScriptParam(9, 0); setScriptParam(10, 1); setScriptParam(11, 40)
      setScriptParam(12, 60); setScriptParam(13, 2); setScriptParam(14, 30); setScriptParam(15, 40)

    elseif idx == 3 then
      -- Glacier
      setScriptParam(4, 16); setScriptParam(5, 18); setScriptParam(6, 40); setScriptParam(7, 5); setScriptParam(8, 85)
      setScriptParam(9, 0); setScriptParam(10, 1); setScriptParam(11, -25)
      setScriptParam(12, 15); setScriptParam(13, 1); setScriptParam(14, 15); setScriptParam(15, 10)

    elseif idx == 4 then
      -- Ice cap
      setScriptParam(4, 16); setScriptParam(5, 25); setScriptParam(6, 50); setScriptParam(7, 0); setScriptParam(8, 80)
      setScriptParam(9, 0); setScriptParam(10, 1); setScriptParam(11, -70)
      setScriptParam(12, 5); setScriptParam(13, 3); setScriptParam(14, 25); setScriptParam(15, 5)

    elseif idx == 5 then
      -- Grassland
      setScriptParam(4, 16); setScriptParam(5, 20); setScriptParam(6, 20); setScriptParam(7, 5); setScriptParam(8, 90)
      setScriptParam(9, 0); setScriptParam(10, 1); setScriptParam(11, 0)
      setScriptParam(12, 40); setScriptParam(13, 2); setScriptParam(14, 60); setScriptParam(15, 40)

    elseif idx == 6 then
      -- Tidal marsh
      setScriptParam(4, 16); setScriptParam(5, 18); setScriptParam(6, 20); setScriptParam(7, 10); setScriptParam(8, 90)
      setScriptParam(9, 0); setScriptParam(10, 1); setScriptParam(11, 15)
      setScriptParam(12, 25); setScriptParam(13, 1); setScriptParam(14, 50); setScriptParam(15, 45)

    elseif idx == 7 then
      -- Coral reef
      setScriptParam(4, 16); setScriptParam(5, 22); setScriptParam(6, 15); setScriptParam(7, 10); setScriptParam(8, 95)
      setScriptParam(9, 0); setScriptParam(10, 1); setScriptParam(11, -15)
      setScriptParam(12, 55); setScriptParam(13, 2); setScriptParam(14, 35); setScriptParam(15, 50)

    elseif idx == 8 then
      -- Mangrove
      setScriptParam(4, 16); setScriptParam(5, 10); setScriptParam(6, 18); setScriptParam(7, 20); setScriptParam(8, 100)
      setScriptParam(9, 0); setScriptParam(10, 1); setScriptParam(11, 60)
      setScriptParam(12, 75); setScriptParam(13, 2); setScriptParam(14, 30); setScriptParam(15, 60)

    elseif idx == 9 then
      -- Predator
      setScriptParam(4, 16); setScriptParam(5, 18); setScriptParam(6, 10); setScriptParam(7, 10); setScriptParam(8, 90)
      setScriptParam(9, 0); setScriptParam(10, 1); setScriptParam(11, 0)
      setScriptParam(12, 70); setScriptParam(13, 3); setScriptParam(14, 40); setScriptParam(15, 40)

    elseif idx == 10 then
      -- Pollinator
      setScriptParam(4, 16); setScriptParam(5, 20); setScriptParam(6, 8); setScriptParam(7, 5); setScriptParam(8, 85)
      setScriptParam(9, 0); setScriptParam(10, 1); setScriptParam(11, -10)
      setScriptParam(12, 65); setScriptParam(13, 2); setScriptParam(14, 30); setScriptParam(15, 55)
    end
  end,

  step = function(self, dt, inputs)
    self.time_s = self.time_s + dt
    
    -- CRITICAL: Store inputs immediately for gate function access
    -- This ensures gate function gets the most current pitch value
    self._current_inputs = inputs
    
    -- cache Pitch In (input 3) for note masking mode
    if inputs then
      self.pitch_in_v = inputs[3] or self.pitch_in_v or 0.0
    end

        -- Read params
    local mode_idx     = (self.parameters[1] or 1)
    local mask_target  = (self.parameters[2] or 1)
    local preset_idx   = (self.parameters[3] or 1)

    -- ECO block (pre-preset)
    local L            = self.parameters[4]
    local eros         = self.parameters[5]
    local reg_s        = self.parameters[6]
    local floorP       = clamp(self.parameters[7] / 100.0, 0.0, 0.8)
    local ceilP        = clamp(self.parameters[8] / 100.0, 0.2, 1.0)
    local density_off  = clamp(self.parameters[9] / 100.0, -0.4, 0.4)
    local eros_mode    = (self.parameters[10] or 1)
    local st_signed    = clamp(self.parameters[11] or 0, -100, 100) / 100.0
    local bb_amt       = clamp(self.parameters[12] or 0, 0, 100) / 100.0
    local bb_curve     = (self.parameters[13] or 1)
    local eros_cpl     = clamp(self.parameters[14] or 0, 0, 100) / 100.0
    local reg_cpl      = clamp(self.parameters[15] or 0, 0, 100) / 100.0
    local restore_btn  = self.parameters[16]

    local root         = ((self.parameters[17] or 1) - 1) % 12
    local scale_idx    = (self.parameters[18] or 1)
    local range_oct    = self.parameters[19] or 2.0  -- in octaves
    local offset_semi  = self.parameters[20] or 0    -- in semitones
    local reseed_btn   = self.parameters[21] or 0

    local gate_pct     = clamp(self.parameters[22], 1, 100)
    local gate_dyn     = (self.parameters[23] or 1)

    -- Apply ECO preset (one-shot on change)
    if self._prev_preset ~= preset_idx then
      self:_apply_preset(preset_idx)
      self._prev_preset = preset_idx

      -- Re-read ECO block after preset application
      L            = self.parameters[4]
      eros         = self.parameters[5]
      reg_s        = self.parameters[6]
      floorP       = clamp(self.parameters[7] / 100.0, 0.0, 0.8)
      ceilP        = clamp(self.parameters[8] / 100.0, 0.2, 1.0)
      density_off  = clamp(self.parameters[9] / 100.0, -0.4, 0.4)
      eros_mode    = (self.parameters[10] or 1)
      st_signed    = clamp(self.parameters[11] or 0, -100, 100) / 100.0
      bb_amt       = clamp(self.parameters[12] or 0, 0, 100) / 100.0
      bb_curve     = (self.parameters[13] or 1)
      eros_cpl     = clamp(self.parameters[14] or 0, 0, 100) / 100.0
      reg_cpl      = clamp(self.parameters[15] or 0, 0, 100) / 100.0
      restore_btn  = self.parameters[16]
    end

    -- Enforce Length for certain mask targets on every step
    local mt = mask_target or 1
    if mt == 2 then
      -- Pitch-class masking: force Length = 12
      if L ~= 12 then
        L = 12
        setParameter(self.algorithmIndex, self.parameterOffset + 3, 12, false)
      end
    elseif mt == 3 then
      -- Interval-class masking: force Length = 7
      if L ~= 7 then
        L = 7
        setParameter(self.algorithmIndex, self.parameterOffset + 3, 7, false)
      end
    end

    -- Cache for gate/draw
    self._L, self._eros, self._reg_s = L, eros, reg_s
    self._floorP, self._ceilP, self._density_off = floorP, ceilP, density_off
    self._gate_pct = gate_pct
    self._gate_dyn = gate_dyn
    self._eros_cpl = eros_cpl
    self._reg_cpl  = reg_cpl
    self._eros_mode = eros_mode
    self._fb_s      = st_signed
    self._bb_amt    = bb_amt
    self._bb_curve  = bb_curve
    self._mode      = mode_idx - 1
    self._mask_target = (mask_target or 1) - 1
    self.root       = root
    self.range_v    = range_oct  -- Just store it, don't reseed on change
    self.offset_semi = offset_semi  -- transpose in semitones

    -- Keep motif length locked to Length
    if L ~= self.motif_len then
      self.motif_len = L
      self:_reseed_motif()
    end

    -- Scale change also reseeds motif (check BEFORE assignment)
    if not self.scale_idx or scale_idx ~= self.scale_idx then
      self.scale_idx = scale_idx
      self:_reseed_motif()
    end
    
    -- Range just updates - motif remapping happens in playback
    self.range_v = range_oct

    -- Reseed button - use parameterOffset, no UI focus change
    if reseed_btn ~= 0 then
      self:_reseed_motif()
      setParameter(self.algorithmIndex, self.parameterOffset + 20, 0, false)
    end

    -- Gate timer and pending gate handling
    -- Process any pending gate trigger from gate function
    if self.pending_gate_trigger then
      self.gate_t = self.pending_gate_trigger
      self.pending_gate_trigger = nil
      -- Apply the gate amplitude that was calculated when gate was triggered
      if self.pending_gate_amp then
        self._gate_amp = self.pending_gate_amp
        self.pending_gate_amp = nil
      end
    end
    
    -- Countdown existing gate
    if self.gate_t > 0 then
      self.gate_t = self.gate_t - dt
      if self.gate_t <= 0 then self.gate_t = 0 end
    end
    local gate_amp = self._gate_amp or 1.0
    -- Gate dynamics: 3V-8V range (standard for velocity-sensitive modules)
    local gate_v = (self.gate_t > 0) and (3.0 + gate_amp * 5.0) or 0.0
    
    -- Process delayed gate for note masking mode (3ms delay)
    if self.pending_gate then
      self.gate_delay_t = self.gate_delay_t - dt
      if self.gate_delay_t <= 0 then
        self:_process_note_mask_gate()
        self.pending_gate = nil
      end
    end

    -- Restore button (momentary) - use parameterOffset, no UI focus change
    if restore_btn and restore_btn ~= 0 then
      self:_do_restore(ceilP)
      setParameter(self.algorithmIndex, self.parameterOffset + 15, 0, false)
    end

    -- Average (pre-regrow) for feedback scaling
    local sum_pre = 0.0
    for i = 1, L do sum_pre = sum_pre + (self.p[i] or 0.0) end
    local avg_pre = sum_pre / L
    if avg_pre < 0 then avg_pre = 0 elseif avg_pre > 1 then avg_pre = 1 end

    -- Regrowth with bounce-back scaling
    if reg_s < 59.5 then
      local t_half_s = reg_s
      if t_half_s <= 0 then t_half_s = 0.01 end
      local k = LN2 / t_half_s

      local deficit = 1.0 - avg_pre
      if deficit < 0 then deficit = 0 elseif deficit > 1 then deficit = 1 end
      local g
      if (self._bb_curve or 1) == 1 then
        g = deficit
      elseif (self._bb_curve or 1) == 2 then
        g = math.sqrt(deficit)
      else
        g = deficit * deficit
      end
      local grow_scale = (1.0 - (self._bb_amt or 0)) + (self._bb_amt or 0) * g
      if grow_scale < 0.0 then grow_scale = 0.0 end
      if grow_scale > 2.0 then grow_scale = 2.0 end

      for i = 1, L do
        local pi = self.p[i]
        local ki = k * grow_scale
        local old_pi = pi
        pi = pi + (ceilP - pi) * ki * dt
        if pi < floorP then pi = floorP elseif pi > ceilP then pi = ceilP end
        self.p[i] = pi

        -- Regrow coupling: diffuse recovery to neighbors
        local delta_grow = pi - old_pi
        if (self._reg_cpl or 0) > 0 and delta_grow > 0 then
          local ninc = delta_grow * (self._reg_cpl or 0)
          local il = i - 1; if il < 1 then il = L end
          local ir = i + 1; if ir > L then ir = 1 end
          local pl = (self.p[il] or ceilP) + ninc
          if pl > ceilP then pl = ceilP end
          if pl < floorP then pl = floorP end
          self.p[il] = pl
          local pr = (self.p[ir] or ceilP) + ninc
          if pr > ceilP then pr = ceilP end
          if pr < floorP then pr = floorP end
          self.p[ir] = pr
        end
      end
    end

    -- Average probability (post-regrow)
    local sum = 0.0
    for i = 1, L do sum = sum + (self.p[i] or 0.0) end
    local avg = sum / L
    if avg < 0 then avg = 0 elseif avg > 1 then avg = 1 end
    self._avg_p = avg
    self.avg_v  = avg * 5.0

    return { self.pitch_v, gate_v, self.avg_v }
  end,

  _process_note_mask_gate = function(self)
    -- This is called after a 3ms delay to ensure pitch CV has been sampled
    local now = self.time_s or 0.0
    
    -- CRITICAL: Read pitch from most recent inputs
    local pitch_now = 0.0
    if self._current_inputs and self._current_inputs[3] then
      pitch_now = self._current_inputs[3]
    else
      pitch_now = self.pitch_in_v or 0.0
    end

    local L        = self._L or 16
    local erosP    = (self._eros or 12) / 100.0
    local floorP   = self._floorP or 0.1
    local ceilP    = self._ceilP or 1.0
    local density  = self._density_off or 0.0
    local gate_pct = self._gate_pct or 10
    local neigh_k  = self._eros_cpl or 0.0
    local gate_dyn = self._gate_dyn or 1
    local avg_p    = self._avg_p or 0.5
    local s        = self._fb_s or 0.0
    local mt       = self._mask_target or 0

    -- Stability trajectory scaling
    local fb_scale
    if s >= 0 then
      fb_scale = (1.0 - s) + s * avg_p
    else
      local d = -s
      fb_scale = (1.0 - d) + d * (1.0 - avg_p)
    end
    if fb_scale < 0.0 then fb_scale = 0.0 end
    if fb_scale > 2.0 then fb_scale = 2.0 end

    -- Determine which probability bin to use
    local i = 1

    if mt == 0 then
      i = self.pos or 1
      if i > L then i = 1 end

    elseif mt == 1 then
      local semi  = math.floor(pitch_now * 12 + 0.5)
      local pc    = semi % 12
      i = pc + 1
      if i < 1 then i = 1 end
      if i > L then i = ((i - 1) % L) + 1 end
      self.pos = i
      self._last_pc = pc

    elseif mt == 2 then
      local semi  = math.floor(pitch_now * 12 + 0.5)
      local pc    = semi % 12
      local last  = self._last_pc or pc
      local diff  = (pc - last) % 12
      if diff < 0 then diff = diff + 12 end
      local ic = diff
      if ic > 6 then ic = 12 - ic end
      if ic < 0 then ic = 0 end
      if ic > 6 then ic = 6 end
      i = ic + 1
      if i < 1 then i = 1 end
      if i > L then i = ((i - 1) % L) + 1 end
      self.pos    = i
      self._last_pc = pc
    end

    local pdraw = self.p[i] + density
    if pdraw < 0 then pdraw = 0 elseif pdraw > 1 then pdraw = 1 end

    if math.random() < pdraw then
      -- Gate dynamics
      local gate_amp = 1.0
      if gate_dyn ~= 1 then
        local spread = ceilP - floorP
        if spread < 0.0001 then
          gate_amp = 1.0
        else
          local norm = (self.p[i] - floorP) / spread
          if norm < 0 then norm = 0 elseif norm > 1 then norm = 1 end
          gate_amp = math.max(0.25, math.sqrt(norm) * 0.75 + 0.25)
        end
      end
      self._gate_amp = gate_amp

      -- Gate pulse out - schedule for next step cycle to avoid glitches
      local step_s   = self.step_period_s or 0.5
      if step_s < 0.02 then step_s = 0.02 end
      if step_s > 5.0  then step_s = 5.0  end
      local pulse_s  = step_s * gate_pct / 100.0
      if pulse_s < 0.001 then pulse_s = 0.001 end
      -- Only trigger new gate if previous gate has finished (prevents double-trigger)
      if self.gate_t <= 0 then
        self.pending_gate_trigger = pulse_s
      end

      -- Pitch Out: sample & quantize
      local semi  = math.floor(pitch_now * 12 + 0.5)
      local vq    = semi / 12.0
      self.pitch_v = vq

      -- Erode
      local oldp = self.p[i]
      local newp
      if (self._eros_mode or 1) == 1 then
        newp = oldp * (1.0 - erosP * fb_scale)
      else
        local ceilP_local   = self._ceilP or 1.0
        local floorP_local  = self._floorP or 0.0
        local e_abs = (erosP * fb_scale) * (ceilP_local - floorP_local)
        newp = oldp - e_abs
      end
      if newp < floorP then newp = floorP end
      self.p[i] = newp

      -- Erosion coupling
      local delta = oldp - newp
      local ndec  = delta * neigh_k
      if ndec > 0 then
        local il = i - 1; if il < 1 then il = L end
        local ir = i + 1; if ir > L then ir = 1 end
        local pl = self.p[il] - ndec
        if pl < floorP then pl = floorP end
        self.p[il] = pl
        local pr = self.p[ir] - ndec
        if pr < floorP then pr = floorP end
        self.p[ir] = pr
      end
    end

    -- Advance cursor for step mode only
    if mt == 0 then
      i = i + 1
      if i > L then i = 1 end
      self.pos = i
    end
  end,

  gate = function(self, input, rising)
  if not rising then return end

  local mode = self._mode or 0  -- 0 = Generator, 1 = Note masking

  --------------------------------------------------------------------
  -- GENERATOR MODE: respond to Clock (input 1), original behaviour
  --------------------------------------------------------------------
  if mode == 0 then
    if input ~= 1 then return end

    -- Clock period update
    local now = self.time_s or 0.0
    if self.last_clk_t then
      local meas = now - self.last_clk_t
      if meas > 0.01 and meas < 5.0 then
        self.step_period_s = self.step_period_s * 0.7 + meas * 0.3
      end
    end
    self.last_clk_t = now

    local L        = self._L or 16
    local erosP    = (self._eros or 12) / 100.0
    local floorP   = self._floorP or 0.1
    local ceilP    = self._ceilP or 1.0
    local density  = self._density_off or 0.2
    local gate_pct = self._gate_pct or 10
    local neigh_k  = self._eros_cpl or 0.0
    local mode_val = self._mode or 0
    local avg_p    = self._avg_p or 0.5
    local s        = self._fb_s or 0.0
    local gate_dyn = self._gate_dyn or 1

    -- Stability trajectory scaling
    local fb_scale
    if s >= 0 then
      fb_scale = (1.0 - s) + s * avg_p
    else
      local d = -s
      fb_scale = (1.0 - d) + d * (1.0 - avg_p)
    end
    if fb_scale < 0.0 then fb_scale = 0.0 end
    if fb_scale > 2.0 then fb_scale = 2.0 end

    local i = self.pos or 1
    if i > L then i = 1 end

    local pdraw = self.p[i] + density
    if pdraw < 0 then pdraw = 0 elseif pdraw > 1 then pdraw = 1 end

    if math.random() < pdraw then
      -- Gate dynamics (generator mode)
      local gate_amp = 1.0
      if gate_dyn ~= 1 then
        local spread = ceilP - floorP
        if spread < 0.0001 then
          gate_amp = 1.0
        else
          local norm = (self.p[i] - floorP) / spread
          if norm < 0 then norm = 0 elseif norm > 1 then norm = 1 end
          -- Dynamics curve: sqrt for perceptual scaling, full 0-1 range for 2V-8V output
          gate_amp = math.sqrt(norm)
        end
      end
      self._gate_amp = gate_amp
      -- Pitch (Generator only)
      if mode_val == 0 then
        local mlen = self.motif_len or L
        local step_ix = ((i - 1) % mlen) + 1
        local deg = self.motif[step_ix] or 0
        
        -- Remap degree to fit current range
        local orig_octave = math.floor(deg / 12)
        local note_in_octave = deg % 12
        
        -- Scale from original motif range to current range
        local orig_range = self.motif_range or 2
        local new_range = self.range_v or 2
        local scaled_octave = math.floor((orig_octave * new_range) / orig_range)
        
        local final_deg = note_in_octave + (scaled_octave * 12)
        local note_pc = (final_deg + self.root) % 12
        local octave_offset = math.floor((final_deg + self.root) / 12)
        
        -- Add transpose and convert to voltage
        local pitch_semi = note_pc + (octave_offset * 12) + (self.offset_semi or 0)
        self.pitch_v = pitch_semi / 12.0
      end

      -- Gate pulse - schedule for next step cycle to avoid glitches
      local step_s   = self.step_period_s or 0.5
      if step_s < 0.02 then step_s = 0.02 end
      if step_s > 5.0  then step_s = 5.0  end
      local pulse_s  = step_s * (self._gate_pct or 10) / 100.0
      if pulse_s < 0.001 then pulse_s = 0.001 end
      -- Only trigger new gate if previous gate has finished (prevents double-trigger)
      if self.gate_t <= 0 then
        self.pending_gate_trigger = pulse_s
      end

      -- Erode
      local oldp = self.p[i]
      local newp
      if (self._eros_mode or 1) == 1 then
        -- Multiplicative
        newp = oldp * (1.0 - erosP * fb_scale)
      else
        -- Subtractive
        local ceilP = self._ceilP or 1.0
        local floorP_local = self._floorP or 0.0
        local e_abs = (erosP * fb_scale) * (ceilP - floorP_local)
        newp = oldp - e_abs
      end
      if newp < floorP then newp = floorP end
      self.p[i] = newp

      -- Erosion coupling (neighbors lose fraction of delta)
      local delta = oldp - newp
      local ndec  = delta * neigh_k
      if ndec > 0 then
        local il = i - 1; if il < 1 then il = L end
        local ir = i + 1; if ir > L then ir = 1 end
        local pl = self.p[il] - ndec
        if pl < floorP then pl = floorP end
        self.p[il] = pl
        local pr = self.p[ir] - ndec
        if pr < floorP then pr = floorP end
        self.p[ir] = pr
      end
    end

    i = i + 1
    if i > L then i = 1 end
    self.pos = i
    return
  end

  --------------------------------------------------------------------
  -- NOTE MASKING MODE: respond to Gate In (input 2)
  -- Uses 3ms delay to ensure pitch CV has been sampled
  --------------------------------------------------------------------
  if input ~= 2 then return end

  -- Schedule gate processing after 3ms delay
  self.pending_gate = true
  self.gate_delay_t = 0.003  -- 3 milliseconds

  -- Update event period from Gate In spacing
  local now = self.time_s or 0.0
  if self.last_gatein_t then
    local meas = now - self.last_gatein_t
    if meas > 0.01 and meas < 5.0 then
      self.step_period_s = self.step_period_s * 0.7 + meas * 0.3
    end
  end
  self.last_gatein_t = now
end,

  draw = function(self)
    -- Bars + cursor moved BELOW the top HUD line

    local L          = self._L or self.parameters[4] or 16
    local x0, y0     = 0, 15      -- bars span full width (lowered for cursor room)
    local w, h       = 255, 41    -- slightly shorter bars for cursor headroom
    local gap        = 1
    local bar_w      = math.max(1, math.floor((w - (L-1)*gap) / L))

    local x = x0
    for i = 1, L do
      local pi = self.p[i] or 0.0
      local bh = math.floor(h * clamp(pi, 0.0, 1.0) + 0.5)
      local y1 = y0 + (h - bh)
      local y2 = y0 + h
      drawRectangle(x, y1, x + bar_w, y2, 15)
      if i == self.pos then
        -- static-height cursor just above bars
        local cy2 = y0 - 2
        local cy1 = cy2 - 1
        drawRectangle(x, cy1, x + bar_w, cy2, 15)
      end
      x = x + bar_w + gap
    end
  end,
}