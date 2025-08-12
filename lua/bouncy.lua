-- Bouncy
--[[
Bouncing ball test script.
A general testing ground for scripting features.
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

-- test that require works
require 'complex'
local c = complex.add( complex.i, complex.new( 10, 20 ) )

local time = 0
local f = 2 * math.pi
local x = 0
local y = 0
local dx = 5
local dy = 6.7
local bing = 0.0
local lastMessage = ''
local gateState = false

local toScreenX = function( x )
	return 1.0 + 2.5 * ( x + 10.0 )
end
local toScreenY = function( y )
	return 12.0 + 2.5 * ( 10.0 - y )
end

local lx = toScreenX( -10.0 )
local cx = toScreenX( 0.0 )
local rx = toScreenX( 10.0 )
local ty = toScreenY( 10.0 )
local cy = toScreenY( 0.0 )
local by = toScreenY( -10.0 )

-- allocate a table to return from step(), rather than allocating a new one on every call
local out = {}

return
{
	name = 'bouncy'
,	author = 'Expert Sleepers Ltd'
	
,	init = function( self )
		return
		{
			inputs = { kCV, kTrigger, kGate }		-- or inputs = integer if all CVs
		,	inputNames = { [2]="Trigger input" }
		,	outputs = 2
		,	outputNames = { "X output", "Y output" }
		,	parameters = 
			{
				{ "Min X", -10, 10, -10, kVolts }			-- min, max, default, unit
			,	{ "Max X", -10, 10,  10, kVolts }
			,	{ "Min Y", -100, 100, -100, kVolts, kBy10 }	-- min, max, default, unit, scale
			,	{ "Max Y", -100, 100,  100, kVolts, kBy10 }
			,	{ "Edges", { "Bounce", "Warp" }, 1 }		-- enums, default
			,	{ "MIDI channel", 0, 16, 0 }
			}
		,	midi = { channelParameter = 6, messages = { "note", "cc", "bend", "aftertouch", "poly pressure", "program change" } }
		}
	end
	
,	trigger = function( self, input )
		if input == 2 then
			x = 0
			y = 0
		end
	end
	
,	gate = function( self, input, rising )
		if input == 3 then
			gateState = rising
		end
	end

,	step = function( self, dt, inputs )
		x = x + dx * dt
		y = y + dy * dt
		if dx < 0 and x < self.parameters[1] then
			if self.parameters[5] == 1 then
				dx = -dx
			else
				x = x - self.parameters[1] + self.parameters[2]
			end
		elseif dx > 0 and x > self.parameters[2] then
			if self.parameters[5] == 1 then
				dx = -dx
			else
				x = x - self.parameters[2] + self.parameters[1]
			end
		end
		if dy < 0 and y < self.parameters[3] then
			if self.parameters[5] == 1 then
				dy = -dy
			else
				y = y - self.parameters[3] + self.parameters[4]
			end
		elseif dy > 0 and y > self.parameters[4] then
			if self.parameters[5] == 1 then
				dy = -dy
			else
				y = y - self.parameters[4] + self.parameters[3]
			end
		end
		time = time + dt
		local t = f * time
		out[1] = x + math.sin( t )
		out[2] = y + inputs[1]
		return out
	end

,	midiMessage = function( self, message )
		if message[1] == 0x90 then
			lastMessage = "None on " .. message[2] .. " vel " .. message[3]
		elseif message[1] == 0x80 then
			lastMessage = "None off " .. message[2] .. " vel " .. message[3]
		end
	end
	
,	pot2Turn = function( self, x )
		local alg = self.algorithmIndex
		local p = self.parameterOffset + 1 + x * 3.5
		focusParameter( alg, p )
	end

,	pot3Turn = function( self, x )
		standardPot3Turn( x )
	end
	
, 	encoder1Turn = function( self, x )
		bing = 0.5
	end
, 	encoder2Turn = function( self, x )
		bing = 0.5
	end
, 	pot3Push = function( self )
		setDisplayMode( "overview" )
	end
, 	encoder2Push = function( self )
		setDisplayMode( "meters" )
	end
	
,	ui = function( self )
		return true
	end

,	draw = function( self )
		local alg = self.algorithmIndex
		local p = getCurrentParameter( alg ) - self.parameterOffset
		drawRectangle( cx, ty, cx, by, 1 )
		drawRectangle( lx, cy, rx, cy, 1 )
		local x1 = toScreenX( self.parameters[1] )
		local x2 = toScreenX( self.parameters[2] )
		local y1 = toScreenY( self.parameters[4] )
		local y2 = toScreenY( self.parameters[3] )
		drawRectangle( x1, y1, x2, y1, p == 4 and 15 or 2 )
		drawRectangle( x1, y2, x2, y2, p == 3 and 15 or 2 )
		drawRectangle( x1, y1, x1, y2, p == 1 and 15 or 2 )
		drawRectangle( x2, y1, x2, y2, p == 2 and 15 or 2 )
		local px = toScreenX( x )
		local py = toScreenY( y )
		drawSmoothBox( px-1.0, py-1.0, px+1.0, py+1.0, 15.0 )
		
		if bing > 0.0 then
			drawText( 100, 30, "bing!" )
			bing = bing - 0.03
		end
		
		drawText( 100, 40, gateState and "Open" or "Closed" )

		drawText( 100, 50, lastMessage )

		drawText( 100, 60, "Slot " .. alg )
	end
	
}
