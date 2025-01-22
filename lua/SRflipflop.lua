
return
{
	name = 'SRflipflop'
,	author = 'Expert Sleepers Ltd'
	
,	init = function( self )
		return
		{
			inputs = { kTrigger, kTrigger }
		,	outputs = 1
		}
	end
	
,	trigger = function( self, input )
		self.state = input > 1
		local v = self.state and 5.0 or 0.0
		return { v }
	end

,	draw = function( self )
		drawText( 100, 40, self.state and "High" or "Low" )
	end

}
