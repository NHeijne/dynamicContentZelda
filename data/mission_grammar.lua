local mission_grammar = {}

local lookup = require("data_lookup")

local table_util = require("table_util")
local log = require("log")

mission_grammar.planned_items = {
	
}

mission_grammar.available_keys = {

}

mission_grammar.available_barriers = {
	
}

-- keys as keys and the values are the barriers opened with it
mission_grammar.key_barrier_lookup = {
	["EQ"]=	{
			["sword__1"]={"bush"},
			["glove__1"]={"white_rock", "bush"},
			["glove__2"]={"black_rock"},
			["bomb_bag__1"]={"door_weak_block"}
			},
	["K"]=	{	
			["boss_key"]={"door_boss_key"},
			["dungeon_key"]={"door_small_key"}
			}
}


mission_grammar.key_types = 	{"K", "EQ"}
mission_grammar.barrier_types = {"L", "B", "OB", "NB", "S"}
mission_grammar.area_types = 	{"C", "P", "F", "PF", "CH", "T", "E"}
-- based on:
-- http://sander.landofsand.com/publications/Dormans_Bakkes_-_Generating_Missions_and_Spaces_for_Adaptable_Play_Experiences.pdf

-- Ideas for possible node types: 
-- ?:any node, 
-- EQ:new equipment, which unlocks B:barrier (use key_barriers lookups and available keys), 
-- OB:old barrier (hero should be able to open these based on the available keys list)
-- NB:new barrier (hero should be able to open this with an equipment piece found later in game)
-- K:key, unlocks L:lock
-- T:Task, which can turn into F:(mandatory) fight room, P:puzzle, E:empty room, PF: puzzle with enemies
-- CH:challenge room
-- S:secret transition, C:treasure chest room

-- graph grammar rules lookup where the keys are the rule numbers, and the values the left and right hand sides
-- grammar = [1]={prob=100, lhs={ nodes={[1]="T", [2]="T", [3]="T"}, edges={ [1]={ [2]="undir_fw" }, [2]={[3]="undir_fw"} } }, 
--							 rhs={ nodes={[1]="T", [2]="T", [3]="T"}, edges={ [1]={ [2]="undir_fw", [3]="undir_fw"} } } }
-- NOTE: Ensure that the lhs edges are connected from the [1] on, there is no recursive search for loose ends that have not been found before
mission_grammar.grammar = {
	-- 1 to 4 are the example rules from the paper
	-- reorganize tasks, creates a branch
 	[1]={ lhs={ nodes={[1]="T", [2]="T", [3]="T"}, edges={ [1]={ [2]="undir_fw" }, [2]={[3]="undir_fw"} } }, 
		  rhs={ nodes={[1]="T", [2]="T", [3]="T"}, edges={ [1]={ [2]="undir_fw", [3]="undir_fw"} } } },
	-- moving a lock forward and branching
	[2]={ lhs={ nodes={[1]="T", [2]="?", [3]="L"}, edges={ [1]={ [2]="undir_fw" }, [2]={[3]="undir_fw"} } }, 
		  rhs={ nodes={[1]="T", [2]="?", [3]="L"}, edges={ [1]={ [2]="undir_fw", [3]="undir_fw"} } } },
	-- create a key and lock in between two tasks
	[3]={ lhs={ nodes={[1]="T", [2]="T",		}, edges={ [1]={ [2]="undir_fw" } } }, 
		  rhs={ nodes={[1]="T", [2]="T", [3]="K", [4]="L"}, 
			    edges={ [1]={ [3]="undir_fw", [4]="undir_fw"}, [3]={[4]="dir_fw"}, [4]={[2]="undir_fw"} } } },	
	-- move key backwards by moving tasks from behind it's lock to in front of the key		
	[4]={ lhs={ nodes={[1]="K", [2]="L", [3]="T", [4]="T", [5]="?" }, 
		  	    edges={ [1]={ [2]="dir_fw", [5]="undir_bk" }, [2]={ [3]="undir_fw" }, [3]={ [4]="undir_fw" } } }, 
		  rhs={ nodes={[1]="K", [2]="L", [3]="T", [4]="T", [5]="?" }, 
			    edges={ [1]={ [2]="dir_fw" }, [2]={ [4]="undir_fw" }, [3]={ [1]="undir_fw" }, [5]={ [3]="undir_fw" } } } },	
	-----------------------------------------------------------------------------------------------
	-- new rules that utilize a new equipment piece			    
	-- create an new Equipment item and 1 barrier in between two tasks
	[5]={ lhs={ nodes={[1]="T", [2]="T",		  }, edges={ [1]={ [2]="undir_fw" } } }, 
		  rhs={ nodes={[1]="T", [2]="T", [3]="EQ", [4]="B"}, 
			    edges={ [1]={ [3]="undir_fw", [4]="undir_fw"}, [3]={[4]="dir_fw"}, [4]={[2]="undir_fw"} } } },
	-- move a barrier forward and cause branching				  
	[6]={ lhs={ nodes={[1]="T", [2]="?", [3]="B"}, edges={ [1]={ [2]="undir_fw" }, [2]={[3]="undir_fw"} } }, 
		  rhs={ nodes={[1]="T", [2]="?", [3]="B"}, edges={ [1]={ [2]="undir_fw", [3]="undir_fw"} } } },
	-- move an equiment piece back
	[7]={ lhs={ nodes={[1]="EQ", [2]="B", [3]="T", [4]="T", [5]="?" }, 
		  	    edges={ [1]={ [2]="dir_fw", [5]="undir_bk" }, [2]={ [3]="undir_fw" }, [3]={ [4]="undir_fw" } } }, 
		  rhs={ nodes={[1]="EQ", [2]="B", [3]="T", [4]="T", [5]="?" }, 
			    edges={ [1]={ [2]="dir_fw" }, [2]={ [4]="undir_fw" }, [3]={ [1]="undir_fw" }, [5]={ [3]="undir_fw" } } } },
	-- Add a Barier -> Secret passage -> Challenge -> Treasure -> Back to the room before secret passage
	[8]={ lhs={ nodes={[1]="EQ", [2]="T" 		}, edges={ [1]={ [2]="undir_bk" } } }, 
		  rhs={ nodes={[1]="EQ", [2]="T", [3]="B", [4]="S", [5]="CH", [6]="C"}, 
		  	 	edges={ [1]={ [2]="undir_bk", [3]="dir_fw" }, [2]={[3]="undir_fw"}, [3]={[4]="undir_fw"}, [4]={[5]="undir_fw"}, [5]={[6]="undir_fw"}, [6]={[2]="dir_fw"} } } },
	-- Randomly adding a barrier for an old equipment piece between tasks
	[9]={ lhs={ nodes={[1]="T", [2]="T", 		}, edges={ [1]={ [2]="undir_fw" } } }, 
		  rhs={ nodes={[1]="T", [2]="T", [3]="OB:?"}, edges={ [1]={ [2]="undir_fw"}, [1]={ [3]="undir_fw"}, [3]={ [2]="undir_fw"} } } },
	-------------------------------------------------------------------------------------------------
	-- Replacing nodes
	[10]={ lhs={ nodes={[1]="T"}, edges={} }, 
		   rhs={ nodes={[1]="F"}, edges={} } },
    [11]={ lhs={ nodes={[1]="T"}, edges={} }, 
		   rhs={ nodes={[1]="P"}, edges={} } },
	[12]={ lhs={ nodes={[1]="T"}, edges={} }, 
		   rhs={ nodes={[1]="PF"}, edges={} } },
	[13]={ lhs={ nodes={[1]="OB"}, edges={} }, 
		   rhs={ nodes={[1]="OB:?"}, edges={} } },
    [14]={ lhs={ nodes={[1]="T"}, edges={} }, 
		   rhs={ nodes={[1]="P"}, edges={} } },
	[15]={ lhs={ nodes={[1]="T"}, edges={} }, 
		   rhs={ nodes={[1]="PF"}, edges={} } },
	-------------------------------------------------------------------------------------------------
	-- rules that add to the example rules
}

-- start off with 3 node types, start, Expand_nodes * N, goal in that order
-- non_terminals = {2}, first in first out
-- nodes = {[1]="start", [2]="T", [3]="goal"}
-- edges = { [<lower_index>]={ [<higher_index>]={edge_type} } and [<higher_index>]={ [<lower_index>]={edge_type_reversed} } }
-- edge_types = dir_fw, dir_bk, undir_fw, undir_bk
-- we use the undirected forward and backward as a method of distinguishing edges which are in the space generation going to be two way transitions
-- so we can just check the pairs of any of the two which edges are available
-- all new nodes are placed at the end of the table
mission_grammar.produced_graph = {}

function mission_grammar.initialize_graph( task_length )
	local nodes = {[1]="start", [2]="E"}
	local edges = {[1]={[2]="undir_fw"}, [2]={[1]="undir_bk"}}
	local non_terminals = {2}
	for i=3, task_length+2 do
		nodes[i] = "T"
		edges[i-1]= edges[i-1] or {}
		edges[i-1][i]="undir_fw"
		edges[i]= edges[i] or {}
		edges[i][i-1]="undir_bk"
		table.insert(non_terminals, i)
	end
	edges[task_length+2][task_length+3]="undir_fw"
	edges[task_length+3]={[task_length+2]="undir_bk"}
	table.insert(nodes, "goal")
	mission_grammar.produced_graph = {nodes=nodes, edges=edges, non_terminals=non_terminals}
	log.debug("produced_graph")
	log.debug(mission_grammar.produced_graph)
end

function mission_grammar.update_keys_and_barriers( game )
	mission_grammar.available_keys = {}
	mission_grammar.available_barriers = {}
	local k = 0
	for item,data in pairs(lookup.items) do
		if game:get_value(item) then 
			k = k + 1
			mission_grammar.available_keys[k]=item
			table_util.add_table_to_table(mission_grammar.key_barrier_lookup["EQ"][item], mission_grammar.available_barriers)
		end
	end
end


-- what kind of map type are we producing
function mission_grammar.produce_graph( map_type, length, branches, puzzles, fights)
	mission_grammar.initialize_graph( length )
	if map_type == "dungeon" then

	elseif map_type == "outside_normal" then
		-- lets start off simple using nothing but tasks and branches
		for i=1, branches do
			local matches = mission_grammar.match( 1 )
			if next(matches) == nil then break end
			mission_grammar.apply_rule( matches[math.random(#matches)], 1 )
		end
		-- place barriers
		local bar = mission_grammar.available_barriers
		local bar_amount = #bar
		for i=1, math.floor(length/2) do
			local matches = mission_grammar.match( 9 )
			if next(matches) == nil then break end
			mission_grammar.apply_rule( matches[math.random(#matches)], 9, bar[math.random(bar_amount)] )
		end

		local puzzles_left = puzzles
		local fights_left = fights
		local options = {10, 11} -- 12 is both, but doesn't function yet
		for i=1, length do
			if fights_left == 0 and puzzles_left == 0 then break
			elseif fights_left == 0 then options = {11}
			elseif puzzles_left == 0 then options = {10} end
			local matches = mission_grammar.match( 10 )
			if next(matches) == nil then break end
			local selected_option= options[math.random(#options)]
			if selected_option==10 then fights_left=fights_left-1
			elseif selected_option==11 then puzzles_left=puzzles_left-1
			else 
				fights_left=fights_left-1
				puzzles_left=puzzles_left-1
			end
			mission_grammar.apply_rule( matches[math.random(#matches)], selected_option )
		end
	end
end

-- brute force matching of subset of graph
-- non-terminal and pattern node [1] should be the same otherwise skip
function mission_grammar.match( rule_number )
	-- check each non-terminal whether it is the starting point of the given pattern
	local pattern = mission_grammar.grammar[rule_number].lhs
	local matches = {}
	local nodes = mission_grammar.produced_graph.nodes
	local edges = mission_grammar.produced_graph.edges
	local non_terminals = mission_grammar.produced_graph.non_terminals
	for _,nt in ipairs(non_terminals) do
		local split_node = table_util.split(nodes[nt], ":")
		local split_node_pattern = table_util.split(pattern.nodes[1], ":")
		if split_node[1] == split_node_pattern[1] and (split_node[2] == nil or split_node[2] == split_node_pattern[2]) then 
			log.debug("starting recursive_search on node "..nt)
			local new_matches = mission_grammar.recursive_search( nodes, edges, pattern, {[1]=nt}, {[1]=nt})
			if new_matches then table_util.add_table_to_table(new_matches, matches) end
		end
	end
	return matches
end

function mission_grammar.recursive_search( nodes, edges, pattern, candidates, current_match)
	log.debug("candidates")
	log.debug(candidates)
	local new_candidates = {}
	for pattern_index, candidate in pairs(candidates) do
		log.debug("pattern_index")
		log.debug(pattern_index)
		log.debug("candidate")
		log.debug(candidate)
		if pattern.edges[pattern_index] ~= nil then
			log.debug("edges found for pattern_index in pattern")
			log.debug(pattern.edges[pattern_index])
			log.debug("existing edges")
			log.debug(edges)
			log.debug("existing nodes")
			log.debug(nodes)
			for index,edge in pairs(pattern.edges[pattern_index]) do -- pattern edges
				local found = false
				for i,v in pairs(edges[candidate]) do -- existing edges
					log.debug("checking existing edge "..candidate.." to "..i)
					-- we need to check whether the edge and the non-terminal type 
					-- are the same for each node connected to the current node
					local split_node = table_util.split(nodes[i], ":")
					local split_node_pattern = table_util.split(pattern.nodes[index], ":")
					if edge == v and (pattern.nodes[index]== "?" or split_node[1] == split_node_pattern[1]) and (split_node[2]==nil or split_node[2] == split_node_pattern[2]) then 
						-- edge types and node types are the same 
						log.debug("found a node that is connected in the right way")
						log.debug("candidate "..candidate.." is connected with "..edge.." to node "..i)
						-- we have found our next candidate for the current node index
						-- add to result list
						if current_match[index] == nil then 
							-- if we didn't have this match before we have found a new candidate for that position
							found = true
							if not table_util.contains(new_candidates[index], i) then
								new_candidates[index] = new_candidates[index] or {}
								table.insert(new_candidates[index], i)
							end
						elseif current_match[index] == i then
							-- if we have found the match before for that index, then it should be that number again, not some other node
							found = true
							break
						end
					end
				end
				if not found then 
					log.debug("did not find any edges that had the required type")
					log.debug("returning false, going backward")
					return false 
				end
			end
		end
	end
	log.debug("finished checking the candidates")
	log.debug(new_candidates)
	if next(new_candidates) == nil then
		log.debug("new_candidates is empty returning candidates")
		return {candidates}
	else
		-- after checking each edge and connected node in the current node index
		-- we go into the recursion
		-- after creating a combination list of the found candidates
		log.debug("creating combinations")
		local combinations = table_util.combinations(new_candidates)
		log.debug("creating combinations done")
		log.debug(table_util.tostring(combinations))
		local result = {}
		local r = 0
		for nr,combi in ipairs(combinations) do
			local new_match = table_util.union(current_match, combi)
			local output = mission_grammar.recursive_search( nodes, edges, pattern, combi, new_match)
			if output then
				for _, out in ipairs(output) do
				log.debug(candidates)
				log.debug("+")
				log.debug(out)
				log.debug("becomes")
				-- output is good, so we create an entry in the results containing every used node on the right position
				r = r+1
				result[r] = {}
				for k,v in pairs(candidates) do result[r][k]=v end
				for k,v in pairs(out) do result[r][k]=v end
				log.debug(result[r])
				end
			else
				-- skip that output
			end
		end
		log.debug("result")
		log.debug(result)
		-- if there are no nodes added because the recursion didn't find anything then we can conclude that we didn't find anything
		if next(result)==nil then return false end
		return result
	end
end

function mission_grammar.apply_rule( match, rule_number, custom_terminal )
	log.debug("applying rule number "..rule_number)
	log.debug("using match:")
	log.debug(match)
	rule = mission_grammar.grammar[rule_number]
	-- remove the listed connections in the lhs from edges
	for index_from, v in pairs(rule.lhs.edges) do
		for index_to, _ in pairs(v) do
			log.debug(index_from.." to "..index_to)
			mission_grammar.produced_graph.edges[match[index_from]][match[index_to]]=nil
			mission_grammar.produced_graph.edges[match[index_to]][match[index_from]]=nil
		end
	end
	-- replace nodes if necessary
	for i=1, #rule.lhs.nodes, 1 do
		local split_lhs_node = table_util.split(mission_grammar.produced_graph.nodes[match[i]], ":")
		if not (rule.rhs.nodes[i] == "?" or split_lhs_node[1] == rule.rhs.nodes[i]) then -- NT:term --> NT results in NT:term // NT --> NT:term goes through
			local split_node = table_util.split(rule.rhs.nodes[i], ":")
			if split_node[2] == "?" then mission_grammar.produced_graph.nodes[match[i]]=split_node[1]..":"..custom_terminal	-- NT:? --> NT:custom_terminal		
			else mission_grammar.produced_graph.nodes[match[i]]=rule.rhs.nodes[i] end -- NT:term1 --> NT2 or NT:term2 // NT1 --> NT2
		end
	end
	-- create new node in nodes if keys of lhs and rhs are different, we are not removing nodes only adding and replacing
	local used_nodes = table_util.copy(match)
	for i=#rule.lhs.nodes+1, #rule.rhs.nodes, 1 do
		local split_node = table_util.split(rule.rhs.nodes[i], ":")
		if split_node[2] == "?" then table.insert(mission_grammar.produced_graph.nodes, split_node[1]..":"..custom_terminal)
		else table.insert(mission_grammar.produced_graph.nodes, rule.rhs.nodes[i]) end
		local last_node = #mission_grammar.produced_graph.nodes
		table.insert(mission_grammar.produced_graph.non_terminals, last_node)
		used_nodes[i] = last_node
	end
	log.debug("used_nodes")
	log.debug(used_nodes)
	-- create new edges by applying the rhs edges
	for index_from, v in pairs(rule.rhs.edges) do
		log.debug(v)
		for index_to, edge in pairs(v) do
			mission_grammar.produced_graph.edges[used_nodes[index_from]] = mission_grammar.produced_graph.edges[used_nodes[index_from]] or {}
			mission_grammar.produced_graph.edges[used_nodes[index_from]][used_nodes[index_to]]=edge
			mission_grammar.produced_graph.edges[used_nodes[index_to]] = mission_grammar.produced_graph.edges[used_nodes[index_to]] or {}
			mission_grammar.produced_graph.edges[used_nodes[index_to]][used_nodes[index_from]]=mission_grammar.inverse(edge)
		end
	end
end

function mission_grammar.inverse(edge)
	if 		edge == "undir_fw" then return "undir_bk"
	elseif 	edge == "undir_bk" then return "undir_fw"
	elseif 	edge == "dir_fw" then return "dir_bk"
	elseif 	edge == "dir_bk" then return "dir_fw" 
	end
end

-- local area_details = {	nr_of_areas=nr_of_areas, -- 
-- 							tileset_id=1, -- tileset id, light world
-- 							outside=true,
-- 							from_direction="west",
-- 							to_direction="east",
-- 							preferred_area_surface=preferred_area_surface, 
-- 							[1]={	area_type="empty",--area_type
-- 									shape_mod=nil, --shape_modifier 
-- 									transition_details=nil, --"transistion <map> <destination>"
-- 									nr_of_connections=1,
-- 									[1]={ type="twoway", areanumber=2, direction="south"}
-- 								}
-- 						  }

function mission_grammar.transform_to_space( params )
	if params.merge then

	else -- a task is one area
		-- transform nodes into area details
		-- initialize the table with the parameters
		log.debug("graph_transform")
		local area_details = {	nr_of_areas=0, -- 
								tileset_id=params.tileset_id, -- tileset id, light world
								outside=params.outside,
								from_direction=params.from_direction,
								to_direction=params.to_direction,
								preferred_area_surface=params.preferred_area_surface,
								path_width=params.path_width 
							  }
		if params.outside then area_details.wall_width = 0
		else area_details.wall_width = 24 end -- dungeon wall = (wall 24)
		local graph = mission_grammar.produced_graph
		local visited_nodes = {}
		local area_assignment = {}
		local areas_assigned = 0
		-- for each node in the graph we check in forward direction
		for index, node in ipairs(graph.nodes) do
			-- but only if the current node is an area, and not a modifier or start or goal TODO integrate start and goal transitions
			if visited_nodes[index] == nil and table_util.contains(mission_grammar.area_types, node) then
				visited_nodes[index]=true
				if area_assignment[index] == nil then
					areas_assigned = areas_assigned +1
					area_assignment[index] = areas_assigned
				end
				local areanumber = area_assignment[index]
				-- initialize the area
				area_details[areanumber]={area_type=node, nr_of_connections=0, contains_items={}}
				local current_area = area_details[areanumber]
				for k,v in pairs(graph.edges[index]) do
					-- now for every edge that that node has we make a connection
					if (v == "undir_fw" or v == "dir_fw") then -- only in forward direction
						local connected_node = graph.nodes[k]
						local split_node = table_util.split(connected_node, ":")
						log.debug("edge "..index.."-->"..k.." "..v)
						log.debug(connected_node)
						log.debug(split_node)
						if table_util.contains(mission_grammar.area_types, split_node[1]) then
							log.debug("new area found")
							-- it's an area: look no further, assign the area an area number and continue
							current_area.nr_of_connections=current_area.nr_of_connections+1
							if area_assignment[k] == nil then
								areas_assigned = areas_assigned +1
								area_assignment[k] = areas_assigned
							end
							local connection = "twoway"
							if v == "dir_fw" then connection = "oneway" end
							current_area[current_area.nr_of_connections] = {type=connection, areanumber=area_assignment[k]}
						elseif table_util.contains(mission_grammar.barrier_types, split_node[1]) then
							log.debug("barrier found, searching for next area")
							-- it's a barrier type, that means that after this should eventually come a single area
							current_area.nr_of_connections=current_area.nr_of_connections+1
							current_area[current_area.nr_of_connections] = {barriers={connected_node}}
							local next_node_id=k
							local done = false
							repeat
								-- so let's look for that area
								for connected_node_id,edge in pairs(graph.edges[next_node_id]) do
									local possible_next_node = table_util.split(graph.nodes[connected_node_id], ":")
									if edge == "undir_fw" or edge == "dir_fw" then
										log.debug("edge "..next_node_id.."-->"..connected_node_id.." "..edge)
										-- ofcourse only check in forward direction
										if table_util.contains(mission_grammar.area_types, possible_next_node[1]) then
											-- we found it, now we add it like any normal connection
											if area_assignment[connected_node_id] == nil then
												areas_assigned = areas_assigned +1
												area_assignment[connected_node_id] = areas_assigned
											end
											local connection = "twoway"
											if v == "dir_fw" then connection = "oneway" end
											current_area[current_area.nr_of_connections].type=connection
											current_area[current_area.nr_of_connections].areanumber=area_assignment[connected_node_id]
											done = true
										elseif table_util.contains(mission_grammar.barrier_types, possible_next_node[1]) then
											-- we found another barrier, okay add that to the list
											-- also update our current node
											next_node_id= connected_node_id
											-- we add a barrier to the list
											visited_nodes[connected_node_id]=true
											table.insert(current_area[current_area.nr_of_connections].barriers, graph.nodes[connected_node_id])
										end
									end
								end
							until done
							log.debug("next area found")
						elseif table_util.contains(mission_grammar.key_types, split_node[1]) then
							log.debug("key area mod found")
							-- a key type is a modifier for the area, not a connection
							visited_nodes[k]=true
							-- so we add the specific key type
							table.insert(current_area.contains_items, connected_node)
						end
					end
				end
			end
		end
		area_details.nr_of_areas=areas_assigned
		return area_details
	end
end

function mission_grammar.update_grammar()
	-- body
end

return mission_grammar