-- Combined AE Random Voltage & Gates (Multi-Seq) with Revised Bipolar, UI, and Active Step Highlight
local NUM_SEQUENCES = 20
local MAX_STEPS = 32

local OUTPUT_BUFFER = {0, 0}  -- Preallocated output buffer for step()
local lastActiveIndex = 1     -- Tracks the last active sequence index

-- Tables to hold 20 voltage sequences and 20 gate sequences.
local voltageSequences = {}
local gateSequences = {}

-- Generate a random 16-bit raw value in the range [-32768, 32767]
local function generateRandomRawValue()
  return math.random(-32768, 32767)
end

-- Randomize a voltage sequence by filling its steps with raw values.
local function randomizeVoltageSequence(seq)
  for i = 1, seq.stepCount do
    seq.steps[i] = generateRandomRawValue()
  end
end

-- Utility for the gate part.
local function randomizeGateSequence(seq)
  for i = 1, MAX_STEPS do
    seq.steps[i] = math.random(100)
  end
end

-- Compute the effective voltage range based on polarity.
-- Polarity: 1 = Positive, 2 = Bipolar, 3 = Negative.
local function getEffectiveRange(minV, maxV, polarity)
  if polarity == 1 then
    return 0, maxV
  elseif polarity == 3 then
    return minV, 0
  else
    return minV, maxV
  end
end

-- Quantize a voltage value to the specified resolution.
local function quantizeVoltage(value, resolutionBits, effectiveMin, effectiveMax)
  local levels = (2 ^ resolutionBits) - 1
  local rangeEffective = effectiveMax - effectiveMin
  local stepSize = rangeEffective / levels
  local index = math.floor((value - effectiveMin) / stepSize + 0.5)
  local quantizedValue = index * stepSize + effectiveMin
  if quantizedValue < effectiveMin then quantizedValue = effectiveMin end
  if quantizedValue > effectiveMax then quantizedValue = effectiveMax end
  return quantizedValue
end

-- Update the cached voltage for the current step by mapping the raw value.
local function updateVoltageCached(seq, resolution, minV, maxV, polarity)
  local raw = seq.steps[seq.currentStep]
  local effectiveMin, effectiveMax = getEffectiveRange(minV, maxV, polarity)
  local fraction
  if polarity == 2 then
    -- Bipolar: map full raw range [-32768,32767] to [0,1]
    fraction = (raw + 32768) / 65535
  elseif polarity == 1 then
    -- Positive: clamp negatives to 0; map [0,32767] to [0,1]
    local clamped = raw < 0 and 0 or raw
    fraction = clamped / 32767
  elseif polarity == 3 then
    -- Negative: clamp positives to 0; map [-32768,0] to [0,1]
    local clamped = raw > 0 and 0 or raw
    fraction = (clamped + 32768) / 32768
  end
  local value = fraction * (effectiveMax - effectiveMin) + effectiveMin
  seq.cachedVoltage = quantizeVoltage(value, resolution, effectiveMin, effectiveMax)
end

-- Initialize the 20 sequences if not already done.
local function initSequences()
  if #voltageSequences < NUM_SEQUENCES then
    for i = 1, NUM_SEQUENCES do
      voltageSequences[i] = { currentStep = 1, stepCount = 8, cachedVoltage = 0, steps = {} }
      for j = 1, MAX_STEPS do
        voltageSequences[i].steps[j] = generateRandomRawValue()
      end
      updateVoltageCached(voltageSequences[i], 16, -1, 1, 2)

      gateSequences[i] = { stepIndex = 1, numSteps = 16, gateRemainingSteps = 0, steps = {} }
      for j = 1, MAX_STEPS do
        gateSequences[i].steps[j] = math.random(100)
      end
    end
  end
end

-- Global randomize function to randomize all sequences.
local function globalRandomize(self)
  for i = 1, NUM_SEQUENCES do
    randomizeVoltageSequence(voltageSequences[i])
    updateVoltageCached(voltageSequences[i], self.parameters[6], self.parameters[3], self.parameters[4], self.parameters[5])
    randomizeGateSequence(gateSequences[i])
  end
end

return {
  name = "Combined AE Random Voltage & Gates (Multi-Seq)",
  author = "Modified from Andras Eichstaedt / Thorinside / 4o",
  
  init = function(self)
    initSequences()
    return {
      -- Three inputs: 
      -- 1 = clock (stepping), 2 = reset trigger, 3 = global randomize trigger
      inputs = { kGate, kTrigger, kTrigger },
      outputs = { kStepped, kGate },
      encoders = { 1, 2 },
      parameters = {
        {"Active Seq Index", 1, NUM_SEQUENCES, 1, kInt},
        {"Voltage Steps", 1, MAX_STEPS, 8, kInt},
        {"Min Voltage", -10, 10, -1, kVolts},
        {"Max Voltage", -10, 10, 1, kVolts},
        {"Polarity", {"Positive", "Bipolar", "Negative"}, 2, kEnum},
        {"Bit Depth (Voltage)", 2, 16, 16, kInt},
        {"Gate Steps", 1, MAX_STEPS, 16, kInt},
        {"Threshold", 1, 100, 50, kPercent},
        {"Gate Length", 5, 1000, 100, kMs},
        {"Global Randomize", {"Off", "On"}, 1, kEnum},
      }
    }
  end,
  
  gate = function(self, input, rising)
    local idx = self.parameters[1]
    if input == 1 and rising then
      -- Advance voltage sequence.
      local voltSeq = voltageSequences[idx]
      voltSeq.stepCount = self.parameters[2]
      voltSeq.currentStep = voltSeq.currentStep + 1
      if voltSeq.currentStep > voltSeq.stepCount then
        voltSeq.currentStep = 1
      end
      updateVoltageCached(voltSeq, self.parameters[6], self.parameters[3], self.parameters[4], self.parameters[5])
      
      -- Advance gate sequence.
      local gateSeq = gateSequences[idx]
      gateSeq.numSteps = self.parameters[7]
      gateSeq.stepIndex = gateSeq.stepIndex + 1
      if gateSeq.stepIndex > gateSeq.numSteps then
        gateSeq.stepIndex = 1
      end
      if gateSeq.steps[gateSeq.stepIndex] >= self.parameters[8] then
        gateSeq.gateRemainingSteps = self.parameters[9]
      end
    end
  end,
  
  trigger = function(self, input)
    local idx = self.parameters[1]
    if input == 2 then
      -- Reset active sequence.
      voltageSequences[idx].currentStep = 1
      updateVoltageCached(voltageSequences[idx], self.parameters[6], self.parameters[3], self.parameters[4], self.parameters[5])
      gateSequences[idx].stepIndex = 1
    elseif input == 3 then
      -- Global randomize all sequences.
      globalRandomize(self)
    end
  end,
  
  step = function(self, dt, inputs)
    local idx = self.parameters[1]
    if idx ~= lastActiveIndex then
      lastActiveIndex = idx
      updateVoltageCached(voltageSequences[idx], self.parameters[6], self.parameters[3], self.parameters[4], self.parameters[5])
    end
    OUTPUT_BUFFER[1] = voltageSequences[idx].cachedVoltage
    local gateSeq = gateSequences[idx]
    if gateSeq.gateRemainingSteps > 0 then
      gateSeq.gateRemainingSteps = gateSeq.gateRemainingSteps - 1
      OUTPUT_BUFFER[2] = 5
    else
      OUTPUT_BUFFER[2] = 0
    end
    return OUTPUT_BUFFER
  end,
  
  encoder2Push = function(self)
    globalRandomize(self)
  end,
  
  pot2Turn = function(self, x)
    local alg = getCurrentAlgorithm()
    local p = self.parameterOffset + 1 + x * 10.5
    focusParameter(alg, p)
  end,
  
  pot3Turn = function(self, x)
    standardPot3Turn(x)
  end,
  
  draw = function(self)
    local idx = self.parameters[1]
    -- Leave top 20px unused (for header)
    
    -- Draw gate sequence as blocks, starting at y = 25.
    local gateSeq = gateSequences[idx]
    local numGate = self.parameters[7]
    local gateBlockWidth = math.floor(256 / numGate)
    local gateBlockHeight = 10
    local gateY = 25
    for i = 1, numGate do
      local x = (i - 1) * gateBlockWidth
      if gateSeq.steps[i] >= self.parameters[8] then
        drawRectangle(x, gateY, x + gateBlockWidth - 2, gateY + gateBlockHeight, 15)
      else
        drawRectangle(x, gateY, x + gateBlockWidth - 2, gateY + gateBlockHeight, 3)
      end
      if i == gateSeq.stepIndex then
         -- Draw white border around active gate step.
         drawLine(x, gateY, x + gateBlockWidth - 2, gateY, 15)
         drawLine(x, gateY, x, gateY + gateBlockHeight, 15)
         drawLine(x + gateBlockWidth - 2, gateY, x + gateBlockWidth - 2, gateY + gateBlockHeight, 15)
         drawLine(x, gateY + gateBlockHeight, x + gateBlockWidth - 2, gateY + gateBlockHeight, 15)
      end
    end
    
    -- Draw voltage sequence as colored blocks, starting at y = 40.
    local voltSeq = voltageSequences[idx]
    local numVolt = self.parameters[2]
    local voltBlockWidth = math.floor(256 / numVolt)
    local voltBlockHeight = 10
    local voltY = 40
    local effectiveMin, effectiveMax = getEffectiveRange(self.parameters[3], self.parameters[4], self.parameters[5])
    for i = 1, numVolt do
      local x = (i - 1) * voltBlockWidth
      local raw = voltSeq.steps[i]
      local voltage
      if self.parameters[5] == 2 then
        voltage = (raw + 32768) / 65535 * (effectiveMax - effectiveMin) + effectiveMin
      elseif self.parameters[5] == 1 then
        voltage = (raw < 0 and 0 or raw) / 32767 * (effectiveMax - effectiveMin) + effectiveMin
      elseif self.parameters[5] == 3 then
        voltage = ((raw > 0 and 0 or raw) + 32768) / 32768 * (effectiveMax - effectiveMin) + effectiveMin
      end
      local norm = (voltage - effectiveMin) / (effectiveMax - effectiveMin)
      if norm < 0 then norm = 0 end
      if norm > 1 then norm = 1 end
      local colorIndex = math.floor(norm * 14) + 1
      drawRectangle(x, voltY, x + voltBlockWidth - 2, voltY + voltBlockHeight, colorIndex)
      if i == voltSeq.currentStep then
         -- Draw white border around active voltage step.
         drawLine(x, voltY, x + voltBlockWidth - 2, voltY, 15)
         drawLine(x, voltY, x, voltY + voltBlockHeight, 15)
         drawLine(x + voltBlockWidth - 2, voltY, x + voltBlockWidth - 2, voltY + voltBlockHeight, 15)
         drawLine(x, voltY + voltBlockHeight, x + voltBlockWidth - 2, voltY + voltBlockHeight, 15)
      end
    end
  end,
}
