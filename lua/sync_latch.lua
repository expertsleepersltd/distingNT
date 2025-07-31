-- Sync Latch with Fill signal
--[[
 
Mutable Instuments MIDIpal "Sync Latch" app
Concept - deferred transport signals for 
slave clocks on precise musical boundaries
 
]] 

--[[
                        Mutable Instruments
                        S Y N C   L A T C H
                          [ MIDIpal app ] 
                          reconceived for 
                    Expert Sleepers  Disting NT
                    
                      by Michael Lauter a.k.a.
                          Sleepwalk Cinema
                       www.sleepwalkcine.com
                       
                       
                  USER MANUAL / THEORY of OPERATION here:
https://github.com/lauterzeit/synth_docs/blob/main/disting_nt/sync_latch_NT.pdf

]]--

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
]] -- 

-- Version
-- v1

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

-- local PPQN_options = {1, 2, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96, 120}
-- Had to limit external timebase options (PPQN) due to limitations of 
-- Lua Step function's 1ms output timing resolution
local PPQN_OPTIONS     = {24, 48, 96, 120}  -- options found on old Roland + Korg devices
local TIME_SIG_DEN_OPT = {1, 2, 4, 8, 16}

local AUTO_FILL_SWITCH = {"Off", "On"}
local SLV_STATE = {"Idle", "Run"}
local SIGNAL_EDGE = {"Falling", "Rising"}

local EOC_DURATION_OPT = {"50% Clock", "1 ms", "2 ms", "3 ms", "4 ms", "5 ms", "6 ms", "7 ms", "10 ms"}
local EOC_DURATION = {0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 10.0}

--------------------------------------------------------------------------------
-- Paramaters
--------------------------------------------------------------------------------

local PPQN_index = 1       -- default to 24 PPQN
local PPQN_res = 24        -- default PPQN clock resolution, see options above
local time_sig_num = 4     -- default Time Signature Numerator, use UI to change
local time_sig_den = 4     -- default Time Signature Denominator, use UI to change
local tmsig_den_index = 3
local eoc_dur_index = 3    -- use 2 ms pulse duration
local mu_missed_idx = 2

local loop_bars = 4        -- default number of bars for sync latch boundaries
local auto_fill_before_latch = true
local auto_fill_beats = 2

local slave_idle_at_reset = false
local output_on_rising_clock = false  --  Default, set to *false* is in
                                      --> FALLING Clock edge <<-- for best timing
                                      --  required for proper Roland DIN-SYNC timing !!
local af_switch_index = 1
local slv_st_ars_index = 2
local sgnl_edge_index = 1
local mumclk_index = 2

local makeup_missed_tick_AR = true    -- to deal with some Clk/Rst masters at Reset
local script_debug = false

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local slave_run = false     -- default, can override with parameter above
local fill_in = false      -- can set set Manually (Trig) or Auto by latch
local end_of_bar = false
local end_of_loop = false

local latch_arm = false
local latch_on_next_tick = false
local reset_request = false

local pulse_timer = false
local pulse_duration = 2
local elapsed_time = 0.0
local last_elapsed = 0.0    -- for debug only

-- Counters
local bar_countdown = loop_bars    -- bar (measure) countdown
local tick_countdown = PPQN_res * time_sig_num  -- clock tick countdown to End of Bar
local auto_fill_tick_count = PPQN_res * auto_fill_beats

-- Output Voltages for signals:
-- "Slave Run"   [1]
-- "Fill Gate"   [2]
-- "End of Bar"  [3]
-- "End of Loop" [4] 
local out_signals = {0.0, 0.0, 0.0, 0.0}


--------------------------------------------------------------------------------
return {
    name = "Sync Latch",
    author = "Sleepwalk Cinema",
    description = "Start / Stop Slave Clock on Measure Boundaries",

    init = function(self)
        return {
            -- Inputs: 1=Clock (Gate), 2=Reset, 3=Arm, 4=Fill
            inputs = {kGate, kTrigger, kTrigger, kTrigger},
            outputs = 4,
            inputNames = {"Clock input", "Reset input", "Arm input", "Fill input"},
            outputNames = {"Slave Run gate", "Fill gate", "End of Bar trig", "End of Loop trig"},
            parameters = {
                {"Loop Bars", 1, 16, 4 },
                {"Time Sig Numerator", 1, 17, 4, kNone },
                {"Time Sig Denomenator", TIME_SIG_DEN_OPT, 3 },
                {"Clock in PPQN", PPQN_OPTIONS, 1 },
                {"Auto Fill", AUTO_FILL_SWITCH, 2 },
                {"Auto Fill Beats", 1, 4, 2, kNone },
                {"Slave State upon Reset", SLV_STATE, 2 },
                {"Slave Gate on Clock", SIGNAL_EDGE, 1 },
                {"End of Loop Pulse dur", EOC_DURATION_OPT, 4},
                {"Makeup Reset Clock Tick", AUTO_FILL_SWITCH, 2 }
            }
        }
    end,

    ------------------------------------------------------------------------------
    -- gate(): 1=Clock In pulses
    ------------------------------------------------------------------------------
    gate = function(self, input, rising)
    	-- Clock --
        if input == 1 and rising then

            -- decrement clock tick counter
            if tick_countdown > 0 then
                tick_countdown = tick_countdown - 1
            end

            -- check for Latch request
            if latch_on_next_tick and output_on_rising_clock then    
                -- toggle the Latch ("Slave Run") signal
                slave_run = not slave_run

                --latch_arm = false
                latch_on_next_tick = false
            end

            end_of_bar = false -- clear
            end_of_loop = false -- clear

        elseif input == 1 and not rising and tick_countdown == 0 then
            -- we've seen last *falling clock* tick of current bar (measure)
            -- so pulse end of bar signal, which gets cleared at next *rising clock*
            end_of_bar = true
            fill_in = false

            -- using timed pulse mode
            if pulse_duration > 0 then
            	pulse_timer = true
            end

            -- decrement bar counter
            if bar_countdown > 0 then 
                bar_countdown = bar_countdown - 1 
            end

            -- end of Latch Loop?
            if bar_countdown == 0 then
                -- any change in loop length take effect after latch
                loop_bars = self.parameters[1]
                -- refill bar countdown
                bar_countdown = loop_bars 
                end_of_loop = true
                
                if latch_arm then
                    latch_on_next_tick = true
                    latch_arm = false
                end
            end

            if latch_on_next_tick and not output_on_rising_clock then
                -- We've just seen last falling clock of loop
                -- so in this mode --> Falling Clock Edge <--
                -- MUST be used for proper Roland DIN-SYNC timing !!
                -- toggle the Latch ("Slave Run") signal
                -- BEFORE first the rising clock of next measure
                if not pulse_timer then
                	-- do it now
                    slave_run = not slave_run
                                
                    latch_on_next_tick = false
                    latch_arm = false
                    -- else WAIT additional TIME = pulse_duration
                end
            end
            
            -- refill bar clock tick countdown
            tick_countdown = PPQN_res * time_sig_num
        end
        
        if bar_countdown == 1 and auto_fill_before_latch and latch_arm then
            if tick_countdown <= auto_fill_tick_count and not fill_in then
                fill_in = true
            end
        end
    end,

    ------------------------------------------------------------------------------
    -- trigger(): 2=Reset, 3=Arm, 4=Fill
    ------------------------------------------------------------------------------
    trigger = function(self, input)
        if input == 2 then
            -- Reset    
            reset_request = true  -- processed by step()
            
            mumclk_index = self.parameters[10]
            if AUTO_FILL_SWITCH[mumclk_index] == "On" then
                  makeup_missed_tick_AR = true
            else  makeup_missed_tick_AR = false
            end
            
            -- some paramater inits must go here
            PPQN_index = self.parameters[4]
            PPQN_res = PPQN_OPTIONS[PPQN_index]
            
            time_sig_num = self.parameters[2]
            tmsig_den_index = self.parameters[3]
            time_sig_den = TIME_SIG_DEN_OPT[tmsig_den_index]
            
            if time_sig_den ~= 4 then
                -- Yes, this is a HACK
                PPQN_res = math.floor( (PPQN_res * 4)  /  time_sig_den )
            end
            
            loop_bars = self.parameters[1]
            
            sgnl_edge_index = self.parameters[8]
            if SIGNAL_EDGE[sgnl_edge_index] == "Rising" then
                output_on_rising_clock = true
            else output_on_rising_clock = false
            end
            
            eoc_dur_index  = self.parameters[9]
            pulse_duration = EOC_DURATION[eoc_dur_index] / 1000.0
            pulse_timer = false
            elapsed_time = 0.0
            last_elapsed = 0.0  -- for debug only
                        
            latch_arm = false       
            latch_on_next_tick = false
            end_of_bar = false
            end_of_loop = false
            fill_in = false
            
            -- deal with fill-in countdown 
            if auto_fill_beats > time_sig_num then
                auto_fill_beats = time_sig_num
            end
            auto_fill_tick_count = PPQN_res * auto_fill_beats
            
            slave_run = not slave_idle_at_reset

            -- refill clock tick countdown
            tick_countdown = PPQN_res * time_sig_num
            bar_countdown = loop_bars
                
        	-- Missed first clock tick on reset, adjust counter
            if makeup_missed_tick_AR then
                tick_countdown = tick_countdown - 1
            end
                
        elseif input == 3 then
            -- toggle Arm request
            latch_arm = not latch_arm

        elseif input == 4 then
            -- Fill signal latch
            fill_in = true
        end
    end,

    ------------------------------------------------------------------------------
    -- step(): ~1 msec. dt= time since last step
    ------------------------------------------------------------------------------
    step = function(self, dt, inputs)
 
        af_switch_index = self.parameters[5]
        if AUTO_FILL_SWITCH[af_switch_index] == "On" then
              auto_fill_before_latch = true
        else  auto_fill_before_latch = false
        end

        auto_fill_beats = self.parameters[6]
        auto_fill_tick_count = PPQN_res * auto_fill_beats

        slv_st_ars_index = self.parameters[7]
        --slave_idle_at_reset = (SLV_STATE[slv_st_ars_index] == "Idle") and 1 or 0
        if SLV_STATE[slv_st_ars_index] == "Idle" then
              slave_idle_at_reset = true
        else  slave_idle_at_reset = false
        end

        eoc_dur_index  = self.parameters[9]
        pulse_duration = EOC_DURATION[eoc_dur_index] / 1000.0

        -- do pulse timer
        if pulse_timer and pulse_duration > 0 then
            if elapsed_time >= pulse_duration then
                -- check each signal
                if latch_on_next_tick then
                	-- delayed change
                    slave_run = not slave_run  -- toggle now

                    latch_on_next_tick = false
                    latch_arm = false                
                end
                
                if end_of_loop then
                    end_of_loop = false       -- force LOW now
                end
                
                if end_of_bar then
                    end_of_bar = false        -- force LOW now
                end
                
                last_elapsed = elapsed_time * 1000
                elapsed_time = 0.0                
                pulse_timer = false
            else
                -- accumulate and check again at next step() call
               elapsed_time = elapsed_time + dt
            end
        end

        -- reset trig seen so hold Run signal LOW for a delta step time
        if reset_request then
            out_signals[1] = 0
            reset_request = false
        else
            out_signals[1] = slave_run and 5 or 0
        end

    	out_signals[2] = fill_in and 5 or 0
        out_signals[3] = end_of_bar and 5 or 0
        out_signals[4] = end_of_loop and 5 or 0

        return out_signals
    end,

    ------------------------------------------------------------------------------
    -- UI stuff: Encoder2 Push to Arm / Disarm Latch, Pot3 Push to initiate Fill-In
    ------------------------------------------------------------------------------
    ui = function( self )
		return true
	end,
	
	encoder2Push = function( self )
        -- toggle Arm request
		latch_arm = not latch_arm
	end,
    
 	pot3Push = function( self )
 	    -- Fill signal latch
        fill_in = true
	end,
	
    ------------------------------------------------------------------------------
    -- draw(): Minimal status - Mutable Instruments style
    ------------------------------------------------------------------------------
    draw = function(self)
 
        local localBar = loop_bars - bar_countdown + 1
        local localTickCountup = PPQN_res * time_sig_num - tick_countdown
        local localBeat = math.floor(localTickCountup / PPQN_res) + 1
        local localTicks = localTickCountup % PPQN_res
		local arm_L_char = " "
		local arm_R_char = " "
		local fill_char = ":"
		local play_char = "."

		if latch_arm then
            arm_L_char = "["
            arm_R_char = "]"
        else
            arm_L_char = " "
            arm_R_char = " "
        end
        if slave_run then
        	play_char = ">"
        else
        	play_char = "."
        end
        if fill_in then
        	fill_char = "!"
        else
    	  	fill_char = ":"
        end

        local x = 95
        local y = 25
        drawText(15, 27, "Sync Latch")
        y = y + 15
        drawText(x,  y, arm_L_char)
        drawText(x+6,  y, ("%02d"):format(localBar))
        drawText(x+20, y, fill_char)
        drawText(x+24, y, ("%02d"):format(localBeat))
        drawText(x+38, y, fill_char)
        drawText(x+42, y, ("%02d"):format(localTicks))
        drawText(x+57, y, arm_R_char)
        drawText(x+65, y, play_char)
        
        if script_debug then
            drawText(x + 100, y, ("PPQN = %3d"):format(PPQN_res))
            drawText(x + 90, y-15, ("CLK = %s"):format(SIGNAL_EDGE[sgnl_edge_index]))
            drawText(x + 80, y+15, ("AF_ticks = %3d"):format(auto_fill_tick_count))
            -- drawText(15, y+15, ("elapsed = %.2f ms of %.1f ms duration"):format(last_elapsed, pulse_duration*1000))
        end
    end
}
