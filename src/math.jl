#InspectDR: Basic math operations
#-------------------------------------------------------------------------------
#=NOTE:
These tools should eventually be moved to a separate unit.
=#


#==Useful tests
===============================================================================#

#Verifies that v is strictly increasing (no repeating values):
#TODO: support repeating values (non-strict)
function isincreasing(v::Vector)
	if length(v) < 1; return true; end
	prev = v[1]

	for x in v[2:end]
		if !(x > prev) #Make sure works for NaN
			return false
		end
	end
	return true
end

isincreasing(r::Range) = (step(r) > 0)

#==Basic operations
===============================================================================#

#Safe version of extrema (returns DNaN on error):
function extrema_nan(v::Vector)
	try
		return extrema(v)
	end
	return (DNaN, DNaN)
end
#Last line
