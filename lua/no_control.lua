-- No Control
--[[
Variable step length trigger sequencer.
]]
--[[
MIT License

Copyright (c) 2025 Expert Sleepers Ltd

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local outputs = { 0.0 }
local step = 16
local countdown = 0
local trigger = 0

return
{
	name = 'No Control'
,	author = 'Expert Sleepers Ltd'
	
,	init = function( self )
		return
		{
			inputs = { kTrigger }
		,	inputNames = { "Reset" }
		,	outputs = 1
		,	parameters = 
			{
				{ "Time 1", 10, 2000, 500, kMs }
			,	{ "Time 2", 10, 2000, 500, kMs }
			,	{ "Time 3", 10, 2000, 500, kMs }
			,	{ "Time 4", 10, 2000, 500, kMs }
			,	{ "Time 5", 10, 2000, 500, kMs }
			,	{ "Time 6", 10, 2000, 500, kMs }
			,	{ "Time 7", 10, 2000, 500, kMs }
			,	{ "Time 8", 10, 2000, 500, kMs }
			,	{ "Time 9", 10, 2000, 500, kMs }
			,	{ "Time 10", 10, 2000, 500, kMs }
			,	{ "Time 11", 10, 2000, 500, kMs }
			,	{ "Time 12", 10, 2000, 500, kMs }
			,	{ "Time 13", 10, 2000, 500, kMs }
			,	{ "Time 14", 10, 2000, 500, kMs }
			,	{ "Time 15", 10, 2000, 500, kMs }
			,	{ "Time 16", 10, 2000, 500, kMs }
			}
		}
	end
	
,	trigger = function( self, input )
		step = 1
		countdown = self.parameters[ step ] * 0.001
		trigger = 0.005
		return outputs
	end

,	step = function( self, dt, inputs )
		countdown = countdown - dt
		if countdown <= 0 then
			step = step + 1
			if step > 16 then step = 1 end
			countdown = self.parameters[ step ] * 0.001
			trigger = 0.005
		end
		if trigger > 0 then
			trigger = trigger - dt
			outputs[1] = 5
		else
			outputs[1] = 0
		end
		return outputs
	end

,	draw = function( self )
		drawText( 80, 40, step )
		drawText( 120, 40, self.parameters[ step ] )
	end

}
