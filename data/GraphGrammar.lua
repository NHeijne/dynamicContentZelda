-- Copyright (c) 2014, lordnaugty
-- All rights reserved.

-- Redistribution and use in source and binary forms, with or without 
-- modification, are permitted provided that the following conditions are met:

-- 1. Redistributions of source code must retain the above copyright notice, 
-- this list of conditions and the following disclaimer.

-- 2. Redistributions in binary form must reproduce the above copyright 
-- notice, this list of conditions and the following disclaimer in the 
-- documentation and/or other materials provided with the distribution.

-- 3. Neither the name of the copyright holder nor the names of its
-- contributors may be used to endorse or promote products derived from this 
-- software without specific prior written permission.

-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
-- DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE 
-- FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
-- DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
-- SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
-- CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
-- OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


require 'Graph'

GraphGrammar = {
	Rule = {}
}

GraphGrammar.Rule.__index = GraphGrammar.Rule

-- TODO: Describe graph grammar production rules in a nice terse comment...
-- - All pattern and substitute vertices should have tag fields.

function GraphGrammar.Rule.new( pattern, substitute, map )
	-- Check that the pattern and substitute graphs have tags.
	for vertex, _ in pairs(pattern.vertices) do
		assert(vertex.tag)
	end

	for vertex, _ in pairs(substitute.vertices) do
		assert(vertex.tag)
	end

	-- Check that the map uses valid vertices.
	for patternVertex, substituteVertex in pairs(map) do
		assert(pattern.vertices[patternVertex])
		assert(substitute.vertices[substituteVertex])
	end

	-- Check that pattern is a subgraph of substitute using the map.
	for patternEdge, patternEdgeEnds in pairs(pattern.edges) do
		local patternVertex1, patternVertex2 = patternEdgeEnds[1], patternEdgeEnds[2]

		local substituteVertex1, substituteVertex2 = map[patternVertex1], map[patternVertex2]
		assert(substituteVertex1, substituteVertex2)

		local substituteEdge = substitute.vertices[substituteVertex1][substituteVertex2]
		assert(substituteEdge)
	end

	-- Find out which vertices are 'modified', i.e. have new edges.

	local result = {
		pattern = pattern,
		substitute = substitute,
		map = map,
	}

	setmetatable(result, GraphGrammar.Rule)

	return result
end

local function _vertexEq( host, hostVertex, pattern, patterVertex )
	return hostVertex.tag == patterVertex.tag
end

function GraphGrammar.Rule:matches( graph )
	-- TODO: Need a tag restriction vertexEq and edgeEq predicates.
	local success, result = graph:matches(self.pattern, _vertexEq)

	return success, result
end

-- Match should be one of the members of a result array from the matches()
-- method. If not all bets are off and you better know what you're doing.
function GraphGrammar.Rule:replace( graph, match )



end