
local augustus
local p_multiplier

return
{
	name = 'Example UI script'
,	author = 'Expert Sleepers Ltd'
,	description = 'User manual example - controls one parameter of Augustus Loop'
	
,	init = function()
		augustus = findAlgorithm( "Augustus Loop" )
		if augustus == nil then
			return "Could not find 'Augustus Loop'"
		end
		p_multiplier = findParameter( augustus, "Delay multiplier" )
		if p_multiplier == nil then
			return "Could not find 'Delay multiplier'"
		end
		return true
	end

,	pot3Turn = function( value )
		setParameterNormalized( augustus, p_multiplier, value )
	end

,	button2Push = function()
		exit()
	end

,	draw = function()
		drawStandardParameterLine()
		drawText( 30, 40, "Hello!" )
		drawLine( 30, 10, 100, 20, 15 )
		drawSmoothLine( 100, 25.5, 30, 18.2, 8.3 )
		drawBox( 20, 40, 25, 45, 15 )
		drawRectangle( 21, 41, 24, 44, 1 )
	end
}
