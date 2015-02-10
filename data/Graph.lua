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


--
-- Graph.lua
--
-- An incidence list based graph data structure.
-- There should be nothing game specific in here if possible.
--
-- Simple loops (vertex with an edge to itself) are not allowed.
--
-- Graph = {
--     vertices = {
--         [vertex] = { [vertex] = edge }*
--     }*,
--     edges = {
--         [edge] = { vertex1, vertex2 }
--     }*
-- }
--


Graph = {}
Graph.__index = Graph

function Graph.new( vertices, edges )
	vertices = vertices or {}
	edges = edges or {}

	local valences = {}

	for vertex, peers in pairs(vertices) do
		valences[vertex] = table.count(peers)
	end

	local result = {
		vertices = vertices,
		edges = edges,
		valences = valences,
	}

	setmetatable(result, Graph)

	result:_invariant()

	return result
end

function Graph:_invariant()
	local vertices = self.vertices
	local edges = self.edges
	local valences = self.valences

	-- 1. Vertices are connected to other vertices by edges.
	for vertex, peers in pairs(vertices) do
		for peer, edge in pairs(peers) do
			assert(vertices[peer])
			assert(edges[edge])
		end
		assert(valences[vertex] == table.count(peers))
	end

	-- 2. Edges are connected to two distinct vertices.
	for edge, endverts in pairs(edges) do
		local vertex1, vertex2 = endverts[1], endverts[2]

		assert(vertex1)
		assert(vertex2)
		assert(vertex1 ~= vertex2)
		assert(vertices[vertex1])
		assert(vertices[vertex2])
	end
end

function Graph:isPeer( vertex1, vertex2 )
	assert(self.vertices[vertex1])
	assert(self.vertices[vertex2])

	return self.vertices[vertex1][vertex2] ~= nil
end

function Graph:addVertex( vertex )
	assert(self.vertices[vertex] == nil)

	self.vertices[vertex] = {}
	self.valences[vertex] = 0

	return vertex
end

function Graph:removeVertex( vertex )
	local vertices = self.vertices
	local edges = self.edges
	local valences = self.valences
	local peers = vertices[vertex]

	if peers then
		for peer, edge in pairs(peers) do
			edges[edge] = nil
			vertices[peer][vertex] = nil
		end

		vertices[vertex] = nil
		valences[vertex] = nil
	end
end

function Graph:addEdge( edge, vertex1, vertex2 )
	local vertices = self.vertices
	local valences = self.valences
	local peers1 = vertices[vertex1]
	local peers2 = vertices[vertex2]

	assert(self.edges[edge] == nil)
	assert(vertex1 ~= vertex2) -- No loops.
	assert(peers1 ~= nil and peers1[vertex2] == nil)
	assert(peers2 ~= nil and peers2[vertex1] == nil)
	
	self.edges[edge] = { vertex1, vertex2 }
	peers1[vertex2] = edge
	peers2[vertex1] = edge
	valences[vertex1] = valences[vertex1] + 1
	valences[vertex2] = valences[vertex2] + 1
end

function Graph:removeEdge( edge )
	local edges = self.edges
	local endverts = edges[edge]

	if endverts then
		local vertices = self.vertices
		local valences = self.valences
		local vertex1, vertex2 = endverts[1], endverts[2]

		vertices[vertex1][vertex2] = nil
		vertices[vertex2][vertex1] = nil

		valences[vertex1] = valences[vertex1] - 1
		valences[vertex2] = valences[vertex2] - 1

		edges[edge] = nil
	end
end

function Graph:merge( other )
	for vertex, peers in pairs(other.vertices) do
		self.vertices[vertex] = peers
	end

	for edge, endverts in pairs(other.edges) do
		self.edges[edge] = endverts
	end

	-- This could be made more efficient...
	local valences = {}

	for vertex, peers in pairs(self.vertices) do
		valences[vertex] = table.count(peers)
	end

	self.valences = valences
end

-- This should be more efficient that distanceMap(), especially if queue
-- is reused between runs.
function Graph:dmap( source, maxdepth )
	maxdepth = maxdepth or math.huge

	local vertices = self.vertices
	assert(vertices[source])

	local result = { [source] = 0 }
	local queue = { source }

	local index = 1
	local depth = 0

	while index <= #queue and depth < maxdepth do
		depth = depth + 1

		local frontier = #queue

		while index <= frontier do
			local vertex = queue[i]

			for peer, _ in pairs(vertices[vertex]) do
				if not result[peer] then
					result[peer] = depth
					queue[#queue+1] = peer
				end
			end

			index = index + 1
		end
	end

	return result
end

-- TODO: If we could avoid the allocations of all but the result that would be cool
function Graph:distanceMap( source, maxdepth )
	maxdepth = maxdepth or math.huge

	local vertices = self.vertices
	assert(vertices[source])

	local result = { [source] = 0 }
	local frontier = { [source] = true }
	local depth = 0

	while depth < maxdepth and next(frontier) do
		depth = depth + 1
		local newFrontier = {}

		for vertex, _ in pairs(frontier) do
			for peer, _ in pairs(vertices[vertex]) do
				if not frontier[peer] and not result[peer] then
					result[peer] = depth
					newFrontier[peer] = true
				end
			end
		end

		frontier = newFrontier
	end

	return result
end

-- Floyd-Warshall, for sparse graphs it would be more efficient to use a
-- breadth first traversal from each vertex.
function Graph:allPairsShortestPaths()
	local result = {}

	local vertices = self.vertices

	for vertex1, peers in pairs(vertices) do
		local weights = {}

		for vertex2, _ in pairs(vertices) do
			if vertex1 == vertex2 then
				weights[vertex2] = 0
			elseif peers[vertex2] then
				-- If we need weights here's where to insert them.
				weights[vertex2] = 1
			else
				weights[vertex2] = math.huge
			end
		end

		result[vertex1] = weights
	end

	for k in pairs(vertices) do
		for i in pairs(vertices) do
			for j in pairs(vertices) do
				result[i][j] = math.min(result[i][j], result[i][k] + result[k][j])
			end
		end
	end

	return result
end

-- TODO: Brandes algorithm would probably be better.
function Graph:betweenness()
	local paths = self:allPairsShortestPaths()
	local vertices = self.vertices

	local result = {}
	local eccentricities = {}
	local radius = math.huge
	local diameter = 0

	local maxtotal = 0
	local numVertices = table.count(vertices)
	local norm = (numVertices - 1) * (numVertices - 2) * 0.5

	for s in pairs(vertices) do
		local total = 0
		local eccentricity = 0

		for t in pairs(vertices) do
			for u in pairs(vertices) do
				assert(paths[t][u] == paths[u][t])

				if paths[t][u] == paths[t][s] + paths[s][u] and s ~= t and s ~= u and t ~= u then
					total = total + 1
				end
			end
			
			eccentricity = math.max(paths[s][t], eccentricity)
		end
		
		assert(total % 2 == 0)
		total = total * 0.5

		print(s, numVertices, norm, total)
		assert(total <= norm)

		result[s] = total / norm
		eccentricities[s] = eccentricity
		radius = math.min(radius, eccentricity)
		diameter = math.max(diameter, eccentricity)
		maxtotal = math.max(total, maxtotal)
	end

	-- print('maxtotal', maxtotal)

	-- if maxtotal > 0 then
	-- 	for vertex, value in pairs(result) do
	-- 		result[vertex] = value / maxtotal
	-- 	end
	-- end

	return result, eccentricities, radius, diameter
end

local _defaultVertexEq = 
	function ( host, hostVertex, pattern, patternVertex )
		return true
	end

local _defaultEdgeEq = 
	function (  host, hostVertex, pattern, patternVertex )
		return true
	end

-- Finds all matching pattern subgraphs in the self/host graph.
--
-- Subgraph isomorphism based on J. R. Ullmann's 'An Algorithm for Subgraph
-- Isomorphism'. Extended to accept a vertex and edge equality functions as
-- optional arguments.
--
-- There is a planar subgraph isomorphism algorithm with far better asymptotic
-- bounds (Eppstein 'Subgraph Isomorphism in Planar Graphs and Related
-- Problems') but it's far more complicated.
--
-- Returns false if there's no matches.
--
-- Returns true, matches: matches is an array of pattern to host vertex maps.
--
-- TODO: Ullmann's algorithm has a 'refine' step that isn;t currently
--       implemented in this version.
function Graph:matches( pattern, vertexEq, edgeEq )
	vertexEq = vertexEq or _defaultVertexEq
	edgeEq = edgeEq or _defaultEdgeEq

	-- The algorithm is a brute force search with a few additions to cut down
	-- on the amount of work done.

	-- The graph being enumerated is commonly called the host graph.
	local host = self

	-- Map from pattern vertices to host vertices that could potentially form
	-- a subgraph. Used to cut down the amount of enumeration.
	local potentials = {}

	local hostValences = host.valences
	local patternValences = pattern.valences

	for patternVertex, _ in pairs(pattern.vertices) do
		local patternValence = patternValences[patternVertex]
		local array = {}

		for hostVertex, hostValence in pairs(hostValences) do
			-- If the host vertex has less peers than the pattern vertex a
			-- match is impossible.
			if hostValence >= patternValence and vertexEq(host, hostVertex, pattern, patternVertex) then
				array[#array+1] = hostVertex
			end
		end

		-- We if there is no host vertex that can be potentially matched to a
		-- pattern vertex, there's no hope of any matches being found.
		if #array == 0 then
			return false
		end

		potentials[#potentials+1] = {
			patternVertex = patternVertex,
			hostVertices = array,
		}
	end

	-- Now we perform a backtracking tree search in an attempt to create all
	-- 1-to-1 maps (bijections) from pattern vertices to host vertices. We use
	-- the potentials table to limit the maps we try and create to only those
	-- that have a chance to succeed.
	--
	-- If we manage to get such a map we then check if the edges in the pattern
	-- are present in the host. If they are we have found a subgraph! Add the
	-- mapping to the result and carry on.

	local result = {}
	local maxDepth = #potentials
	local depth = 1
	
	-- Brute force, backtracking tree search needs a stack to hold intermediate
	-- state.
	local stack = {}

	for index = 1, #potentials do
		local frame = {
			nextChoiceIndex = 1,
			choices = potentials[index].hostVertices,
			patternVertex = potentials[index].patternVertex,
			hostVertex = nil,
		}
		stack[index] = frame
	end

	while true do
		local frame = stack[depth]
		local choices = frame.choices
		local choice

		for choiceIndex = frame.nextChoiceIndex, #choices do
			choice = choices[choiceIndex]

			-- Does the choice conflict with a previous choice?
			for index = 1, depth-1 do
				local ancestor = stack[index]
				if choice == ancestor.hostVertex then
					choice = nil
					break
				end
			end

			if choice then
				frame.nextChoiceIndex = choiceIndex + 1
				break
			end
		end

		if choice then
			frame.hostVertex = choice

			-- Have we got a mapping for each pattern vertex?
			if depth < maxDepth then
				depth = depth + 1
			else
				-- pattern -> host vertex map.
				local map = {}

				for index = 1, #stack do
					local frame = stack[index]
					map[frame.patternVertex] = frame.hostVertex
				end

				local success = true

				-- Do all pattern vertices that share an edge also share an
				-- edge in the host graph?
				for patternEdge, patternEdgeEnds in pairs(pattern.edges) do
					local patternVertex1, patternVertex2 = patternEdgeEnds[1], patternEdgeEnds[2]

					local hostVertex1, hostVertex2 = map[patternVertex1], map[patternVertex2]
					assert(hostVertex1, hostVertex2)

					local hostEdge = host.vertices[hostVertex1][hostVertex2]

					if not hostEdge or not edgeEq(host, hostEdge, pattern, patternEdge) then
						success = false
						break
					end
				end

				if success then
					result[#result+1] = map
				end
			end
		else
			-- No choices at depth 1 means we're at the end!
			if depth == 1 then
				return #result > 0, result
			else
				-- No choices si signified by the nextChoiceIndex being greater
				-- than the choices array.
				frame.nextChoiceIndex = #choices + 1

				-- We need to unwind.
				for index = depth, 1, -1 do
					depth = index

					local frame = stack[index]
					frame.hostVertex = nil

					-- If there are still possible choices stay at this depth.
					if frame.nextChoiceIndex <= #frame.choices then
						break
					-- If there are no more choices reset the nextChoiceIndex
					-- but not at depth 1 or we'll loop forever.
					elseif index ~= 1 then
						frame.nextChoiceIndex = 1
					end
				end
			end
		end
	end
end

-- if arg then
-- 	local test = Graph.new()
-- 	test:addVertex(1)
-- 	test:addVertex(2)
-- 	test:addVertex(3)
-- 	test:addVertex(4)

-- 	test:addEdge({}, 1, 2)
-- 	test:addEdge({}, 1, 3)
-- 	test:addEdge({}, 1, 4)

-- 	local path = test:allPairsShortestPaths()

-- 	for i, weights in pairs(path) do
-- 		for j, distance in pairs(weights) do
-- 			print(i, j, distance)
-- 		end
-- 	end

-- 	print()

-- 	local betweenness = test:betweenness()

-- 	for vertex, centrality in pairs(betweenness) do
-- 		print(vertex, centrality)
-- 	end


--  --    local a = { tag = 'a' }
-- 	-- local b = { tag = 'b' }
	
-- 	-- local host = Graph.new()
-- 	-- host:addVertex(a)
-- 	-- host:addVertex(b)
	
-- 	-- host:addEdge({}, a, b)
	
-- 	-- local x = { tag = 'x' }
-- 	-- local y = { tag = 'y' }
	
-- 	-- local pattern = Graph.new()
-- 	-- pattern:addVertex(x)
-- 	-- pattern:addVertex(y)
	
-- 	-- pattern:addEdge({}, x, y)
	
-- 	-- local success, result = host:matches(pattern)

-- 	-- print(success)
-- 	-- if result then
-- 	-- 	table.print(result)
-- 	-- end

-- 	-- a -- b -- c
-- 	-- |    |    |
-- 	-- d -- e -- f

-- 	local a = { tag = 'a' }
-- 	local b = { tag = 'b' }
-- 	local c = { tag = 'c' }
-- 	local d = { tag = 'd' }
-- 	local e = { tag = 'e' }
-- 	local f = { tag = 'f' }

-- 	local host = Graph.new()
-- 	host:addVertex(a)
-- 	host:addVertex(b)
-- 	host:addVertex(c)
-- 	host:addVertex(d)
-- 	host:addVertex(e)
-- 	host:addVertex(f)

-- 	host:addEdge({}, a, b)
-- 	host:addEdge({}, b, c)
-- 	host:addEdge({}, d, e)
-- 	host:addEdge({}, e, f)
-- 	host:addEdge({}, a, d)
-- 	host:addEdge({}, b, e)
-- 	host:addEdge({}, c, f)

-- 	-- x -- y
-- 	-- |    |
-- 	-- z -- w

-- 	local x = { tag = 'x' }
-- 	local y = { tag = 'y' }
-- 	local z = { tag = 'z' }
-- 	local w = { tag = 'w' }
	
-- 	local pattern = Graph.new()
-- 	pattern:addVertex(x)
-- 	pattern:addVertex(y)
-- 	pattern:addVertex(z)
-- 	pattern:addVertex(w)

-- 	pattern:addEdge({}, x, y)
-- 	pattern:addEdge({}, x, z)
-- 	pattern:addEdge({}, z, w)
-- 	pattern:addEdge({}, y, w)
	
-- 	local success, result = host:matches(pattern)

-- 	assert(success)
-- 	assert(#result == 16)

-- 	print(success)
-- 	if success then
-- 		for _, map in ipairs(result) do
-- 			local ps = {}
-- 			local hs = {}

-- 			for p, h in pairs(map) do
-- 				ps[#ps+1] = p.tag
-- 				hs[#hs+1] = h.tag
-- 			end

-- 			printf('%s:%s', table.concat(ps), table.concat(hs))
-- 		end
-- 	end

-- 	print(#result)
-- end

return Graph










