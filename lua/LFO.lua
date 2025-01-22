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

--[[
Mainly intended as an example of the two different output modes, stepped and linear.
]]

return
{
	name = 'LFO'
,	author = 'Expert Sleepers Ltd'
	
,	init = function( self )
		self.t = 0.0
		return
		{
			inputs = 1
		,	outputs = { kStepped, kLinear }
		}
	end

,	step = function( self, dt, inputs )
		local f = 1 + inputs[1]
		local t = self.t + dt * f
		if t >= 1.0 then
			t = t - 1.0
		elseif t < 0.0 then
			t = t + 1.0
		end
		self.t = t
		local sqr = t > 0.5 and 5.0 or -5.0
		local tri = 20 * math.min( t, 1 - t ) - 5
		return { sqr, tri }
	end

}
