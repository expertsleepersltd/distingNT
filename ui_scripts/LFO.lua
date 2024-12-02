
local lfo
local p_speeds = {}

return
{
	name = 'LFO speeds'
,	author = 'Expert Sleepers Ltd'
,	description = 'Controls the speeds of the first three channels of an LFO'
	
,	init = function()
		lfo = findAlgorithm( "LFO" )
		if lfo == nil then
			return "Could not find 'LFO'"
		end
		for i=1,3 do
			local name = i .. ":Speed"
			p_speeds[i] = findParameter( lfo, name )
			if p_speeds[i] == nil then
				return "Could not find '" .. name .. "'"
			end
		end
		return true
	end

,	pot1Turn = function( value )
		setParameterNormalized( lfo, p_speeds[1], value )
	end

,	pot2Turn = function( value )
		setParameterNormalized( lfo, p_speeds[2], value )
	end

,	pot3Turn = function( value )
		setParameterNormalized( lfo, p_speeds[3], value )
	end

,	button2Push = function()
		exit()
	end

,	draw = function()
		for i=1,3 do
			drawParameterLine( lfo, p_speeds[i], ( i - 1 ) * 10 )
		end
		drawText( 0, 63, "Pots 1-3 control three LFO speeds" )
	end
}
