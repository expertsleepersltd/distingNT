
local looper
local p_record
local p_play
local p_undo
local p_redo
local p_targetNext
local p_targetLoop

local focusOnCurrentLayer = function()
	local v = getParameter( looper, p_targetLoop )
	if v <= 4 then
		local p = findParameter( looper, string.format("%.0f",v) .. ":Current layer" )
		if p then
			focusParameter( looper, p )
		end
	end
end

return
{
	name = 'Example UI script'
,	author = 'Expert Sleepers Ltd'
,	description = 'Custom UI for the Looper, using the two encoders as the record and play buttons'
	
,	init = function()
		looper = findAlgorithm( "Looper" )
		if looper == nil then
			return "Could not find 'Looper'"
		end
		p_targetLoop = findParameter( looper, "Target loop" )
		if p_targetLoop == nil then
			return "Could not find 'Target loop'"
		end
		p_record = findParameter( looper, "Record" )
		if p_record == nil then
			return "Could not find 'Record'"
		end
		p_play = findParameter( looper, "Play" )
		if p_play == nil then
			return "Could not find 'Play'"
		end
		p_undo = findParameter( looper, "Undo" )
		if p_undo == nil then
			return "Could not find 'Undo'"
		end
		p_redo = findParameter( looper, "Redo" )
		if p_redo == nil then
			return "Could not find 'Redo'"
		end
		p_targetNext = findParameter( looper, "Target next" )
		if p_targetNext == nil then
			return "Could not find 'Target next'"
		end
		return true
	end

,	pot1Turn = function( value )
		standardPot1Turn( value )
	end

,	pot2Turn = function( value )
		standardPot2Turn( value )
	end

,	pot3Turn = function( value )
		standardPot3Turn( value )
	end

,	button2Push = function()
		exit()
	end

,	button4Push = function()
		setParameter( looper, p_targetNext, 1 )
		setParameter( looper, p_targetNext, 0 )
	end
	
,	encoder1Push = function()
		setParameter( looper, p_record, 1 )
	end
	
,	encoder1Release = function()
		setParameter( looper, p_record, 0 )
		focusOnCurrentLayer()
	end
	
,	encoder2Push = function()
		setParameter( looper, p_play, 1 )
	end
	
,	encoder2Release = function()
		setParameter( looper, p_play, 0 )
	end
	
,	encoder2Turn = function( whichWay )
		if whichWay > 0 then
			setParameter( looper, p_redo, 1 )
			setParameter( looper, p_redo, 0 )
		else
			setParameter( looper, p_undo, 1 )
			setParameter( looper, p_undo, 0 )
		end
		focusOnCurrentLayer()
	end
	
,	draw = function()
		drawStandardParameterLine()
		drawAlgorithmUI( looper )
	end
}
