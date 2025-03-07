-- Gene Sequencer
--[[
A sequence that evolves to your preferences. Two modes, Evolve mode and Play mode.
In play mode, the sequencer plays through all of the sequences and loops.
In evolve mode, select sequences, modify your fitness preferences (lower=dislike, higher=like)
and then press Encoder 2 to evolve.

Evolution is under your control.

In1=Clock
In2=Reset
In3=Evolve

UI:
Enc1=Sequence Selector
Enc2=Fitness Tweaker
Enc2Press=Evolve
]]

--[[
This is free and unencumbered software released into the public domain.
Anyone is free to copy, modify, publish, use, compile, sell, or distribute this
software, either in source code form or as a compiled binary, for any purpose,
commercial or non-commercial, and by any means.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]
local NUM_SEQUENCES        = 6
local STEPS_PER_SEQ        = 16
local MUTATE_GATES         = true

local population           = {}
local currentSequenceIndex = 1
local currentStep          = 1
local evolutionCount       = 0

local function randFloat(minVal, maxVal)
  return minVal + (maxVal - minVal) * math.random()
end

local function randomSequence()
  local seq = { voltages = {}, gates = {}, fitness = 1.0 }
  for i = 1, STEPS_PER_SEQ do
    seq.voltages[i] = randFloat(-1, 1) -- normalized -1..+1
    seq.gates[i]    = (math.random() < 0.5)
  end
  return seq
end

local function initPopulation()
  population = {}
  for s = 1, NUM_SEQUENCES do
    population[s] = randomSequence()
  end
end

local function crossover(seqA, seqB)
  local child = { voltages = {}, gates = {}, fitness = 1.0 }
  local cut   = math.random(1, STEPS_PER_SEQ)
  for i = 1, STEPS_PER_SEQ do
    if i <= cut then
      child.voltages[i] = seqA.voltages[i]
      child.gates[i]    = seqA.gates[i]
    else
      child.voltages[i] = seqB.voltages[i]
      child.gates[i]    = seqB.gates[i]
    end
  end
  return child
end

local function mutate(seq, evolveRate)
  local mutateProbability = evolveRate / 100.0
  for i = 1, STEPS_PER_SEQ do
    if math.random() < mutateProbability then
      seq.voltages[i] = seq.voltages[i] + randFloat(-0.5, 0.5)
      if seq.voltages[i] < -1 then seq.voltages[i] = -1 end
      if seq.voltages[i] > 1 then seq.voltages[i] = 1 end

      if MUTATE_GATES then
        seq.gates[i] = not seq.gates[i]
      end
    end
  end
end

local function computeFitness(seq)
  local score = seq.fitness
  local uniqueVals = {}

  for i = 1, STEPS_PER_SEQ do
    local v = seq.voltages[i]
    uniqueVals[v] = true

    if i > 1 then
      local prev = seq.voltages[i - 1]
      local interval = math.abs(v - prev)
      if interval > 0.4 then
        score = score - 0.2 * interval
      else
        score = score + 0.1
      end
      if interval < 0.0001 then
        score = score - 0.05
      end
    end
  end

  -- variety
  local distinctCount = 0
  for _ in pairs(uniqueVals) do
    distinctCount = distinctCount + 1
  end
  score          = score + (distinctCount * 0.05)

  -- start/end closeness
  local firstVal = seq.voltages[1]
  local lastVal  = seq.voltages[STEPS_PER_SEQ]
  local dist     = math.abs(lastVal - firstVal)
  if dist > 0 and dist < 0.5 then
    score = score + 0.3
  elseif dist == 0 then
    score = score - 0.15
  end

  -- gates
  local gateOnCount = 0
  for i = 1, STEPS_PER_SEQ do
    if seq.gates[i] then
      gateOnCount = gateOnCount + 1
    end
  end
  score = score + ((gateOnCount / STEPS_PER_SEQ) * 0.5)

  return score
end

local function pickParent()
  local sumF = 0
  for s = 1, NUM_SEQUENCES do
    sumF = sumF + computeFitness(population[s])
  end
  local r = randFloat(0, sumF)
  local cum = 0
  for s = 1, NUM_SEQUENCES do
    cum = cum + computeFitness(population[s])
    if r <= cum then
      return population[s]
    end
  end
  return population[NUM_SEQUENCES]
end

local function findBestSeq()
  local bestIndex = 1
  local bestVal   = computeFitness(population[1])
  for s = 2, NUM_SEQUENCES do
    local fval = computeFitness(population[s])
    if fval > bestVal then
      bestVal   = fval
      bestIndex = s
    end
  end
  return bestIndex, bestVal
end

local function evolvePopulation(evolveRate)
  local bestIdx = findBestSeq()
  local bestSeq = population[bestIdx]

  local newPop = {}
  -- elitism
  newPop[1] = { voltages = {}, gates = {}, fitness = bestSeq.fitness }
  for i = 1, STEPS_PER_SEQ do
    newPop[1].voltages[i] = bestSeq.voltages[i]
    newPop[1].gates[i]    = bestSeq.gates[i]
  end

  for s = 2, NUM_SEQUENCES do
    local pA    = pickParent()
    local pB    = pickParent()
    local child = crossover(pA, pB)
    mutate(child, evolveRate)
    newPop[s] = child
  end

  population = newPop
  evolutionCount = evolutionCount + 1
end

-------------------------------------------------------------
-- SCRIPT TABLE
-------------------------------------------------------------
return {
  name         = "Gene Sequencer",
  author       = "Thorinside | o1",

  init         = function(self)
    initPopulation()
    currentSequenceIndex = 1
    currentStep = 1
    evolutionCount = 0

    return {
      inputs = { kGate, kTrigger, kTrigger },
      outputs = 2,
      parameters = {
        { "Min Voltage",    -10,                  10,  -2,   kVolts },
        { "Max Voltage",    -10,                  10,  2,    kVolts },
        { "Evolution Rate", 0,                    100, 20,   kPercent },
        { "Randomize",      { "Off", "On" },      1,   kEnum },
        { "Mode",           { "Evolve", "Play" }, 1,   kEnum }
      }
    }
  end,

  gate         = function(self, input, rising)
    if input == 1 and rising then
      -- If randomize=On => re-randomize
      if self.parameters[4] == 2 then -- "On"
        initPopulation()
        currentSequenceIndex = 1
        currentStep          = 1
        evolutionCount       = 0

        -- fix setParameter usage
        local algIndex       = getCurrentAlgorithm()
        setParameter(algIndex, self.parameterOffset + 4, 1) -- param #4 => "Off"
      end

      currentStep = currentStep + 1

      -- If we pass the last step
      if currentStep > STEPS_PER_SEQ then
        currentStep = 1
        -- If Mode=Play, cycle to next sequence
        if self.parameters[5] == 2 then
          currentSequenceIndex = currentSequenceIndex + 1
          if currentSequenceIndex > NUM_SEQUENCES then
            currentSequenceIndex = 1
          end
        end
      end
    end
  end,

  trigger      = function(self, input)
    if input == 2 then
      currentStep = 1
    elseif input == 3 then
      local evoRate = self.parameters[3]
      evolvePopulation(evoRate)
      currentStep = 1
    end
  end,

  step         = function(self, dt, inputs)
    local seq    = population[currentSequenceIndex]
    local rawVal = seq.voltages[currentStep] -- -1..+1
    local gateOn = seq.gates[currentStep]

    local minV   = self.parameters[1]
    local maxV   = self.parameters[2]
    local norm   = (rawVal + 1) * 0.5
    local scaled = minV + norm * (maxV - minV)

    local outV   = scaled
    local outG   = gateOn and 5.0 or 0.0
    return { outV, outG }
  end,

  ui           = function(self)
    return true
  end,

  -- Standard pot usage
  pot1Turn     = function(self, val)
    standardPot1Turn(val)
  end,

  pot2Turn     = function(self, val)
    standardPot2Turn(val)
  end,

  pot3Turn     = function(self, val)
    standardPot3Turn(val)
  end,

  ---------------------------------------------------------
  -- pot3Push toggles mode param #5 Evolve <-> Play
  -- using the correct setParameter( alg, paramIndex, value )
  ---------------------------------------------------------
  pot3Push     = function(self)
    local modeParam = self.parameters[5]
    local algIndex  = getCurrentAlgorithm()
    local paramIdx  = self.parameterOffset + 5

    if modeParam == 1 then
      -- was "Evolve" => switch to "Play"
      setParameter(algIndex, paramIdx, 2)
    else
      -- was "Play" => switch to "Evolve"
      setParameter(algIndex, paramIdx, 1)
    end
  end,

  -- Encoders => GA usage
  encoder1Turn = function(self, delta)
    if self.parameters[5] == 1 then
      -- Only allow manual selection if Mode=Evolve
      currentSequenceIndex = currentSequenceIndex + delta
      if currentSequenceIndex < 1 then
        currentSequenceIndex = 1
      elseif currentSequenceIndex > NUM_SEQUENCES then
        currentSequenceIndex = NUM_SEQUENCES
      end
    end
  end,

  encoder2Turn = function(self, delta)
    local seq = population[currentSequenceIndex]
    seq.fitness = seq.fitness + (0.1 * delta)
    if seq.fitness < 0.1 then seq.fitness = 0.1 end
    if seq.fitness > 5.0 then seq.fitness = 5.0 end
  end,

  encoder2Push = function(self)
    local evoRate = self.parameters[3]
    evolvePopulation(evoRate)
    currentStep = 1
  end,

  draw         = function(self)
    local yOffset   = 20
    local seq       = population[currentSequenceIndex]
    local modeParam = self.parameters[5] -- 1=Evolve, 2=Play
    local modeStr   = (modeParam == 1) and "Evolve" or "Play"

    drawText(10, yOffset, "Seq " .. string.format("%d", currentSequenceIndex) .. "/" .. NUM_SEQUENCES)
    drawText(110, yOffset, "Evolutions: " .. evolutionCount)
    drawText(10, yOffset + 10, "Fitness: " .. string.format("%.2f", seq.fitness))
    drawText(110, yOffset + 10, "Mode: " .. modeStr)

    local xStart = 10
    local yStart = yOffset + 25
    local boxW   = 12
    local gap    = 2

    for i = 1, STEPS_PER_SEQ do
      local x1 = xStart + (i - 1) * (boxW + gap)
      local y1 = yStart
      local x2 = x1 + boxW
      local y2 = y1 + 10

      local col = seq.gates[i] and 12 or 3
      if i == currentStep then
        drawBox(x1 - 1, y1 - 1, x2 + 1, y2 + 1, 15)
      end
      drawRectangle(x1, y1, x2, y2, col)
    end
  end
}
