-- LSystemSequencer
local LSystemSequencer = {}

-- Compatibility shim for Lua 5.1 / 5.4
local unpack = table.unpack or unpack

-- Default scale: C major (semitone offsets)
LSystemSequencer.default_scale = {0, 2, 4, 5, 7, 9, 11}

----------------------------------------------------------------------
-- Utility helpers
----------------------------------------------------------------------

-- Pick one key from a `{ value = weight, ... }` table
-- Now a method using the stored deterministic generator
function LSystemSequencer:weighted_choice(tbl)
    local total, acc = 0, 0
    for _, w in pairs(tbl) do total = total + w end
    -- Use math.random() instead of the custom LCG
    local r = math.random() * total
    for k, w in pairs(tbl) do
        acc = acc + w
        if r <= acc then return k end
    end
end

-- Favour stepwise motion – weights can be tweaked to taste
local STEP_WEIGHTS = {[-2] = 1, [-1] = 3, [0] = 4, [1] = 3, [2] = 1}
-- Now a method using self:weighted_choice
function LSystemSequencer:weighted_step()
    return self:weighted_choice(STEP_WEIGHTS)
end

-- Triangular‑ish random number between a & b (closer to middle on average)
local function triangular_rand(a, b)
    -- Sum of two uniforms gives triangular PDF
    local u = math.random() + math.random()
    return a + (b - a) * u * 0.5 -- scale to [0,1], peak at centre
end

----------------------------------------------------------------------
-- Constructor
----------------------------------------------------------------------

function LSystemSequencer.new(config)
    local self = {}
    setmetatable(self, {__index = LSystemSequencer}) -- Allow calling methods

    ------------------------------------------------------------------
    -- Config
    ------------------------------------------------------------------
    self.axiom = config.axiom or "P"
    self.iterations = config.iterations or 3
    self.scale = config.scale or LSystemSequencer.default_scale
    self.base_note = config.base_note or 60 -- MIDI middle C
    self.velocity_range = config.velocity_range or {60, 127}
    self.duration_range = config.duration_range or {0.125, 0.5}

    -- Parameterised rule probabilities (unchanged interface)
    self.probabilities = config.probabilities or
                             {
            P = {PRP = 0.6, PV = 0.4},
            R = {RV = 0.7, RR = 0.3},
            V = {VP = 1.0}
        }

    ------------------------------------------------------------------
    -- L‑system expansion rules
    ------------------------------------------------------------------
    -- These now implicitly call self:weighted_choice via the metatable
    self.rules = {
        P = function(seq) return seq:weighted_choice(seq.probabilities.P) end,
        R = function(seq) return seq:weighted_choice(seq.probabilities.R) end,
        V = function(seq) return seq:weighted_choice(seq.probabilities.V) end
    }
    -- Store the initial generator based on config or default seed (will be overwritten by _update_sequencer_config in init)

    ------------------------------------------------------------------
    -- Expand axiom for N iterations
    ------------------------------------------------------------------
    function self:expand()
        local current = self.axiom
        for _ = 1, self.iterations do
            local next_expansion = {} -- Renamed to avoid conflict
            for i = 1, #current do
                local sym = current:sub(i, i)
                -- Pass 'self' (the sequencer object) to the rule function
                local repl = self.rules[sym] and self.rules[sym](self) or sym
                next_expansion[#next_expansion + 1] = repl
            end
            current = table.concat(next_expansion)
        end
        return current
    end

    ------------------------------------------------------------------
    -- Turn expanded symbol string into { note‑event, … }
    ------------------------------------------------------------------
    function self:interpret(symbols)
        local events = {}

        local pitch_idx = 1 -- position in scale
        local velocity = (self.velocity_range[1] + self.velocity_range[2]) / 2
        local duration = (self.duration_range[1] + self.duration_range[2]) / 2

        local scale_len = #self.scale

        for i = 1, #symbols do
            local sym = symbols:sub(i, i)

            if sym == "P" then
                ------------------------------------------------------------------
                -- Choose next scale step (mostly stepwise, occasional leaps)
                ------------------------------------------------------------------
                pitch_idx = pitch_idx + self:weighted_step() -- Call as method
                if pitch_idx < 1 then pitch_idx = 1 end

                -- Wrap into octaves for musical continuity
                local octave = math.floor((pitch_idx - 1) / scale_len)
                local degree = ((pitch_idx - 1) % scale_len) + 1
                local note = self.base_note + octave * 12 + self.scale[degree]

                -- Clamp to valid MIDI range just in case
                if note < 0 then
                    note = 0
                elseif note > 127 then
                    note = 127
                end

                ------------------------------------------------------------------
                events[#events + 1] = {
                    type = "note",
                    pitch = note,
                    velocity = math.floor(velocity),
                    duration = duration
                }

            elseif sym == "R" then
                ------------------------------------------------------------------
                -- Pick one of three quantised durations (short / mid / long)
                ------------------------------------------------------------------
                local min_d, max_d = unpack(self.duration_range)
                local mid_d = (min_d + max_d) * 0.5
                local choices = {min_d, mid_d, max_d}
                duration = choices[math.random(#choices)]

            elseif sym == "V" then
                ------------------------------------------------------------------
                -- Choose velocity with triangular distribution (natural feel)
                ------------------------------------------------------------------
                local vmin, vmax = unpack(self.velocity_range)
                velocity = triangular_rand(vmin, vmax)
            end
        end

        return events
    end

    return self
end

return LSystemSequencer
