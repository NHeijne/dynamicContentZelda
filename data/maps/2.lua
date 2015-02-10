local map = ...
local game = map:get_game()
local log = require("log")
local table_util = require("table_util")
local mission_grammar = require("mission_grammar")

-- data lookups

-- use the same as prop lookup
local transition_area_lookup = 
{
	["cave_stairs_1"] = 		{required_size={x=32, y=48},
								 [{x1=0, y1=0, x2=8, y2=2*16}]={[1]=865}, 
								 [{x1=8, y1=0, x2=8+16, y2=8}]={[1]=867},
								 [{x1=8+16, y1=0, x2=2*16, y2=2*16}]={[1]=866},
								 [{x1=8, y1=8, x2=8+16, y2=2*16}]={[1]=868}
								 },

	["edge_stairs_1"] = 	    {required_size={x=48, y=24},
								 [{x1=0, y1=0, x2=16, y2=24, layer=0}]={[4]=49}, 
								 [{x1=32, y1=0, x2=48, y2=24, layer=0}]={[4]=49}, 
								 [{x1=8, y1=0, x2=40, y2=8, layer=1}]={[4]=152}, 
								 [{x1=8, y1=8, x2=16, y2=24, layer=0}]={[4]=72},
								 [{x1=16, y1=8, x2=32, y2=24, layer=0}]={[4]=192},
								 [{x1=32, y1=8, x2=40, y2=24, layer=0}]={[4]=73}},
	["edge_stairs_3"] = 		{required_size={x=48, y=24},
								 [{x1=0, y1=0, x2=16, y2=24, layer=0}]={[4]=52}, 
								 [{x1=32, y1=0, x2=48, y2=24, layer=0}]={[4]=52}, 
							     [{x1=8, y1=0, x2=16, y2=16, layer=0}]={[4]=74}, 
								 [{x1=16, y1=0, x2=32, y2=16, layer=0}]={[4]=196},
								 [{x1=32, y1=0, x2=40, y2=16, layer=0}]={[4]=75},
								 [{x1=8, y1=16, x2=40, y2=24, layer=1}]={[4]=153}},
	 ["edge_stairs_2"] = 	    {required_size={x=64, y=24},
								 [{x1=0, y1=0, x2=24, y2=24, layer=0}]={[4]=49}, 
								 [{x1=40, y1=0, x2=64, y2=24, layer=0}]={[4]=49}, 
								 [{x1=0, y1=0, x2=32, y2=8, layer=1}]={[4]=152}, 
								 [{x1=0, y1=8, x2=8, y2=24, layer=0}]={[4]=72},
								 [{x1=8, y1=8, x2=24, y2=24, layer=0}]={[4]=192},
								 [{x1=24, y1=8, x2=32, y2=24, layer=0}]={[4]=73}},
	["edge_stairs_4"] = 		{required_size={x=64, y=24},
								 [{x1=0, y1=0, x2=24, y2=24, layer=0}]={[4]=52}, 
								 [{x1=40, y1=0, x2=64, y2=24, layer=0}]={[4]=52}, 
							     [{x1=0, y1=0, x2=8, y2=16, layer=0}]={[4]=74}, 
								 [{x1=8, y1=0, x2=8+16, y2=16, layer=0}]={[4]=196},
								 [{x1=8+16, y1=0, x2=2*16, y2=16, layer=0}]={[4]=75},
								 [{x1=0, y1=16, x2=32, y2=24, layer=1}]={[4]=153}}
}

local tile_lookup =
{
	["maze_wall_hor"]={[1]=1016, [4]=70},
	["maze_wall_ver"]={[1]=1016, [4]=71},
	["maze_post"]={[1]=1016, [4]=69},
	["dungeon_floor"]={[4]=328},
	["dungeon_spacer"]={[4]=170},
	["pot_stand"]={[4]=101},
	["debug_corner"]={[1]=63, [4]=327}
}

local wall_tiling_lookup =
{
	["dungeon"]={["wall"]={["n"]=49, ["e"]=50, ["w"]=51, ["s"]=52},
				 ["wall_inward_corner"]={["nw"]=45, ["ne"]=46, ["sw"]=47, ["se"]=48},
				 ["wall_outward_corner"]={["nw"]=53, ["ne"]=54, ["sw"]=55, ["se"]=56},
				 ["floor_edge"]={["n"]=179, ["e"]=238, ["w"]=237, ["s"]=236},
				 ["floor_edge_inward_corner"]={["nw"]=14, ["ne"]=15, ["sw"]=16, ["se"]=17},
				 ["floor_edge_outward_corner"]={["nw"]=239, ["ne"]=240, ["sw"]=241, ["se"]=242}
				}
}

local prop_lookup = 
{
	["green_tree"]= { required_size={x=64, y=64},
					 [{x1=0, y1=-8, x2=8, y2=4*8, layer=2}]=513, -- left canopy
					 [{x1=8, y1=-16, x2=7*8, y2=0, layer=2}]=512, -- top canopy
					 [{x1=8, y1=0, x2=7*8, y2=5*8, layer=2}]=511, -- middle canopy
					 [{x1=7*8, y1=-8, x2=8*8, y2=4*8, layer=2}]=514, -- right canopy
					 [{x1=0, y1=4*8, x2=8, y2=6*8, layer=0}]=503, --left trunk
					 [{x1=7*8, y1=4*8, x2=8*8, y2=6*8, layer=0}]=504, -- right trunk
					 [{x1=8, y1=5*8, x2=7*8, y2=7*8, layer=0}]=505, -- middle trunk
					 [{x1=16, y1=7*8, x2=6*8, y2=8*8, layer=0}]=523, -- bottom trunk
					 [{x1=8, y1=0, x2=7*8, y2=5*8, layer=0}]=502}, -- wall
	["small_green_tree"]={[{x1=0, y1=0, x2=32, y2=32, layer=0}]=526, required_size={x=32, y=32}},
	["small_lightgreen_tree"]={[{x1=0, y1=0, x2=32, y2=32, layer=0}]=527, required_size={x=32, y=32}},
	["tree_stump"]={[{x1=0, y1=0, x2=32, y2=32, layer=0}]=630, required_size={x=32, y=32}},
	["flower1"]={[{x1=0, y1=0, x2=16, y2=16, layer=0}]=42, required_size={x=16, y=16}},
	["flower2"]={[{x1=0, y1=0, x2=16, y2=16, layer=0}]=43, required_size={x=16, y=16}},
	["halfgrass"]={[{x1=0, y1=0, x2=16, y2=16, layer=0}]=36, required_size={x=16, y=16}},
	["fullgrass"]={[{x1=0, y1=0, x2=16, y2=16, layer=0}]=37, required_size={x=16, y=16}},
	["hole"] = {[{x1=0, y1=0, x2=16, y2=16, layer=0}]=825, required_size={x=16, y=16}},
	["impassable_rock_16x16"] = { 	[{x1=0, y1=0, x2=8, y2=8, layer=0}]=288, 
									[{x1=8, y1=0, x2=16, y2=8, layer=0}]=287, 
									[{x1=0, y1=8, x2=8, y2=16, layer=0}]=286, 
									[{x1=8, y1=8, x2=16, y2=16, layer=0}]=285, 
									required_size={x=16, y=16}},
	["impassable_rock_32x16"] = { 	[{x1=0, y1=0, x2=8, y2=8, layer=0}]=284, 
									[{x1=24, y1=0, x2=32, y2=8, layer=0}]=283, 
									[{x1=0, y1=8, x2=8, y2=16, layer=0}]=282, 
									[{x1=24, y1=8, x2=32, y2=16, layer=0}]=281,
									[{x1=8, y1=0, x2=24, y2=8, layer=0}]=265, 
									[{x1=8, y1=8, x2=24, y2=16, layer=0}]=266,
									required_size={x=32, y=16}},
	["impassable_rock_16x32"] = { 	[{x1=0, y1=0, x2=8, y2=8, layer=0}]=288, 
									[{x1=8, y1=0, x2=16, y2=8, layer=0}]=287, 
									[{x1=0, y1=24, x2=8, y2=32, layer=0}]=286, 
									[{x1=8, y1=24, x2=16, y2=32, layer=0}]=285,
									[{x1=0, y1=8, x2=8, y2=24, layer=0}]=273, 
									[{x1=8, y1=8, x2=16, y2=24, layer=0}]=274,
									required_size={x=16, y=32}},
}

function map:on_started(destination)
	log.debug_log_reset()
	hero:freeze()
	if not game:get_value("b30") then hero:start_treasure("sword", 1, "b30") end
	-- Initialize the pseudo random number generator
	local seed = 
			768279 -- testing dungeon lay-out
			--300536 -- bug in direct transition check -- it was out of range
			--842844 -- testing spread internal
			--136539 -- Bug forest
			--474129 -- long roads example TODO some bugs with the forest lay-out
			--150560 -- directly connected
			--514394 -- good seed for indirect transitions
			--949056 -- lengthy and curvy transitions
			tonumber(tostring(os.time()):reverse():sub(1,6)) -- good random seeds
	log.debug("random seed = " .. seed)
	math.randomseed( seed )
	math.random(); math.random(); math.random()
	-- done. :-)
	-- testing area below
	log.debug("test_area")
	mission_grammar.produce_graph( "outside_normal", 7, 3, 4, 3)
	log.debug(mission_grammar.produced_graph)
	log.debug("area_details")
	local area_details = mission_grammar.transform_to_space( {	tileset_id=4, 
																outside=false, 
																from_direction="west", 
																to_direction="east", 
																preferred_area_surface=80,
																path_width=2*16}
																)
	log.debug(area_details)
	log.debug("test_area")
	-- testing area above

	hero:set_visible(true)
	game:set_hud_enabled(true)
    game:set_pause_allowed(true)
    game:set_dialog_style("box")
    --map:set_tileset("1") needs to be set before the map loads
    local areas = generate_path_bottomup_in_order(area_details)
    log.debug("done with generation")
	
	local exit_areas={}
    local exclusion_areas={}
    local layer
	if area_details.outside then -- forest
    	exit_areas, exclusion_areas = create_forest_map(areas, area_details)
    	layer = 1
	else -- dungeon
		exit_areas, exclusion_areas = create_dungeon_map(areas, area_details)
		layer = 0
	end

	log.debug("filling in area types")
	log.debug("exclusion_areas")
	log.debug(exclusion_areas)
	for k,v in pairs(areas["walkable"]) do
		log.debug("filling in area "..k)
		log.debug("creating area_type " .. area_details[k].area_type)
		if area_details[k].area_type == "F" then makeSingleFight(v)
		elseif area_details[k].area_type == "P" then makeSingleMaze(v, exit_areas[k], tile_lookup, area_details, exclusion_areas[k], layer)
		elseif area_details[k].area_type == "PF" then 
			makeSingleMaze(v, exit_areas[k], tile_lookup, area_details, exclusion_areas[k], layer)
			makeSingleFight(v)
		end
    end

	--log.debug(printGlobalVariables())
	hero:unfreeze()
end

local teleport_once = false

function map:on_opening_transition_finished(destination)
	if not teleport_once then
		hero:teleport("2", "start_position", "immediate")
		teleport_once = true
	end
end

function makeSingleFight(area) 
	local fight_generator = require("fight_generator")
	local enemiesInEncounter = fight_generator.make(area, 5)
	for _,enemy in pairs(enemiesInEncounter) do
		map:create_enemy(enemy)
	end
end

function makeSingleMaze(area, exit_areas, tile_lookup, area_details, exclusion_area, layer) 
	log.debug("start maze generation")
	local maze_generator = require("maze_generator")
	local maze = maze_generator.generate_maze( area, 16, exit_areas, exclusion_area, nil )
	for _,v in ipairs(maze) do
		fill_area(v.area, tile_lookup[v.pattern][area_details.tileset_id], "maze", layer)
	end
end

function show_corners(area, tileset)
	if tileset == nil then tileset = tonumber(map:get_tileset()) end
	local tile_id = tile_lookup["debug_corner"][tileset]
	fill_area({x1=area.x1, y1=area.y1, x2=area.x1+8, y2=area.y1+8}, tile_id, "corner", 0)--topleft
	fill_area({x1=area.x2-8, y1=area.y1, x2=area.x2, y2=area.y1+8}, tile_id, "corner", 0)--topright
	fill_area({x1=area.x2-8, y1=area.y2-8, x2=area.x2, y2=area.y2}, tile_id, "corner", 0)--bottomright
	fill_area({x1=area.x1, y1=area.y2-8, x2=area.x1+8, y2=area.y2}, tile_id, "corner", 0)--bottomleft
end

-- OLD takes too long with larger areas, maybe for internal filling of a walkable area
function create_spread_internal(area, density_offset, prop_names, prop_index)
	-- place randomly in the areas that are left
	local areas_left = {table_util.copy(area)}
	repeat
		log.debug("areas_left")
		log.debug(areas_left)
		local selected_prop 
		if "table" == type(prop_names[prop_index]) then
			selected_prop = prop_names[prop_index][math.random(#prop_names[prop_index])]
		else
			selected_prop = prop_names[prop_index]
		end
		local min_required_size = {x=prop_lookup[selected_prop].required_size.x, y=prop_lookup[selected_prop].required_size.y}
		-- if the last area in areas left is not large enough, we discard
		local current_area = table.remove(areas_left)
		local area_size = get_area_size(current_area)
		if area_size.x < min_required_size.x or area_size.y < min_required_size.y then
			-- pop off last, and try to put in the next prop
			if prop_index < #prop_names then
				create_spread_internal(current_area, density_offset, prop_names, prop_index+1)
			end
		else
			-- take a random area within the last area
			local random_area = random_area_in_area(current_area, min_required_size.x, min_required_size.y)
			-- if it is large enough then place tree prop, and reduce area by middle canopy size with 8 from the top and bottom
			place_prop(selected_prop, random_area, 0)
			local new_areas = shrink_until_no_conflict( resize_area(random_area, 
																	{-density_offset, 
																	 -density_offset, 
																	  density_offset, 
																	  density_offset}),
														current_area)

			table_util.add_table_to_table(new_areas, areas_left)
			-- do this until no areas are left
		end
	until next(areas_left) == nil
end

function create_forest_map(existing_areas, area_details)
	-- start filling in
	local tileset = area_details.tileset_id
	for k,v in pairs(existing_areas["walkable"]) do
    	log.debug("walkable " .. k)
    	log.debug(v)
    	create_spread_internal(v, 0, {{"flower1","flower2", "fullgrass"}}, 1)
    	show_corners(v, tileset)
    end
    for k,v in pairs(existing_areas["boundary"]) do
    	log.debug("boundary " .. k)
    	log.debug(v)
    	fill_area(v, 7, "boundary", 0)
    	-- gonna fill it up with trees later
	    show_corners(v, tileset)
    end
	local exit_areas={}
    local exclusion_areas={}
	for areanumber,connections in pairs(existing_areas["transition"]) do
		exit_areas[areanumber]={}
		exclusion_areas[areanumber]={}
		for connection_nr,v in pairs(connections) do
			log.debug(v.transitions)
			if v.transition_type == "direct" then
				exit_areas[areanumber][#exit_areas[areanumber]+1]=v.connected_at
				for i=1, #v.transitions do
			    	log.debug("transition area:".. areanumber .. ", connection: ".. connection_nr .. ", part: ".. i)
			    	log.debug(v.transitions[i])
			    	fill_area(v.transitions[i], 49, "transition", 0)
			    	show_corners(v.transitions[i], tileset)
			    end
			else -- we do a lookup, TODO eventually all transitions will use the lookup
				local t_details = transition_area_lookup[v.transition_type]
				for i=1, #v.transitions do
					table.insert(exclusion_areas[areanumber], {area=v.transitions[i], sides_open={"south"}})
					for positioning, tile in pairs(t_details) do
						local temp_pos={x1=v.transitions[i].x1+positioning.x1,
									    y1=v.transitions[i].y1+positioning.y1,
									    x2=v.transitions[i].x1+positioning.x2,
									    y2=v.transitions[i].y1+positioning.y2}
						fill_area(temp_pos, tile[tileset], "transition", 0)
					end
			    end
			end
		end
	end

	-- create tree lines which will follow a certain pattern uniformly across the map
	local tree_size = {x=64, y=80}
	local width, height = map:get_size()
	-- create each horizontal layer of trees
	local treelines = math.floor((height-32) -- 32 is the heiht that overlaps with the previous row
										/ 48) -- the height of the tree that is not overlapping at the bottom row
	log.debug("treelines")
	log.debug(treelines)
	local blocking_size = {x=48, y=64}
	local treeline_area_list = {}
	local left_overs = {}
	for i=1, treelines do
		local x_offset = 0
		if i % 2 == 0 then x_offset=24 end
		local top_line = 32+i*48-blocking_size.y
		local new_treeline = {x1=x_offset+8, y1=top_line, 
							  x2=width-(width-x_offset-16)%blocking_size.x,
							  y2=32+i*48}
		local chopped_treeline = {new_treeline}
		-- checking for overlap with transitions
		log.debug("create_forest_map transitions treeline "..i)
		for areanumber,connections in pairs(existing_areas["transition"]) do
			for connection_nr,v in pairs(connections) do
				if v.transition_type == "direct" then
					for k=1, #v.transitions do
						local counter=1
						repeat
							log.debug(counter)
							local tl = chopped_treeline[counter]
							if tl and areas_intersect(tl, v.transitions[k]) then 
								log.debug("create_forest_map found intersection treeline "..i)
								local new_areas = shrink_until_no_conflict(v.transitions[k], tl, "horizontal")
								chopped_treeline[counter] = false
								table_util.add_table_to_table(new_areas, chopped_treeline)
							else 
								counter = counter +1
							end
						until counter > #chopped_treeline
					end
				end
			end
		end
		log.debug("create_forest_map walkable treeline "..i)
		for areanumber,walkable in pairs(existing_areas["walkable"]) do
			local counter = 1
			log.debug(counter)
			repeat
				local tl = chopped_treeline[counter]
				if tl and areas_intersect(tl, walkable) then 
					log.debug("create_forest_map found intersection treeline "..i)
					local new_areas = shrink_until_no_conflict(walkable, tl, "horizontal")
					chopped_treeline[counter] = false
					table_util.add_table_to_table(new_areas, chopped_treeline)
				else 
					counter = counter +1
				end
			until counter > #chopped_treeline
		end
		remove_false(chopped_treeline)
		for _, tl in ipairs(chopped_treeline) do
			local area_size = get_area_size(tl)
			local x_available = (tl.x2 - (tl.x2-x_offset) % blocking_size.x) - (tl.x1 + (blocking_size.x - (tl.x1-x_offset) % blocking_size.x))
			if area_size.y < blocking_size.y or x_available < blocking_size.x then 
				if tl.y1 == top_line then tl.y1 = tl.y1+16 end
				table.insert(left_overs, tl)
			else 
				-- chop left side
				if tl.y1 == top_line then tl.y1 = tl.y1+16 end
				--left
				local till_next_part = (tl.x1-x_offset)%blocking_size.x 
				if till_next_part == 0 then till_next_part = blocking_size.x  
				else till_next_part = blocking_size.x - till_next_part end
				local left_area = {x1=tl.x1,y1=tl.y1,x2=tl.x1+(till_next_part-8),y2=tl.y2}
				tl.x1 = tl.x1+(till_next_part)
				if left_area.x2-left_area.x1 > 8 then
					table.insert(left_overs, left_area)
				end
				-- chop right side
				till_next_part = (tl.x2-x_offset)%blocking_size.x 
				if till_next_part == 0 then till_next_part = blocking_size.x end
				local right_area = {x1=tl.x2-(till_next_part)+8,y1=tl.y1,x2=tl.x2,y2=tl.y2}
				tl.x2 = tl.x2-(till_next_part)
				if right_area.x2-right_area.x1 > 8 then
					table.insert(left_overs, right_area)
				end
				if tl.x2-tl.x1 ~= 0 then table.insert(treeline_area_list, tl) end 
			end
		end
	end
	-- visualize
	for _, tl in ipairs(treeline_area_list) do
		--left side
		fill_area({x1=tl.x1-8, y1=tl.y1-3*8, x2=tl.x1, y2=tl.y1+2*8}, 513, "forest", 2) -- left canopy
		fill_area({x1=tl.x2, y1=tl.y1-3*8, x2=tl.x2+8, y2=tl.y1+2*8}, 514, "forest", 2) -- right canopy
		--right side
		fill_area({x1=tl.x1-8, y1=tl.y1+2*8, x2=tl.x1, y2=tl.y1+4*8}, 503, "forest", 0) -- left trunk
		fill_area({x1=tl.x2, y1=tl.y1+2*8, x2=tl.x2+8, y2=tl.y1+4*8}, 504, "forest", 0) -- right trunk
		-- fill the middle
		fill_area({x1=tl.x1, y1=tl.y1+3*8, x2=tl.x2, y2=tl.y1+5*8}, 505, "forest", 0) -- middle trunk
		fill_area({x1=tl.x1, y1=tl.y1-2*8, x2=tl.x2, y2=tl.y1+3*8}, 502, "forest", 0) -- wall
		fill_area({x1=tl.x1, y1=tl.y1-2*8, x2=tl.x2, y2=tl.y1+3*8}, 511, "forest", 2) -- middle canopy
		fill_area({x1=tl.x1, y1=tl.y1-4*8, x2=tl.x2, y2=tl.y1-2*8}, 512, "forest", 2) -- top canopy
		-- tricky part, the bottom trunk
		local x = tl.x1+8
		repeat
			fill_area({x1=x, y1=tl.y1+5*8, x2=x+32, y2=tl.y1+6*8}, 523, "forest", 0) -- bottom trunk
			x = x+48
		until x > tl.x2
	end
	-- TODO combine leftovers into sizable pieces and fill those with other forest props
	for _, lo in ipairs(left_overs) do
		create_spread_internal(lo, 0, {	{"small_green_tree", "small_lightgreen_tree", "tree_stump"}, 
										"impassable_rock_32x16", "impassable_rock_16x32", "impassable_rock_16x16"
										--{"flower1","flower2", "fullgrass"}
										}, 1)
		--fill_area(lo, 275, "water", 0)
		--[[local area_size = get_area_size(lo)
		if area_size.x > 32 and area_size.y > 32 then
			local random_area = random_area_in_area(lo, 32, 32)
			create_spread_internal(lo, 24, "flower1")
		end]]--
	end

	return exit_areas, exclusion_areas
end

function create_walls( area, wall_width )
	local walls = {["n"]={{x1=area.x1+wall_width, x2=area.x2-wall_width, y1=area.y1, y2=area.y1+wall_width}},
				   ["e"]={{x1=area.x2-wall_width, x2=area.x2, y1=area.y1+wall_width, y2=area.y2-wall_width}},
				   ["w"]={{x1=area.x1, x2=area.x1+wall_width, y1=area.y1+wall_width, y2=area.y2-wall_width}},
				   ["s"]={{x1=area.x1+wall_width, x2=area.x2-wall_width, y1=area.y2-wall_width, y2=area.y2}}}
	local corners = {["ne"]={x1=area.x2-wall_width, x2=area.x2, y1=area.y1, y2=area.y1+wall_width},
					 ["nw"]={x1=area.x1, x2=area.x1+wall_width, y1=area.y1, y2=area.y1+wall_width},
					 ["se"]={x1=area.x2-wall_width, x2=area.x2, y1=area.y2-wall_width, y2=area.y2},
					 ["sw"]={x1=area.x1, x2=area.x1+wall_width, y1=area.y2-wall_width, y2=area.y2}}
	--[[local floor_edge= {["n"]={x1=area.x1+wall_width, x2=area.x2-wall_width, y1=area.y1+wall_width, y2=area.y1+wall_width+8},
					   ["e"]={x1=area.x2-wall_width-8, x2=area.x2-wall_width, y1=area.y1+wall_width, y2=area.y2-wall_width},
					   ["w"]={x1=area.x1+wall_width, x2=area.x1+wall_width+8, y1=area.y1+wall_width, y2=area.y2-wall_width},
					   ["s"]={x1=area.x1+wall_width, x2=area.x2-wall_width, y1=area.y2-wall_width-8, y2=area.y2-wall_width}}
	local floor_edge_corners]]-- TODO cosmetics
	local open_area = {{x1=area.x1+wall_width, x2=area.x2-wall_width, y1=area.y1+wall_width, y2=area.y2-wall_width}}
	return walls, corners, open_area
end

function create_dungeon_map(existing_areas, area_details)
	-- start filling in
	local wall_width = area_details.wall_width
	local tileset = area_details.tileset_id
	local walkable_walls = {}
	local inner_corners = {}
	local outer_corners = {}
	for k,v in pairs(existing_areas["walkable"]) do
    	log.debug("walkable " .. k)
    	log.debug(v)
    	fill_area(v, tile_lookup["dungeon_floor"][tileset], "floor", 1)
    	walkable_walls[k]=v.walls
    	inner_corners[k]=v.corners
    	for dir,area_list in pairs(v.walls) do
    		for _,area in ipairs(area_list) do
    			fill_area(area, wall_tiling_lookup["dungeon"]["wall"][dir], "wall", 1)
    		end
    	end
    	for dir,area in pairs(v.corners) do
    		fill_area(area, wall_tiling_lookup["dungeon"]["wall_inward_corner"][dir], "wall_corner", 1)
    	end
    	show_corners(v, tileset)
    end
    for k,v in pairs(existing_areas["boundary"]) do
    	log.debug("boundary " .. k)
    	log.debug(v)
    	fill_area(v, tile_lookup["dungeon_spacer"][tileset], "boundary", 2)
    	show_corners(v, tileset)
    end--
	local exit_areas={}
    local exclusion_areas={}
	for areanumber,connections in pairs(existing_areas["transition"]) do
		exit_areas[areanumber]={}
		exclusion_areas[areanumber]={}
		for connection_nr,v in pairs(connections) do
			log.debug(v.transitions)
			if v.transition_type == "direct" then
				exit_areas[areanumber][#exit_areas[areanumber]+1]=v.connected_at
				for i=1, #v.transitions do
			    	log.debug("transition area:".. areanumber .. ", connection: ".. connection_nr .. ", part: ".. i)
			    	log.debug(v.transitions[i])
			    	fill_area(v.transitions[i], tile_lookup["dungeon_floor"][tileset], "transition", 1)
			    	show_corners(v.transitions[i], tileset)
			    end
			else -- we do a lookup, TODO eventually all transitions will use the lookup
				for i=1, #v.transitions do
					--table.insert(exclusion_areas[areanumber], {area=v.transitions[i], sides_open={"south"}})
					log.debug("transition area:".. areanumber .. ", connection: ".. connection_nr .. ", part: ".. i)
					log.debug("placing prop indirect transition")
					log.debug(v)
					log.debug(tileset)
					place_prop(v.transition_type, v.transitions[i], 1, tileset, transition_area_lookup, "transition"..v.transition_type)
			    end
			end
		end
	end
	--
	return exit_areas, exclusion_areas
end

function place_prop(name, area, layer, tileset_id, use_this_lookup, custom_name)
	local temp_name = custom_name or "prop"..name
	local lookup_table = use_this_lookup or prop_lookup
	for positioning, tile in pairs(lookup_table[name]) do
		if "table" == type( positioning ) then
			local temp_pos={x1=area.x1+positioning.x1,
						    y1=area.y1+positioning.y1,
						    x2=area.x1+positioning.x2,
						    y2=area.y1+positioning.y2}
			local temp_layer = layer or 0
			if positioning.layer ~= nil then temp_layer = temp_layer+positioning.layer end
			local temp_tile = tile
			if "table" == type( tile ) then temp_tile = tile[tileset_id] end
			fill_area(temp_pos, temp_tile, temp_name, temp_layer)
		end
    end
end

function random_area_details(nr_of_areas, preferred_area_surface)
	local area_details = {	nr_of_areas=nr_of_areas, -- 
							tileset_id=1, -- tileset id, light world
							outside=true,
							from_direction="west",
							to_direction="east",
							preferred_area_surface=preferred_area_surface, 
							[1]={	area_type="empty",--area_type
									shape_mod=nil, --shape_modifier 
									transition_details=nil, --"transistion <map> <destination>"
									nr_of_connections=1,
									[1]={ type="twoway", areanumber=2, direction="south"}
								}
						  }
						  --TODO add connections to the recipient areas as well for all connection types
	if nr_of_areas > 1 then 
		for i=2, nr_of_areas do
			area_details[i] = {area_type="empty"}
			area_details[i].nr_of_connections = 0
			if i < nr_of_areas then 
				area_details[i].nr_of_connections = area_details[i].nr_of_connections+1
				area_details[i][area_details[i].nr_of_connections] = {type="twoway", areanumber=i+1} 
			end
			if i>2 then
				area_details[i].nr_of_connections = area_details[i].nr_of_connections+1
				area_details[i][area_details[i].nr_of_connections] = {type="twoway", areanumber=i-2}
			end
		end
	end
	return area_details
end



-- generating a path
-- general idea is to create a representation of every area, and connections

-- We try to do this by using a table (connections) of undefined length which contain
-- tables of undefined length to contain representations {type} of connections between nodes
-- One table (areas) explains the type of area, minimal area size, and the density of props.

-- Things that are to be taken into account:
--1- Areas need to have at least enough space between them to allow the hero to move through and have a 
---- measure of easthetics (predefine cases in which you need extra space)
--2- Connections need to be able to reach their nodes
--3- Area can be resized/scaled, but probably only beforehand (check this!)
--4- positioning of the tiles is based on topleft anchoring
--5- tiles have no size info available, only pattern number (manually add these to lookup tables -_-)

-- optimal block placement is an NP-Hard problem, do not attempt optimal~ given an area, that is not the objective!
-- instead we create and determine our map size afterwards

-- area_details = {	nr_of_areas, 
	-- 				tileset, 
	-- 				preferred_area_surface, 
	-- 				[1...nr_of_areas]={	area_type, 
	-- 									shape_modifier, 
	-- 									is_transition_area, 
	-- 									[1...connections]={ ("twoway"/"oneway_to"/"oneway_from"), areanumber}
	-- 								  }
	-- 			   }

function generate_path_bottomup_in_order(area_details)
	-- initialize all reused variables
	local width, height = map:get_size()

	local areas = {["walkable"]={}, ["boundary"]={[1] = {x1=0, y1=0, x2=width, y2=height}}, ["transition"]={}}

	local allowed_connectiontypes = {"separator", "adjacent", "jumper", "cave_teleport"}

	local boundary_width = 5*16

	local x = math.floor(math.random(boundary_width, width-boundary_width)/16)*16
	local y = math.floor(math.random(boundary_width, height-boundary_width)/16)*16
	local starting_origin = {256, 1024, "normal"}
	
	local new_walkable_area_list = create_new_walkable_areas(area_details, areas, boundary_width, starting_origin)
	log.debug("new walkable areas")
	log.debug(new_walkable_area_list)

	for areanumber=1, area_details.nr_of_areas, 1 do
		log.debug("conflict resolution for new walkable area")
		new_walkable_area = conflict_resolution(new_walkable_area_list[areanumber], areas, boundary_width, "walkable")
		if new_walkable_area then
			areas["transition"][areanumber] = {}
			areas["walkable"][areanumber] = new_walkable_area
		else
			log.debug("conflict resolution walkable ".. areanumber .. " failed")
		end
	end 

	-- generate transitions for each area, in order
	-- direct transitions, they need to be handled first to be able to place indirect transitions without overlap
	local todo_indirect = {}
	for areanumber=1, area_details.nr_of_areas, 1 do
		local details_of_current_area = area_details[areanumber]
		for connection=1, details_of_current_area.nr_of_connections, 1 do
			local transition_details = details_of_current_area[connection]
			-- determine which transition types are possible given the locations of the areas
			local found_path, found = check_for_direct_path(area_details.path_width+2*area_details.wall_width, math.huge, areanumber, transition_details.areanumber, areas)
			if found then -- create direct transition
				local resulting_transitions, connected_at = create_direct_transition(found_path, transition_details, area_details.path_width+2*area_details.wall_width, areas)
				rectify_walkable_details(areas, areanumber, connected_at[1], area_details, true)
				rectify_walkable_details(areas, transition_details.areanumber, connected_at[#connected_at], area_details, true)
				local links, to_transition = expand_transition_connected_at( connected_at, area_details )
				areas["transition"][areanumber][connection]={transitions=resulting_transitions,
															 transition_openings=to_transition,
															 transition_links=links,
															 transition_type="direct", 
															 connected_at=connected_at[1]}
				areas["transition"][transition_details.areanumber]["area_from"..areanumber.."_to"..transition_details.areanumber.."_con_"..connection]={transitions={}, transition_type="direct", connected_at=connected_at[#connected_at]}
				for _, v in ipairs(resulting_transitions) do
					conflict_resolution(v, areas, boundary_width, "transition")
				end
			else
				todo_indirect[areanumber] = todo_indirect[areanumber] or {} 
				todo_indirect[areanumber][connection]=transition_details
			end
		end
	end
	-- now that we have all the connecting areas of a certain walkable area we can properly assign a position to indirect transitions
	for areanumber, indirect_connections in pairs(todo_indirect) do
		for connection, transition_details in pairs(indirect_connections) do
			-- collect all the touching areas and create a list of open areas left for the indirect transitions
			local resulting_transitions, transition_type, directions = create_indirect_transition(connection, areanumber, transition_details, areas, area_details)
			rectify_walkable_details(areas, areanumber, resulting_transitions[1], area_details, true)
			rectify_walkable_details(areas, transition_details.areanumber, resulting_transitions[2], area_details, true)
			areas["transition"][areanumber]["area_from"..areanumber.."_to"..transition_details.areanumber.."_con_"..connection]=
				{transitions={resulting_transitions[1]}, transition_type=transition_type[1], direction=directions[1]}
			areas["transition"][transition_details.areanumber]["area_from"..areanumber.."_to"..transition_details.areanumber.."_con_"..connection]=
				{transitions={resulting_transitions[2]}, transition_type=transition_type[2], direction=directions[2]}
		end
	end
	log.debug(transition_assignments)
	return areas
end

function rectify_walkable_details(existing_areas, areanumber, new_area, area_details, transition_bool)
	log.debug("rectify_walkable_details areanumber "..areanumber)
	log.debug("new_area")
	log.debug(new_area)
	if transition_bool == nil then transition_bool = false end
	local wall_width = area_details.wall_width
	local area_to_rectify = existing_areas["walkable"][areanumber]
	log.debug("area_to_rectify")
	log.debug(area_to_rectify)
	local use_this_area = new_area
	local check_these_areas = nil
	if transition_bool then
		-- adjust walls which intersect with the opening -- adding some extra length so we can use that with the open area
		if new_area.x1==area_to_rectify.x2 then -- east
			use_this_area = resize_area(new_area, {-wall_width-32, wall_width,0,-wall_width})
		elseif new_area.x2==area_to_rectify.x1 then -- west
			use_this_area = resize_area(new_area, {0, wall_width,wall_width+32,-wall_width})
		elseif new_area.y2==area_to_rectify.y1 then -- north
			use_this_area = resize_area(new_area, {wall_width, 0,-wall_width,wall_width+32})
		elseif new_area.y1==area_to_rectify.y2 then -- south
			use_this_area = resize_area(new_area, {wall_width, -wall_width-32,-wall_width,0}) end
		if new_area.x2==area_to_rectify.x2 then check_these_areas = area_to_rectify.walls["e"]
		elseif new_area.x1==area_to_rectify.x1 then check_these_areas = area_to_rectify.walls["w"]
		elseif new_area.y1==area_to_rectify.y1 then check_these_areas = area_to_rectify.walls["n"]
		elseif new_area.y2==area_to_rectify.y2 then check_these_areas = area_to_rectify.walls["s"] end
		for k,v in ipairs(check_these_areas) do
			if areas_intersect(use_this_area, v) then
				local newly_made_areas = shrink_until_no_conflict(use_this_area, v)
				check_these_areas[k]=false
				table_util.add_table_to_table(newly_made_areas, check_these_areas)
			end
		end
		remove_false(check_these_areas)
	end
	-- adjust open area
	check_these_areas = area_to_rectify.open
	for k,v in ipairs(check_these_areas) do
		if areas_intersect(use_this_area, v) then
			local newly_made_areas, conflict = shrink_until_no_conflict(use_this_area, v)
			check_these_areas[k]=false
			table_util.add_table_to_table(newly_made_areas, check_these_areas)
			table.insert(area_to_rectify.used, conflict)
		end
	end
	remove_false(check_these_areas)
	remove_false(area_to_rectify.used)
end

-- directions are 0:east, 1:north, 2:west, 3:south, which is the same in the engine
function pick_random_wall_piece( width, existing_areas, areanumber, area_details, directions )
	local wall_width = area_details.wall_width
	local possible_directions = {}
	local possible_areas = {}
	directions = directions or {0, 1, 2, 3}
	if table_util.contains(directions, 1) then
		for k,v in pairs(existing_areas["walkable"][areanumber].walls["n"]) do
			local size = get_area_size(v)
			if size.x >= width then 
				possible_areas[1] = possible_areas[1] or {}
				table.insert(possible_areas[1], v)
				if not table_util.contains(possible_directions, 1) then table.insert(possible_directions, 1) end
			end
		end
	end
	if table_util.contains(directions, 3) then
		for k,v in pairs(existing_areas["walkable"][areanumber].walls["s"]) do
			local size = get_area_size(v)
			if size.x >= width then 
				possible_areas[3] = possible_areas[3] or {}
				table.insert(possible_areas[3], v)
				if not table_util.contains(possible_directions, 3) then table.insert(possible_directions, 3) end
			end
		end
	end
	if table_util.contains(directions, 0) then
		for k,v in pairs(existing_areas["walkable"][areanumber].walls["e"]) do
			local size = get_area_size(v)
			if size.y >= width then 
				possible_areas[0] = possible_areas[0] or {}
				table.insert(possible_areas[0], v)
				if not table_util.contains(possible_directions, 0) then table.insert(possible_directions, 0) end
			end
		end
	end
	if table_util.contains(directions, 2) then
		for k,v in pairs(existing_areas["walkable"][areanumber].walls["w"]) do
			local size = get_area_size(v)
			if size.y >= width then 
				possible_areas[2] = possible_areas[2] or {}
				table.insert(possible_areas[2], v)
				if not table_util.contains(possible_directions, 2) then table.insert(possible_directions, 2) end
			end
		end
	end
	local selected_direction = possible_directions[math.random(#possible_directions)]
	if selected_direction == nil then return false, false end
	local available_areas = possible_areas[selected_direction]
	if selected_direction == 1 or selected_direction == 3 then 
		return random_area_in_area(available_areas[math.random(#available_areas)], width, wall_width), selected_direction
	else 
		return random_area_in_area(available_areas[math.random(#available_areas)], wall_width, width), selected_direction
	end
end

function pick_random_open_area( width, height, existing_areas, areanumber )
	local open_areas = existing_areas["walkable"][areanumber].open
	local possible_areas = {}
	local n = 0
	for k,v in ipairs(open_areas) do
		local size = get_area_size(v)
		if size.x >= width and size.y >= height then
			n = n+1
			possible_areas[n]=v
		end
	end
	return random_area_in_area(possible_areas[math.random(#possible_areas)], width, height)
end

function expand_transition_connected_at( connected_at, area_details )
	local width = area_details.wall_width
	local total = #connected_at
	local to_transition = {	expand_line( connected_at[1], width ), 
							expand_line( connected_at[total], width )}
	local links = {}
	for i=2,total-1 do
		links[i-1]=expand_line (connected_at[i], width )
	end
	return links, to_transition
end

function expand_line( area, width )
	local expanded_area
	local dir
	if area.y1 == area.y2 then -- needs to be expanded vertically
		expanded_area = resize_area(area, {0, -width, 0, width})
		dir="vertically"
	else -- needs to be expanded horizontally
		expanded_area = resize_area(area, {-width, 0, width, 0})
		dir="horizontally"
	end
	return {area=expanded_area, direction=dir }
end

function create_new_walkable_areas(area_details, existing_areas, boundary_width, starting_origin)
	-- area details contains the direction of the map where it should be headed
	-- for example if the from_direction == west, and the to_direction is east,
	-- then the probability of selecting a new direction for the next walkable area 
	-- should be west=0, north=0.25, east=0.5, south=0.25
	-- a from direction and to direction should not be the same, too much extra work
	local prob_dist = { ["west"]=25, 
						["east"]=25, 
						["north"]=25, 
						["south"]=25
					  }
	prob_dist[area_details.from_direction] = 0
	prob_dist[area_details.to_direction] = 50
	-- next we check what the combined area is of the areas already made, 
	-- and with the offset we can take a random between 1*offset and 2*offset
	-- with the 0 offset we can take a random between 0 and the width of the bounding area
	-- we can then place a normal origin on that point and test it if we can create a walkable area without intersections
	-- create first walkable area
	local wall_width = area_details.wall_width

	local new_area_list = {}
	local new_area = random_area(area_details, starting_origin)
	local walls, corners, open = create_walls( new_area, wall_width )
	new_area.walls=walls
	new_area.corners=corners
	new_area.open=open
	new_area.used={}
	new_area_list[#new_area_list+1] = new_area
	local bounding_area = new_area
	for i=2, area_details.nr_of_areas do
		local direction = choose_random_key(prob_dist)
		local next_origin = find_origin_along_edge(bounding_area, direction, boundary_width)
		new_area = random_area(area_details, next_origin)
		walls, corners, open = create_walls( new_area, wall_width )
		new_area.walls=walls
		new_area.corners=corners
		new_area.open=open
		new_area.used={}
		bounding_area = merge_areas(bounding_area, new_area)
		new_area_list[#new_area_list+1] = new_area
	end
	-- make sure that the areas are clear of the border of the map
	-- TODO use this to change the map size
	--[[
	for i=1, area_details.nr_of_areas do
		if new_area_list[i].x1 < boundary_width then
			local diff_x = boundary_width - new_area_list[i].x1 
			for i=1, area_details.nr_of_areas do
				new_area_list[i] = move_area(new_area_list[i], diff_x, 0)
			end
		end
		if new_area_list[i].y1 < boundary_width then
			local diff_y = boundary_width - new_area_list[i].y1 
			for i=1, area_details.nr_of_areas do
				new_area_list[i] = move_area(new_area_list[i], 0, diff_y)
			end
		end
	end]]--
	return new_area_list
end

-- Returns an item name and variant.
function choose_random_key(probabilities)

  local random = math.random(100)
  local sum = 0

  for key, probability in pairs(probabilities) do
    sum = sum + probability
    if random <= sum then
      return key
    end
  end

  return nil
end

-- helper function for creating transitions that will be close together
function area_cutoff(closest_point, max_distance, area, min_width, min_height)
	local new_area = table_util.copy(area)
	local width = area.x2-area.x1
	local height = area.y2-area.y1
	-- horizontal
	if closest_point.x < area.x2 then  -- if closest_point is left of the area then we need to cut from the right side
		local distance = area.x2-closest_point.x 
		if distance > max_distance and width > min_width then
			new_area.x2 = clamp(new_area.x2-(distance-max_distance), new_area.x1+min_width, math.huge)
		end
	end
	if closest_point.x > area.x1 then  -- if closest_point is right of the area then we need to cut from the right side
		local distance = closest_point.x-area.x1
		if distance > max_distance and width > min_width then
			new_area.x1 = clamp(new_area.x1+(distance-max_distance), 0, new_area.x2-min_width)
		end
	end
	--vertical
	if closest_point.y < area.y2 then  -- if closest_point is above the area then we need to cut from the bottom side
		local distance = area.y2-closest_point.y 
		if distance > max_distance and height > min_height then
			new_area.y2 = clamp(new_area.y2-(distance-max_distance), new_area.y1+min_height, math.huge)
		end
	end
	if closest_point.y > area.y1 then  -- if closest_point is below the area then we need to cut from the top side
		local distance = closest_point.y-area.y1
		if distance > max_distance and height > min_height then
			new_area.y1 = clamp(new_area.y1+(distance-max_distance), 0, new_area.y2-min_width)
		end
	end
	return new_area
end


-- path contains nodes from check_for_direct_path
-- node={area_type, length, number, connected_to, touch_details={along_entire_length, touching_area, touching_direction}}
function create_direct_transition(path, transition_details, path_width, existing_areas)
	log.debug("checking for direct transition on path:")
	log.debug(path)
	local resulting_transitions={} -- in order from original area to other area
	local new_transition_areas ={}
	local entrance = random_area_in_area(path[1].touch_details.touching_area, path_width, path_width)
	local connected_at = {entrance}
	log.debug("entrance before creation")
	log.debug(entrance)
	local dir1 = path[1].touch_details.touching_direction
	local exit
	local dir2
	for p=2, #path, 1 do
		new_transition_areas = {}
		boundary_area = existing_areas[path[p-1].area_type][path[p-1].number]
		local min_width = 2*path_width
		local cuttoff_area = area_cutoff({x=entrance.x1, y=entrance.y1}, 2*path_width, path[p].touch_details.touching_area, min_width, min_width)
		exit = random_area_in_area(cuttoff_area, path_width, path_width)
		table.insert(connected_at, exit)
		log.debug("exit")
		log.debug(exit)
		dir2 = path[p].touch_details.touching_direction
		-- a transition within an area is always at most 3 areas and at least 1
		-- cases: (a) corner, (b) sidestep, (c) U-turn
		if dir1 == dir2 then -- either sidestep or U-turn
			if dir1 == "vertically" then -- vertical sidestep or U-turn
				local top
				local bottom
				local top_first = false
				if entrance.y1 <= exit.y1 then -- entrance needs to go south and exit north
					top = entrance
					bottom = exit
					top_first = true
				elseif entrance.y1 > exit.y1 then -- entrance needs to go north and exit south
					bottom = entrance
					top = exit
					top_first = false
				end
				-- if max distance == 0 then they are the same, we need a U-turn
				local max_distance = bottom.y1 - top.y1
				local random_distance = math.floor(math.random(0, clamp(max_distance-path_width, 0, math.huge))/16)*16
				local top_area = {x1=top.x1, y1=top.y1, x2=top.x2, y2=top.y1+random_distance}
				local bottom_area = {x1=bottom.x1, y1=bottom.y1-clamp(max_distance-random_distance-path_width, 0, math.huge), x2=bottom.x2, y2=bottom.y2}
				if max_distance == 0 and boundary_area.y1 < top_area.y1 then -- U-turn
					local center_area = {x1=math.min(top_area.x1, bottom_area.x1), 
					    				 y1=top_area.y1-path_width, 
					    				 x2=math.max(top_area.x2, bottom_area.x2), 
					    				 y2=top_area.y2}
					new_transition_areas = {center_area}
					log.debug("adding top vertical U-turn")
					log.debug(new_transition_areas)
				elseif max_distance == 0 and boundary_area.y2 > top_area.y1 then -- U-turn
					local center_area = {x1=math.min(top_area.x1, bottom_area.x1), 
										 y1=top_area.y2, 
										 x2=math.max(top_area.x2, bottom_area.x2), 
										 y2=top_area.y2+path_width}
					new_transition_areas = {center_area}
					log.debug("adding bottom vertical U-turn")
					log.debug(new_transition_areas)
				else -- Sidestep
					local center_area = {x1=math.min(top_area.x1, bottom_area.x1), 
										 y1=top_area.y2, 
										 x2=math.max(top_area.x2, bottom_area.x2), 
										 y2=top_area.y2+path_width}
					if top_first then 
						if get_area_size(top_area).size > 0 then new_transition_areas[#new_transition_areas+1] = top_area end
						new_transition_areas[#new_transition_areas+1] = center_area
						if get_area_size(bottom_area).size > 0 then new_transition_areas[#new_transition_areas+1] = bottom_area end
					else 
						if get_area_size(bottom_area).size > 0 then new_transition_areas[#new_transition_areas+1] = bottom_area end
						new_transition_areas[#new_transition_areas+1] = center_area
						if get_area_size(top_area).size > 0 then new_transition_areas[#new_transition_areas+1] = top_area end
					end
					log.debug("adding vertical Sidestep to other side")
					log.debug(new_transition_areas)
				end
			else -- horizontal sidestep or U-turn
				local left
				local right
				local left_first = false
				if entrance.x1 <= exit.x1 then -- entrance needs to go east and exit west
					left = entrance
					right = exit
					left_first = true
				elseif entrance.x1 > exit.x1 then -- entrance needs to go west and exit east
					right = entrance
					left = exit
					left_first = false
				end
				local max_distance = right.x1 - left.x1
				local random_distance = math.floor(math.random(0, clamp(max_distance-path_width, 0, math.huge))/16)*16
				local left_area = {x1=left.x1, y1=left.y1, x2=left.x2+random_distance, y2=left.y2}
				local right_area = {x1=right.x1-clamp(max_distance-random_distance-path_width, 0, math.huge), y1=right.y1, x2=right.x2, y2=right.y2}
				if max_distance == 0 and boundary_area.x1 < left.x1 then -- if max distance == 0 then they are the same, we need a U-turn
					local center_area = {x1=left_area.x1-path_width, 
										 y1=math.min(left_area.y1, right_area.y1), 
										 x2=left_area.x2, 
										 y2=math.max(left_area.y2, right_area.y2)}
					new_transition_areas = {center_area}
					log.debug("adding left horizontal U-turn")
					log.debug(new_transition_areas)
				elseif max_distance == 0 and boundary_area.x2 > left.x1 then -- if max distance == 0 then they are the same, we need a U-turn
					local center_area = {x1=left_area.x1, 
										 y1=math.min(left_area.y1, right_area.y1), 
										 x2=left_area.x2+path_width, 
										 y2=math.max(left_area.y2, right_area.y2)}
					new_transition_areas = {center_area}
					log.debug("adding right horizontal U-turn")
					log.debug(new_transition_areas)
				else 
					local center_area = {x1=left_area.x2, 
										 y1=math.min(left_area.y1, right_area.y1), 
										 x2=left_area.x2+path_width, 
										 y2=math.max(left_area.y2, right_area.y2)}
					if left_first then 
						if get_area_size(left_area).size > 0 then new_transition_areas[#new_transition_areas+1] = left_area end
						new_transition_areas[#new_transition_areas+1] = center_area
						if get_area_size(right_area).size > 0 then new_transition_areas[#new_transition_areas+1] = right_area end
					else 
						if get_area_size(right_area).size > 0 then new_transition_areas[#new_transition_areas+1] = right_area end
						new_transition_areas[#new_transition_areas+1] = center_area
						if get_area_size(left_area).size > 0 then new_transition_areas[#new_transition_areas+1] = left_area end
					end
					log.debug("adding horizontal Sidestep to other side")
					log.debug(new_transition_areas)
				end
			end
		else -- corner case
			log.debug("adding corner")
			local first, second
			local area1, area2
			local area1_first = false
			if dir1 == "vertically" then
				area1 = entrance
				area2 = exit
				area1_first = true
			else -- entrance is horizontal
				area1 = exit
				area2 = entrance
				area1_first = false
			end
			if area1.y1 < area2.y2 then 
				first = {x1=area1.x1, y1=area1.y1, x2=area1.x2, y2=area2.y2}
			else 
				first = {x1=area1.x1, y1=area2.y1, x2=area1.x2, y2=area1.y2} 
			end
			if area2.x1 < area1.x2 then 
				second = {x1=area2.x1, y1=area2.y1, x2=area1.x1, y2=area2.y2}
			else
				second = {x1=area1.x2, y1=area2.y1, x2=area2.x2, y2=area2.y2}
			end
			if area1_first then 
				if get_area_size(first).size > 0 then new_transition_areas[#new_transition_areas+1] = first end
				if get_area_size(second).size > 0 then new_transition_areas[#new_transition_areas+1] = second end
			else 
				if get_area_size(second).size > 0 then new_transition_areas[#new_transition_areas+1] = second end
				if get_area_size(first).size > 0 then new_transition_areas[#new_transition_areas+1] = first end
			end
			log.debug(new_transition_areas)
		end
		dir1 = dir2
		entrance = exit
		log.debug("entrance after creation")
		log.debug(entrance)
		table_util.add_table_to_table(new_transition_areas, resulting_transitions)
	end
	return resulting_transitions, connected_at
end

--[[ teletransporter
properties (table): A table that describles all properties of the entity to create. Its key-value pairs must be:
name (string, optional): Name identifying the entity or nil. If the name is already used by another entity, a suffix (of the form "_2", "_3", etc.) will be automatically appended to keep entity names unique.
layer (number): Layer on the map (0: low, 1: intermediate, 2: high).
x (number): X coordinate on the map.
y (number): Y coordinate on the map.
width (number): Width of the entity in pixels.
height (number): Height of the entity in pixels.
sprite (string, optional): Id of the animation set of a sprite to create for the teletransporter. No value means no sprite (the teletransporter will then be invisible).
sound (string, optional): Sound to play when the hero uses the teletransporter. No value means no sound.
transition (string, optional): Style of transition to play when the hero uses the teletransporter. Must be one of:
"immediate": No transition.
"fade": Fade-out and fade-in effect.
"scrolling": Scrolling between maps. The default value is "fade".
destination_map (string): Id of the map to transport to (can be id of the current map).
destination_name (string, optional): ]]

--[[ destination
properties (table): A table that describles all properties of the entity to create. Its key-value pairs must be:
name (string, optional): Name identifying the entity or nil. If the name is already used by another entity, a suffix (of the form "_2", "_3", etc.) will be automatically appended to keep entity names unique.
layer (number): Layer on the map (0: low, 1: intermediate, 2: high).
x (number): X coordinate on the map.
y (number): Y coordinate on the map.
direction (number): Direction that the hero should take when arriving on the destination, between 0 (East) and 3 (South), or -1 to keep his direction unchanged.
sprite (string, optional): Id of the animation set of a sprite to create for the destination. No value means no sprite (the destination will then be invisible).
default (boolean, optional): ]]

--[[ stairs
properties (table): A table that describes all properties of the entity to create. Its key-value pairs must be:
name (string, optional): Name identifying the entity or nil. If the name is already used by another entity, a suffix (of the form "_2", "_3", etc.) will be automatically appended to keep entity names unique.
layer (number): Layer on the map (0: low, 1: intermediate, 2: high).
x (number): X coordinate on the map.
y (number): Y coordinate on the map.
direction (number): Direction where the stairs should be turned between 0 (East of the room) and 3 (South of the room). For stairs inside a single floor, this is the direction of going upstairs.
subtype (number): Kind of stairs to create:
0: Spiral staircase going upstairs.
1: Spiral staircase going downstairs.
2: Straight staircase going upstairs.
3: Straight staircase going downstairs.
4: Small stairs inside a single floor (change the layer of the hero).
]]

function create_indirect_transition(connection_nr, areanumber, transition_details, existing_areas, area_details)
	log.debug("creating indirect transition")
	local new_transition_areas={}
	local direction = {}
	local outside = area_details.outside
	local transition_type
	local layer
	-- create cave stairs in a random spot in both areas, with minimum distance of 3*16 from the walls
	local areanumbers = {areanumber, transition_details.areanumber}
	log.debug("areas")
	log.debug(areanumbers)
	if outside then -- cave_stairs teleports for simplicity
		layer = 0
		log.debug("creating cave stairs")
		for i=1, 2 do
			new_transition_areas[i]=pick_random_open_area( 2*16, 3*16, existing_areas, areanumbers[i] )
		end
		transition_type = "cave_stairs"
	else -- TODO edge stairs or passages, or simple teleporting platues
		-- check which positions along the edge of the walkable area is available
		layer = 1
		log.debug("creating edge stairs")
		for i=1, 2 do
			new_transition_areas[i], direction[i]=pick_random_wall_piece( 48, existing_areas, areanumbers[i], area_details, {1, 3})
			if not direction[i] then -- we need an inward placement of a stairs piece
				pick_random_wall_piece( 96, existing_areas, areanumbers[i], area_details, {2, 4})
			end
		end
		transition_type = "edge_stairs"
	end
	-- updating variables based on what is missing and which direction is needed for the destination
	-- stairs direction
	direction[1]=direction[1] or 1
	direction[2]=direction[2] or 1
	local transitions_used = {transition_type.."_"..direction[1], transition_type.."_"..direction[2]}
	local other_pos = {{x=new_transition_areas[1].x1+16, y=new_transition_areas[1].y1+16}, 
						 {x=new_transition_areas[2].x1+16, y=new_transition_areas[2].y1+16}}
	local dest_direction = {(direction[1]+2)%4, (direction[2]+2)%4}
	local dest_pos = {  {x=new_transition_areas[1].x1+24, y=new_transition_areas[1].y1+29}, 
						{x=new_transition_areas[2].x1+24, y=new_transition_areas[2].y1+29}}
	if dest_direction[1] == 1 then 
		dest_pos[1].y=new_transition_areas[1].y1-5 
		other_pos[1].y=new_transition_areas[1].y1
	end
	if dest_direction[2] == 1 then 
		dest_pos[2].y=new_transition_areas[2].y1-5 
		other_pos[2].y=new_transition_areas[2].y1
	end
	--TODO multiple transitions from one area to another area
	-- destinations are given the coordinates of where the player regains control
	-- for stair this is x+8 and y+13
	local dest1_name="destination_"..tostring(connection_nr).."_from"..tostring(areanumbers[2]).."_to"..tostring(areanumbers[1])
	local dest2_name="destination_"..tostring(connection_nr).."_from"..tostring(areanumbers[1]).."_to"..tostring(areanumbers[2])
	log.debug("creating destinations:\n"..dest1_name.."\n"..dest2_name)
	local dest1 = map:create_destination({name=dest1_name,layer=layer, x=dest_pos[1].x, y=dest_pos[1].y, direction=dest_direction[1], sprite="entities/teletransporter"})
	local dest2 = map:create_destination({name=dest2_name,layer=layer, x=dest_pos[2].x, y=dest_pos[2].y, direction=dest_direction[2], sprite="entities/teletransporter"})
	map:create_teletransporter({name="transition_"..tostring(connection_nr).."_from"..tostring(areanumbers[1]).."_to"..tostring(areanumbers[2]), sprite="entities/teletransporter",
								transition="immediate",layer=layer, x=other_pos[1].x, y=other_pos[1].y, width=16, height=16,
								destination_map=map:get_id(), destination=dest2_name})
	map:create_teletransporter({name="transition_"..tostring(connection_nr).."_from"..tostring(areanumbers[2]).."_to"..tostring(areanumbers[1]), sprite="entities/teletransporter",
								transition="immediate",layer=layer, x=other_pos[2].x, y=other_pos[2].y, width=16, height=16,
								destination_map=map:get_id(), destination=dest1_name})
	map:create_stairs({name="stairs_"..tostring(connection_nr).."_from"..tostring(areanumbers[1]).."_to"..tostring(areanumbers[2]),
					   layer=layer, x=other_pos[1].x, y=other_pos[1].y, direction=direction[1], subtype="3"})
	map:create_stairs({name="stairs_"..tostring(connection_nr).."_from"..tostring(areanumbers[2]).."_to"..tostring(areanumbers[1]),
					   layer=layer, x=other_pos[2].x, y=other_pos[2].y, direction=direction[2], subtype="3"})
	
	log.debug("finished creating indirect transition")
	return new_transition_areas, transitions_used, direction
end

function clamp(number, between_this, and_this)
	if number < between_this then return between_this end
	if number > and_this then return and_this end
	return number
end

function random_area_in_area(area, width, height)
	local new_area = {}
	if  area.x2 - area.x1 > width then 
		new_area.x1 = math.floor(math.random(area.x1, area.x2-width)/16)*16
		new_area.x2 = new_area.x1+width
	else 
		new_area.x1 = area.x1
		new_area.x2 = area.x2
	end
	if  area.y2 - area.y1 > height then 
		new_area.y1 = math.floor(math.random(area.y1, area.y2-height)/16)*16
		new_area.y2 = new_area.y1+height
	else 
		new_area.y1 = area.y1
		new_area.y2 = area.y2
	end
	return new_area
end

function remove_false(tab)
	local remove_these={}
	log.debug("length before: "..tostring(#tab))
	for i=#tab, 1, -1 do
		if not tab[i] then remove_these[#remove_these+1]=i end
	end
	log.debug("false_encountered: "..tostring(#remove_these))
	for _,v in ipairs(remove_these) do
		table.remove(tab, v)
	end
	log.debug("length after: "..tostring(#tab))
end

-- part of conflict resolution
function shrink_until_no_conflict(new_area, old_area, preference)
	log.debug("short conflict resolution")
	local conflict_free = false
	local newly_made_areas = {}
	intersection = areas_intersect(new_area, old_area)
	if not intersection then return {new_area}, false end
	local conflict_area
	newly_made_areas[#newly_made_areas+1], conflict_area = shrink_area(old_area, intersection, preference)
	intersection = areas_intersect(new_area, conflict_area)
	log.debug("conflict area:")
	log.debug(conflict_area)
	log.debug("intersection:")
	log.debug(intersection)
	if areas_equal(conflict_area, intersection) then conflict_free = true end
	while not conflict_free do
		newly_made_areas[#newly_made_areas+1], conflict_area = shrink_area(conflict_area, intersection, preference)
		intersection = areas_intersect(new_area, conflict_area)
		log.debug("conflict area:")
		log.debug(conflict_area)
		log.debug("intersection:")
		log.debug(intersection)
		if areas_equal(conflict_area, intersection) then conflict_free = true end
	end
	log.debug("conflict free again")
	remove_false(newly_made_areas)
	return newly_made_areas, conflict_area
end

-- only merge areas that are touching along entire length
-- or when trying to find the area span of 2 areas
function merge_areas(area1, area2)
	return {x1=math.min(area1.x1, area2.x1), 
			y1=math.min(area1.y1, area2.y1), 
			x2=math.max(area1.x2, area2.x2), 
			y2=math.max(area1.y2, area2.y2)}
end

--OLD
-- the overlap horizontally and vertically
--TODO Not yet used
function get_areas_in_between(area1, area2)
	return  {x2=math.max(area1.x1, area2.x1), 
			x1=math.min(area1.x2, area2.x2), 
			y1=math.max(area1.y1, area2.y1),
			y2=math.min(area1.y2, area2.y2)}, 
			{x1=math.max(area1.x1, area2.x1), 
			x2=math.min(area1.x2, area2.x2), 
			y2=math.max(area1.y1, area2.y1),
			y1=math.min(area1.y2, area2.y2)}
end

-- TODO Function is a bit long...
-- breadth first search with checks for earlier encountered nodes to avoid loops
function check_for_direct_path(path_width, max_length, areanumber1, areanumber2, existing_areas)
	log.debug("checking for direct path between area "..tostring(areanumber1).." and area "..tostring(areanumber2))
	log.debug("area1:")
	log.debug(existing_areas["walkable"][areanumber1])
	log.debug("area2:")
	log.debug(existing_areas["walkable"][areanumber2])
	local depth_list = {1}
	local possible_paths_tree = {[table_util.tostring(depth_list)]={area_type="walkable", length=0, number=areanumber1}}
	local max_depth = 1
	local numbers_encountered = {["walkable"]={[areanumber1]=true}, ["boundary"]={}}
	local done = false
	local found = false
	local new_layer_has_new_entries = false
	while not done do
		local string_key = table_util.tostring(depth_list)
		log.debug("current string key: "..string_key)
		local current_area = existing_areas[possible_paths_tree[string_key].area_type][possible_paths_tree[string_key].number]
		local area_index = 1
		-- test for touching walkable areas
		for i=1, #existing_areas["walkable"] do
			if numbers_encountered["walkable"][i] == nil then
				local test_area = existing_areas["walkable"][i]
				log.debug("check_for_direct_path testing touch walkable ")
				log.debug("current_area")
				log.debug(current_area)
				log.debug("test_area walkable "..i)
				log.debug(test_area)
				local touching, along_entire_length, touching_area, touching_direction = areas_touching(current_area, test_area)
				local touch_size = {x=0, y=0}
				if touching then touch_size = get_area_size(touching_area) end
				if touching and (touch_size.x >= path_width or touch_size.y >= path_width) then 
					numbers_encountered["walkable"][i] = true
					local length = 0 -- the total length up till the next contact point
					local length_increment = 0 
					if max_depth > 1 then length_increment = 
						distance_between(touching_area, possible_paths_tree[string_key].touch_details.touching_area, path_width) end
					length = possible_paths_tree[string_key].length + length_increment
					if i==areanumber2 then 
						local new_node = {area_type="walkable", length=length, number=i, 
									   touch_details={along_entire_length=along_entire_length, 
									     				touching_area=touching_area, 
									     				touching_direction=touching_direction}}
						depth_list = concat_table(depth_list, {area_index})
						local new_key = table_util.tostring(depth_list)
						possible_paths_tree[new_key] = new_node
						area_index=area_index+1
						found = true
						log.debug("found the area we were looking for!")
						done = true
						break
					end 
				end
			end
		end
		if done then break end
		-- test for touching boundary areas
		for i=1, #existing_areas["boundary"] do
			if numbers_encountered["boundary"][i] == nil then
				log.debug("testing boundary area "..tostring(i))
				local test_area = existing_areas["boundary"][i]
				local test_size = get_area_size(test_area)
				if test_size.x >= path_width and test_size.y >= path_width then -- transition might fit
					local touching, along_entire_length, touching_area, touching_direction = areas_touching(current_area, test_area)
					local touch_size = {x=0, y=0}
					if touching then touch_size = get_area_size(touching_area) end
					if touching and (touch_size.x >= path_width or touch_size.y >= path_width) then -- transition will definitely fit
						local length = 0 -- the total length up till the next contact point
						local length_increment = 0 
						if max_depth > 1 then 
							length_increment = 
								distance_between(touching_area, possible_paths_tree[string_key].touch_details.touching_area, path_width) 
						end
						length = possible_paths_tree[string_key].length + length_increment
						local new_node = {area_type="boundary", length=length, number=i, 
									     touch_details={along_entire_length=along_entire_length, 
									     				touching_area=touching_area, 
									     				touching_direction=touching_direction}}
						new_layer_has_new_entries= true
						local new_key = table_util.tostring(concat_table(depth_list, {area_index}))
						log.debug("added key "..new_key)
						possible_paths_tree[new_key] = new_node
						area_index=area_index+1
						numbers_encountered["boundary"][i] = true
					end
				end
			end
		end
		log.debug("found new nodes: "..tostring(new_layer_has_new_entries))
		-- breath first search of boundary areas
		local depth_counter = 1
		local got_next_node = false
		while not got_next_node do
			if depth_counter == max_depth then depth_list[depth_counter] = depth_list[depth_counter] +1 end
			local next_key = {}
			for i=1,depth_counter do
				next_key[i] = depth_list[i]
			end
			next_key = table_util.tostring(next_key)
			log.debug("next_key: "..next_key)
			if possible_paths_tree[next_key] == nil then -- last node in current branch
				if depth_counter > 1 then depth_list[depth_counter-1] = depth_list[depth_counter-1]+1 end
				if depth_counter == max_depth then depth_list[depth_counter] = 0
				else depth_list[depth_counter] = 1 end -- set to first node of the next branch
				depth_counter = depth_counter-1 -- back one step
			elseif depth_counter == max_depth then -- at the lowest depth, so we can safely say we have found the next node
				got_next_node = true
			else -- if not at max depth then we assign a new parent
				depth_counter = depth_counter+1
			end
			if depth_counter == 0 then
				if new_layer_has_new_entries then new_layer_has_new_entries = false
				else 
					done = true
					break 
				end
				depth_list[max_depth] = 1
				depth_list[max_depth+1] = 0
				depth_list[1] = 1
				max_depth = max_depth+1
				depth_counter = 1
				log.debug("going to layer "..tostring(max_depth))
			end
			log.debug("depth_counter: "..tostring(depth_counter))
			log.debug("depth_list: "..table_util.tostring(depth_list))
		end
		-- the rest of the layers are added in the while loop
	end
	local found_path = {}
	if found then -- direct transitions
		log.debug("possible_paths_tree:")
		log.debug(possible_paths_tree)
		local key = {1}
		for i=2,#depth_list do
			key[#key+1]=depth_list[i]
			local string_key = table_util.tostring(key)
			found_path[#found_path+1]=possible_paths_tree[string_key]
		end
	else --indirect transitions
		-- touching areas of the beginning and end area
		found_path={[areanumber1]={}, [areanumber2]={}}
		for _,v in ipairs({areanumber1, areanumber2}) do
			local current_area = existing_areas["walkable"][v]
			for i=1, #existing_areas["boundary"] do
				local test_area = existing_areas["boundary"][i]
				local touching, along_entire_length, touching_area, touching_direction = areas_touching(current_area, test_area)
				local touch_size = {x=0, y=0}
				if touching then touch_size = get_area_size(touching_area) end
				if touching and (touch_size.x >= 2*16 or touch_size.y >= 2*16) then -- transition will definitely fit
					local new_node = {area_type="boundary", length=length, number=i, 
								     touch_details={along_entire_length=along_entire_length, 
								     				touching_area=touching_area, 
								     				touching_direction=touching_direction}}
					found_path[v][#found_path[v]+1] = new_node
				end
			end
		end
	end
	return found_path, found
end

function concat_table(table1, table2)
	local resulting_table = {}
	for _, v in ipairs(table1) do
		resulting_table[#resulting_table+1]=v
	end
	for _, v in ipairs(table2) do
		resulting_table[#resulting_table+1]=v
	end
	return resulting_table
end

function distance_between(area1, area2, overlap_required)
	local x_distance = 0
	if area2.x2 < area1.x1 then x_distance = area1.x1 - area2.x2 + overlap_required -- area2 is left of area1
	elseif area2.x1 > area1.x2 then x_distance = area2.x1 - area1.x2 + overlap_required -- area 2 is right of area1
	elseif area2.x1 < area1.x1 and area2.x2 > area1.x1 then -- there is horizontal overlap on the left side
		local overlap = area2.x2 - area1.x1
		if overlap < overlap_required then x_distance = overlap_required - overlap end
	elseif area2.x1 < area1.x2 and area2.x2 > area1.x2 then -- there is horizontal overlap on the right side
		local overlap = area1.x2 - area2.x1
		if overlap < overlap_required then x_distance = overlap_required - overlap end
	end
	local y_distance = 0
	if area2.y2 < area1.y1 then y_distance = area1.y1 - area2.y2 + overlap_required -- area2 is left of area1
	elseif area2.y1 > area1.y2 then y_distance = area2.y1 - area1.y2 + overlap_required -- area 2 is right of area1
	elseif area2.y1 < area1.y1 and area2.y2 > area1.y1 then -- there is vertical overlap on the top side
		local overlap = area2.y2 - area1.y1
		if overlap < overlap_required then y_distance = overlap_required - overlap end
	elseif area2.y1 < area1.y2 and area2.y2 > area1.y2 then -- there is vertical overlap on the bottom side
		local overlap = area1.y2 - area2.y1
		if overlap < overlap_required then y_distance = overlap_required - overlap end
	end
	return x_distance + y_distance, x_distance, y_distance
end

function conflict_resolution(new_area, existing_areas, boundary_width, new_area_type)
	log.debug("checking for conflicts")
	log.debug(new_area_type)
	log.debug(new_area)
	-- check if the new area falls inside the map
	local width, height = map:get_size()
	if not new_area then return false end
	-- check for area intersections with the new area
	for i = 1, #existing_areas["boundary"] do
		if existing_areas["boundary"][i] then
			local conflict_area = existing_areas["boundary"][i]
			local intersection = areas_intersect(new_area, conflict_area)
			if intersection then
				-- if the conflicting area is a boundary we will use the following algorithm
				-- shrink the conflicting boundary area with the least amount of pixels
				-- create area that is equal to the part that was shrunken away (conflict area)
				-- check for intersection between the new area and conflict area,
				---- if the conflict area falls into the new area completely, discard the conflict area and end algorithm
				---- if the conflict area falls outside the new area but still intersects then repeat the algorithm
				local conflict_free = false
				log.debug("boundary conflict")
				log.debug("conflict area:")
				log.debug(conflict_area)
				existing_areas["boundary"][i], conflict_area = shrink_area(conflict_area, intersection)
				intersection = areas_intersect(new_area, conflict_area)
				log.debug("intersection:")
				log.debug(intersection)
				if areas_equal(conflict_area, intersection) then conflict_free = true end
				while not conflict_free do
					log.debug("not conflict free")
					log.debug("conflict area:")
					log.debug(conflict_area)
					existing_areas["boundary"][#existing_areas["boundary"]+1], conflict_area = shrink_area(conflict_area, intersection)
					intersection = areas_intersect(new_area, conflict_area)
					log.debug("intersection:")
					log.debug(intersection)
					if areas_equal(conflict_area, intersection) then conflict_free = true end
				end
				log.debug("conflict free again")
			end
		end
	end
	remove_false(existing_areas["boundary"])
	return new_area
end

function shrink_area(area_to_be_shrunk, intersection, preference)
	local area_width = area_to_be_shrunk.x2-area_to_be_shrunk.x1
	local area_height = area_to_be_shrunk.y2-area_to_be_shrunk.y1
	local min_direction = {math.max(area_width, area_height),0, 1}
	-- make sure that the expanded area doesn't intersect anymore with any other areas
	local shrink_using_this = {0,0,0,0}
	local ratios = {0,0,0,0}
	-- 2:southward, 4:northward, 3:eastward, 1:westward
	shrink_using_this[2] = intersection.y2-area_to_be_shrunk.y1
	shrink_using_this[4] = intersection.y1-area_to_be_shrunk.y2
	shrink_using_this[3] = intersection.x1-area_to_be_shrunk.x2
	shrink_using_this[1] = intersection.x2-area_to_be_shrunk.x1
	if area_width == 0 then
		ratios[1] = 1
		ratios[3] = 1
	else
		ratios[1] = math.abs(shrink_using_this[1])/area_width
		ratios[3] = math.abs(shrink_using_this[3])/area_width
	end
	if area_height == 0 then
		ratios[2] = 1
		ratios[4] = 1
	else
		ratios[2] = math.abs(shrink_using_this[2])/area_height
		ratios[4] = math.abs(shrink_using_this[4])/area_height
	end
	min_direction[1] = math.abs(shrink_using_this[1])
	min_direction[2] = 1
	min_direction[3] = ratios[1]	
	if preference == "horizontal" and (ratios[1] < 1 or ratios[3] < 1) then
		if ratios[1] < ratios[3] then
			shrink_using_this[2], shrink_using_this[3], shrink_using_this[4] = 0, 0, 0
			min_direction = {math.abs(shrink_using_this[1]), 1, ratios[1]}
		else
			shrink_using_this[1], shrink_using_this[2], shrink_using_this[4] = 0, 0, 0
			min_direction = {math.abs(shrink_using_this[3]), 3, ratios[3]}
		end
	elseif preference == "vertical" and (ratios[2] < 1 or ratios[4] < 1) then
		if ratios[2] < ratios[4] then
			shrink_using_this[1], shrink_using_this[3], shrink_using_this[4] = 0, 0, 0
			min_direction = {math.abs(shrink_using_this[2]), 2, ratios[2]}
		else
			shrink_using_this[1], shrink_using_this[2], shrink_using_this[3] = 0, 0, 0
			min_direction = {math.abs(shrink_using_this[4]), 4, ratios[4]}
		end
	else
		-- greedy actions first, lowest amount of shrinkage on each intersection
		for s=2, #shrink_using_this do
			if ratios[s] < min_direction[3] then
				shrink_using_this[min_direction[2]] = 0
				min_direction[1] = math.abs(shrink_using_this[s])
				min_direction[2] = s
				min_direction[3] = ratios[s]
			else
				shrink_using_this[s] = 0
			end
		end
	end

	local newly_made_area
	if min_direction[3] == 1 then newly_made_area = false
	else newly_made_area = resize_area(area_to_be_shrunk, shrink_using_this) end

	-- now the other way around
	if 		min_direction[2] == 1 then -- shrunk left side
				shrink_using_this[min_direction[2]] = min_direction[1] - area_width
	elseif 	min_direction[2] == 2 then -- shrunk top side
				shrink_using_this[min_direction[2]] = min_direction[1] - area_height
	elseif 	min_direction[2] == 3 then -- shrunk right side
				shrink_using_this[min_direction[2]] = area_width - min_direction[1] 
	elseif 	min_direction[2] == 4 then -- shrunk bottom side
				shrink_using_this[min_direction[2]] = area_height - min_direction[1] 
	end
	shrink_using_this[1], shrink_using_this[2], shrink_using_this[3], shrink_using_this[4] = 
		shrink_using_this[3], shrink_using_this[4], shrink_using_this[1], shrink_using_this[2]
	local conflict_area = resize_area(area_to_be_shrunk, shrink_using_this)
	return newly_made_area, conflict_area
end

function random_area(area_details, origin)
	local preferred_area_surface = area_details.preferred_area_surface
	local wall_width = area_details.wall_width
	local dimxy_sqrt = math.floor(math.sqrt(preferred_area_surface))
	local dimx = dimxy_sqrt+math.random(-math.floor(dimxy_sqrt/5), math.floor(dimxy_sqrt/5))
	local dimy = math.floor(preferred_area_surface/(dimx))
	if origin[3] == "normal" then
		return {	x1=origin[1], 
					y1=origin[2],
					x2=origin[1]+dimx*16+2*wall_width,
					y2=origin[2]+dimy*16+2*wall_width
				}
	elseif origin[3] == "north" then
		return {x1 = origin[1]-math.floor(dimx/2)*16-wall_width,
				y1 = origin[2]-dimy*16-2*wall_width,
				x2 = origin[1]+math.ceil(dimx/2)*16+wall_width,
				y2 = origin[2]}
	elseif origin[3] == "south" then
		return {x1 = origin[1]-math.floor(dimx/2)*16-wall_width,
				y1 = origin[2],
				x2 = origin[1]+math.ceil(dimx/2)*16+wall_width,
				y2 = origin[2]+dimy*16+2*wall_width}
	elseif origin[3] == "east" then
		return {x1 = origin[1],
				y1 = origin[2]-math.floor(dimy/2)*16-wall_width,
				x2 = origin[1]+dimx*16+2*wall_width,
				y2 = origin[2]+math.ceil(dimy/2)*16+wall_width}
	elseif origin[3] == "west" then
		return {x1 = origin[1]-dimx*16-2*wall_width,
				y1 = origin[2]-math.floor(dimy/2)*16-wall_width,
				x2 = origin[1],
				y2 = origin[2]+math.ceil(dimy/2)*16+wall_width}
	else 
		return false
	end

end


function areas_touching(area1, area2)
	local touching = false
	local along_entire_length = {false, false}
	local touching_area = {}
	local touching_direction = false
	if area1.x1 == area2.x2 and area2.y1 < area1.y2 and area2.y2 > area1.y1 then -- area1 west is touching
		touching_direction = "horizontally"
		touching_area = {x1=area1.x1, y1=math.max(area1.y1, area2.y1), x2=area1.x1, y2=math.min(area1.y2, area2.y2)}
		touching = true 
	elseif area1.x2 == area2.x1 and area2.y1 < area1.y2 and area2.y2 > area1.y1 then -- area1 east is touching
		touching_direction = "horizontally"
		touching_area = {x1=area1.x2, y1=math.max(area1.y1, area2.y1), x2=area1.x2, y2=math.min(area1.y2, area2.y2)}
		touching = true 
	elseif area1.y1 == area2.y2 and area2.x1 < area1.x2 and area2.x2 > area1.x1 then -- area1 north is touching
		touching_direction = "vertically"
		touching_area = {x1=math.max(area1.x1, area2.x1), y1=area1.y1, x2=math.min(area1.x2, area2.x2), y2=area1.y1}
		touching = true 
	elseif area1.y2 == area2.y1 and area2.x1 < area1.x2 and area2.x2 > area1.x1 then -- area1 south is touching
		touching_direction = "vertically"
		touching_area = {x1=math.max(area1.x1, area2.x1), y1=area1.y2, x2=math.min(area1.x2, area2.x2), y2=area1.y2}
		touching = true 
	end
	if (area1.y1 >= area2.y1 and area1.y2 <= area2.y2) or (area1.x1 >= area2.x1 and area1.x2 <= area2.x2) then along_entire_length[1] = true end
	if (area1.y1 <= area2.y1 and area1.y2 >= area2.y2) or (area1.x1 <= area2.x1 and area1.x2 >= area2.x2) then along_entire_length[2] = true end
	return touching, along_entire_length, touching_area, touching_direction
end

-- directions = {"north","south", "east", "west"}
-- origin_point= {x, y, expansiondirection}
function find_origin_along_edge(area, direction, offset)
	local x, y
	x = math.floor(math.random(area.x1, area.x2)/16)*16
	y = math.floor(math.random(area.y1, area.y2)/16)*16
	local randomized_offset = math.floor((offset * math.random() + offset)/16)*16
	if direction == "north" then
		return {x, area.y1-randomized_offset, direction}
	elseif direction == "south" then
		return {x, area.y2+randomized_offset, direction}	
	elseif direction == "east" then
		return {area.x2+randomized_offset, y, direction}
	elseif direction == "west" then
		return {area.x1-randomized_offset, y, direction} -- originpoint
	else 
		return false
	end
end

function random_except(for_these_numbers, from, to)
	local checking_table = {}
	for i = 1, #for_these_numbers do
		checking_table[for_these_numbers[i]] = true
	end
	local random_number = math.random(from, to-#for_these_numbers)
	local got_right_number = false
	while not got_right_number do
		if checking_table[random_number] ~= nil then
			random_number = random_number + 1
		else
			got_right_number = true
		end
	end
	return random_number
end

function get_area_size(area)
	return {size=((area.x2-area.x1)*(area.y2-area.y1)), x=(area.x2-area.x1), y=(area.y2-area.y1)}
end

-- resize_table={x1, y1, x2, y2}
function resize_area(area, resize_table)
	return {x1=area.x1+resize_table[1], y1=area.y1+resize_table[2], x2=area.x2+resize_table[3], y2=area.y2+resize_table[4]}
end

function move_area(area, move_x, move_y)
	return {x1=area.x1+move_x, y1=area.y1+move_y, x2=area.x2+move_x, y2=area.y2+move_y}
end

-- area = {x1, y1, x2, y2}
function fill_area(area, pattern_id, par_name, layer)
	map:create_dynamic_tile({name=par_name, 
							layer=layer, 
							x=area.x1, y=area.y1, 
							width=area.x2-area.x1, height=area.y2-area.y1, 
							pattern=pattern_id, enabled_at_start=true})
end

-- area = {x1, y1, x2, y2}
function areas_intersect(area1, area2)
	if (area1.x1 < area2.x2 and area1.x2 > area2.x1 and
    area1.y1 < area2.y2 and area1.y2 > area2.y1) then
		return {x1=math.max(area1.x1, area2.x1), 
				y1=math.max(area1.y1, area2.y1), 
				x2=math.min(area1.x2, area2.x2), 
				y2=math.min(area1.y2, area2.y2)}
    else
    	return false
    end
end

function areas_equal(area1, area2)
	if 	area1.x1 == area2.x1 and
		area1.x2 == area2.x2 and
		area1.y1 == area2.y1 and
		area1.y2 == area2.y2 then
	 	return true
	else
		return false
	end
end

function limit_area_to_area(limit_this_area, to_this_area)
	local limited_area = {
			x1=math.min(math.max(limit_this_area.x1, to_this_area.x1), to_this_area.x2),
			x2=math.max(math.min(limit_this_area.x2, to_this_area.x2), to_this_area.x1),
			y1=math.min(math.max(limit_this_area.y1, to_this_area.y1), to_this_area.y2),
			y2=math.max(math.min(limit_this_area.y2, to_this_area.y2), to_this_area.y1),
			}
	if get_area_size(limited_area).size == 0 then return false end
	return limited_area
end