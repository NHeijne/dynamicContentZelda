local matrix = require("matrix")
local log = require("log")

local learningAlgorithms = {}

function learningAlgorithms.linearRegression (X, y)
	log.debug(matrix.tostring(X))
	--log.debug(matrix.tostring(y))
	
	--beta = (X.T * X).-1 * X.T * y	
	local XtotheT = matrix.transpose( X )
	local Xtothe2 = matrix.mul( XtotheT, X )
	
	log.debug(matrix.det( Xtothe2 ))
	if matrix.det( Xtothe2 ) == 0 then return nil end
	
	local partOne = matrix.invert( Xtothe2 )
	local partOneAndTwo = matrix.mul( partOne, XtotheT )
	local betaHat = matrix.mul( partOneAndTwo, y )
	
	log.debug(betaHat)

	return betaHat
end

return learningAlgorithms