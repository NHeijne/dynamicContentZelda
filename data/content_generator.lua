
local mission_grammar 	= require("mission_grammar")
local space_gen 		= require("space_generator")
local lookup 			= require("data_lookup")
local fight_generator 	= require("fight_generator")

local log 				= require("log")
local table_util 		= require("table_util")
local area_util 		= require("area_util")
local num_util 			= require("num_util")

local content = {}

local game
local hero
local map

function content.start_test(given_map)
	map = given_map
	game = map:get_game()
	hero = map:get_hero()
	log.debug_log_reset()
	hero:freeze()
	if not game:get_value("sword__1") then hero:start_treasure("sword", 1, "sword__1") end
	
	function hero:on_state_changed(state)
		local f = sol.file.open("userExperience.txt","a+"); f:write(state .. "-hero\n"); f:flush(); f:close()
		if state == "hurt" then 
			local f = sol.file.open("userExperience.txt","a+")
			f:write(game:get_life() .. "-life\n") -- This gives previous health for some reason
			f:flush(); f:close()
		end
		-- returning false gives it back to the engine to handle
		return false
	end
		
	-- Initialize the pseudo random number generator
	local seed = --783166 -- transition bug
			tonumber(tostring(os.time()):reverse():sub(1,6)) -- good random seeds
	log.debug("random seed = " .. seed)
	math.randomseed( seed )
	math.random(); math.random(); math.random()
	-- done. :-)
	-- testing area below
	log.debug("test_area")
	mission_grammar.update_keys_and_barriers(game)
	mission_grammar.produce_graph( "outside_normal", 7, 3, 0, 7)
	log.debug(mission_grammar.produced_graph)
	log.debug("area_details")
	local tileset_id = tonumber(map:get_tileset())
	local outside = false
	if tileset_id == 1 or tileset_id == 2 then outside = true end
	content.area_details = mission_grammar.transform_to_space( {tileset_id=tileset_id, 
																outside=outside, 
																from_direction="west", 
																to_direction="east", 
																preferred_area_surface=180,
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
    content.areas = space_gen.generate_space(content.area_details, map)
    log.debug("done with generation")
	
	local exit_areas={}
    local exclusion_areas={}
    local layer
	if content.area_details.outside then -- forest
    	exit_areas, exclusion_areas = content.create_forest_map(content.areas, content.area_details)
    	layer = 0
	else -- dungeon
		exit_areas, exclusion_areas = content.create_dungeon_map(content.areas, content.area_details)
		layer = 0
	end
	-- adding effects
	fight_generator.add_effects_to_sensors(map, content.areas, content.area_details)

	log.debug("filling in area types")
	log.debug("exclusion_areas")
	log.debug(exclusion_areas)
	local wall_width = content.area_details.wall_width
	for k,v in pairs(content.areas["walkable"]) do
		log.debug("filling in area "..k)
		log.debug("creating area_type " .. content.area_details[k].area_type)
		if content.area_details[k].area_type == "P" or content.area_details[k].area_type == "PF" then 
			content.makeSingleMaze(area_util.resize_area(v,{wall_width+16, wall_width+16, -wall_width-16, -wall_width-16}), exit_areas[k], content.area_details, v.used, layer)
		end
    end

	--log.debug(printGlobalVariables())
	hero:unfreeze()
	local hero_x, hero_y, hero_layer = hero:get_position()
	map.small_keys_savegame_variable = "small_key_map"..map:get_id()
	map:create_pickable{layer=hero_layer, x=hero_x+16, y=hero_y, treasure_name="small_key", treasure_variant = 1}
end

function content.makeSingleFight(area, layer) 
	local fight_generator = require("fight_generator")
	local enemiesInEncounter = fight_generator.make(area, 5)
	for _,enemy in pairs(enemiesInEncounter) do
		enemy.layer = layer
		map:create_enemy(enemy)
	end
end

function content.makeSingleMaze(area, exit_areas, area_details, exclusion_area, layer) 
	log.debug("start maze generation")
	local maze_generator = require("maze_generator")
	local maze = maze_generator.generate_maze( area, 16, exit_areas, exclusion_area )
	for _,v in ipairs(maze) do
		content.place_tile(v.area, lookup.tiles[v.pattern][area_details.tileset_id], "maze", layer)
	end
end


function content.show_corners(area, tileset, layer)
	local layer = layer or 0
	if tileset == nil then tileset = tonumber(map:get_tileset()) end
	local tile_id = lookup.tiles["debug_corner"][tileset]
	content.place_tile({x1=area.x1, y1=area.y1, x2=area.x1+8, y2=area.y1+8}, tile_id, "corner", layer)--topleft
	content.place_tile({x1=area.x2-8, y1=area.y1, x2=area.x2, y2=area.y1+8}, tile_id, "corner", layer)--topright
	content.place_tile({x1=area.x2-8, y1=area.y2-8, x2=area.x2, y2=area.y2}, tile_id, "corner", layer)--bottomright
	content.place_tile({x1=area.x1, y1=area.y2-8, x2=area.x1+8, y2=area.y2}, tile_id, "corner", layer)--bottomleft
end

-- OLD takes too long with larger areas, maybe for internal filling of a walkable area
function content.spread_props(area, density_offset, prop_names, prop_index)
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
		local min_required_size = {x=lookup.props[selected_prop].required_size.x, y=lookup.props[selected_prop].required_size.y}
		-- if the last area in areas left is not large enough, we discard
		local current_area = table.remove(areas_left)
		local area_size = area_util.get_area_size(current_area)
		if area_size.x < min_required_size.x or area_size.y < min_required_size.y then
			-- pop off last, and try to put in the next prop
			if prop_index < #prop_names then
				content.spread_props(current_area, density_offset, prop_names, prop_index+1)
			end
		else
			-- take a random area within the last area
			local random_area = area_util.random_internal_area(current_area, min_required_size.x, min_required_size.y)
			-- if it is large enough then place tree prop, and reduce area by middle canopy size with 8 from the top and bottom
			content.place_prop(selected_prop, random_area, 0)
			local new_areas = area_util.shrink_until_no_conflict( area_util.resize_area(random_area, 
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

function content.create_forest_map(existing_areas, area_details)
	-- start filling in
	local tileset = area_details.tileset_id
	for k,v in pairs(existing_areas["walkable"]) do
    	log.debug("walkable " .. k)
    	log.debug(v)
    	content.spread_props(v, 0, {{"flower1","flower2", "fullgrass"}}, 1)
    	content.show_corners(v, tileset)
    end
    for k,v in pairs(existing_areas["boundary"]) do
    	log.debug("boundary " .. k)
    	log.debug(v)
    	content.place_tile(v, 7, "boundary", 0)
    	-- gonna fill it up with trees later
	    content.show_corners(v, tileset)
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
			    	content.place_tile(v.transitions[i], 49, "transition", 0)
			    	content.show_corners(v.transitions[i], tileset)
			    end
			elseif #v.openings~= 0 then -- we do a lookup, TODO eventually all transitions will use the lookup
				local t_details = lookup.transitions[v.transition_type]
				for i=1, #v.openings do
					table.insert(exclusion_areas[areanumber], {area=v.openings[i], sides_open={"south"}})
					for positioning, tile in pairs(t_details) do
						local temp_pos={x1=v.openings[i].x1+positioning.x1,
									    y1=v.openings[i].y1+positioning.y1,
									    x2=v.openings[i].x1+positioning.x2,
									    y2=v.openings[i].y1+positioning.y2}
						content.place_tile(temp_pos, tile[tileset], "transition", 0)
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
		log.debug("content.create_forest_map transitions treeline "..i)
		for areanumber,connections in pairs(existing_areas["transition"]) do
			for connection_nr,v in pairs(connections) do
				if v.transition_type == "direct" then
					for k=1, #v.transitions do
						local counter=1
						repeat
							log.debug(counter)
							local tl = chopped_treeline[counter]
							if tl and area_util.areas_intersect(tl, v.transitions[k]) then 
								log.debug("content.create_forest_map found intersection treeline "..i)
								local new_areas = area_util.shrink_until_no_conflict(v.transitions[k], tl, "horizontal")
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
		log.debug("content.create_forest_map walkable treeline "..i)
		for areanumber,walkable in pairs(existing_areas["walkable"]) do
			local counter = 1
			log.debug(counter)
			repeat
				local tl = chopped_treeline[counter]
				if tl and area_util.areas_intersect(tl, walkable) then 
					log.debug("content.create_forest_map found intersection treeline "..i)
					local new_areas = area_util.shrink_until_no_conflict(walkable, tl, "horizontal")
					chopped_treeline[counter] = false
					table_util.add_table_to_table(new_areas, chopped_treeline)
				else 
					counter = counter +1
				end
			until counter > #chopped_treeline
		end
		table_util.remove_false(chopped_treeline)
		for _, tl in ipairs(chopped_treeline) do
			local area_size = area_util.get_area_size(tl)
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
		content.place_tile({x1=tl.x1-8, y1=tl.y1-3*8, x2=tl.x1, y2=tl.y1+2*8}, 513, "forest", 2) -- left canopy
		content.place_tile({x1=tl.x2, y1=tl.y1-3*8, x2=tl.x2+8, y2=tl.y1+2*8}, 514, "forest", 2) -- right canopy
		--right side
		content.place_tile({x1=tl.x1-8, y1=tl.y1+2*8, x2=tl.x1, y2=tl.y1+4*8}, 503, "forest", 0) -- left trunk
		content.place_tile({x1=tl.x2, y1=tl.y1+2*8, x2=tl.x2+8, y2=tl.y1+4*8}, 504, "forest", 0) -- right trunk
		-- fill the middle
		content.place_tile({x1=tl.x1, y1=tl.y1+3*8, x2=tl.x2, y2=tl.y1+5*8}, 505, "forest", 0) -- middle trunk
		content.place_tile({x1=tl.x1, y1=tl.y1-2*8, x2=tl.x2, y2=tl.y1+3*8}, 502, "forest", 0) -- wall
		content.place_tile({x1=tl.x1, y1=tl.y1-2*8, x2=tl.x2, y2=tl.y1+3*8}, 511, "forest", 2) -- middle canopy
		content.place_tile({x1=tl.x1, y1=tl.y1-4*8, x2=tl.x2, y2=tl.y1-2*8}, 512, "forest", 2) -- top canopy
		-- tricky part, the bottom trunk
		local x = tl.x1+8
		repeat
			content.place_tile({x1=x, y1=tl.y1+5*8, x2=x+32, y2=tl.y1+6*8}, 523, "forest", 0) -- bottom trunk
			x = x+48
		until x > tl.x2
	end
	-- TODO combine leftovers into sizable pieces and fill those with other forest props
	for _, lo in ipairs(left_overs) do
		content.spread_props(lo, 0, {	{"small_green_tree", "small_lightgreen_tree", "tree_stump"}, 
										"impassable_rock_32x16", "impassable_rock_16x32", "impassable_rock_16x16"
										--{"flower1","flower2", "fullgrass"}
										}, 1)
		--content.place_tile(lo, 275, "water", 0)
		--[[local area_size = area_util.get_area_size(lo)
		if area_size.x > 32 and area_size.y > 32 then
			local random_area = area_util.random_internal_area(lo, 32, 32)
			content.spread_props(lo, 24, "flower1")
		end]]--
	end

	return exit_areas, exclusion_areas
end

function content.create_dungeon_map(existing_areas, area_details)
	-- start filling in
	local wall_width = area_details.wall_width
	local tileset = area_details.tileset_id
	for k,v in pairs(existing_areas["walkable"]) do
    	log.debug("walkable " .. k)
    	log.debug(v)
    	content.place_tile(v, lookup.tiles["dungeon_floor"][tileset], "floor", 0)
    	content.place_walls(v, wall_width)
    	content.show_corners(v, tileset, 0)
    end
    for k,v in pairs(existing_areas["boundary"]) do
    	log.debug("boundary " .. k)
    	log.debug(v)
    	content.place_tile(v, lookup.tiles["dungeon_spacer"][tileset], "boundary", 2)
    	content.show_corners(v, tileset, 0)
    end
	local exit_areas={}
    local exclusion_areas={}
	for areanumber,connections in pairs(existing_areas["transition"]) do
		exit_areas[areanumber]={}
		exclusion_areas[areanumber]={}
		for connection_nr,v in pairs(connections) do
			log.debug(v.transitions)
			if v.connected_at then
				if v.connected_at.x1 == v.connected_at.x2 then 
					exit_areas[areanumber][#exit_areas[areanumber]+1]=area_util.resize_area(v.connected_at, {0, wall_width+8, 0, -wall_width-8})
				else
					exit_areas[areanumber][#exit_areas[areanumber]+1]=area_util.resize_area(v.connected_at, {wall_width+8, 0, -wall_width-8, 0})
				end
			end
			if v.transition_type == "direct" and #v.transitions ~= 0 then
				local previous_walls, previous_corners
				local transition_pieces = #v.transitions
				log.debug("transition area:".. areanumber .. ", connection: ".. connection_nr)
				log.debug(v)
				for i=1, transition_pieces do
					-- first place part of the transition
			    	log.debug("transition area:".. areanumber .. ", connection: ".. connection_nr .. ", part: ".. i)
			    	content.place_tile(v.transitions[i], lookup.tiles["dungeon_floor"][tileset], "transition", 0)
			    	content.place_walls(v.transitions[i], wall_width)
			    	content.show_corners(v.transitions[i], tileset, 2)
			    	log.debug("links "..areanumber..";"..connection_nr)
			    	log.debug(v.links)
			    	-- now for the links in between
			    	if transition_pieces > 1 and i > 1 then
			    		-- vertical and horizontal case
			    		if v.links[i-1].direction == 1 or  v.links[i-1].direction == 3 then
			    			-- create the ground to walk on
			    			content.place_tile(area_util.resize_area(v.links[i-1], {wall_width, 0, -wall_width, 0}), lookup.tiles["dungeon_floor"][tileset], "floor", 0)
			    		else
			    			content.place_tile(area_util.resize_area(v.links[i-1], {0, wall_width, 0, -wall_width}), lookup.tiles["dungeon_floor"][tileset], "floor", 0)
			    		end
			    	end
			    	previous_walls, previous_corners = walls, corners
			    end
			    for _,opening in ipairs(v.openings) do
			    	if opening.direction == 1 or opening.direction == 3 then
		    			-- create the ground to walk on
		    			content.place_prop("edge_doors_1", area_util.from_center(opening, 32, opening.y2-opening.y1), 0, tileset, lookup.transitions)
		    		else
		    			content.place_prop("edge_doors_0", area_util.from_center(opening, opening.x2-opening.x1 ,32 ), 0, tileset, lookup.transitions)
		    		end
			    end
			elseif v.openings ~= nil then -- we do a lookup, TODO eventually all transitions will use the lookup
				for _,opening in ipairs(v.openings) do
					exit_areas[areanumber][#exit_areas[areanumber]+1]=area_util.resize_area(opening, {8, 0, -8, 0})
					log.debug("transition area:".. areanumber .. ", connection: ".. connection_nr)
					log.debug("placing prop indirect transition")
					log.debug(v)
					log.debug(tileset)
					content.place_prop(v.transition_type, opening, 0, tileset, lookup.transitions, "transition"..v.transition_type)
			    end
			end
			content.create_barriers( area_details, existing_areas, areanumber, connection_nr )
		end
	end

	--
	return exit_areas, exclusion_areas
end

function content.place_walls(area, wall_width)
	local walls, corners = area_util.create_walls(area, wall_width)
	for dir,area_list in pairs(walls) do
		for _,a in ipairs(area_list) do
			content.place_tile(a, lookup.wall_tiling["dungeon"]["wall"][dir], "wall", 0)
		end
	end
	for dir,a in pairs(corners) do
		content.place_tile(a, lookup.wall_tiling["dungeon"]["wall_inward_corner"][dir], "wall_corner", 0)
	end
end

-- barrier type is already concluded when the mission grammar is formed
-- so we need to create a table of destructables and doors to place at specific spots along the area
function content.create_barriers( area_details, existing_areas, areanumber, connection_nr )
	if type(connection_nr) ~= "number" then return false end
	log.debug("create_barriers")
	local barriers =area_details[areanumber][connection_nr].barriers
	if barriers == nil then
		log.debug("no barriers found for a"..areanumber.." c"..connection_nr)
	 	return false 
	end
	local transition_details = existing_areas["transition"][areanumber][connection_nr]
	local openings = transition_details.openings
	local ww = area_details.wall_width
	for _,barrier in pairs(barriers) do
		local split = table_util.split(barrier, ":")
		local barrier_type
		local object_details
		if lookup.destructible[split[2]] then 
			barrier_type = "destructible" 
			object_details = lookup.destructible[split[2]]
		else
			barrier_type = "door" 
			object_details = lookup.doors[split[2]]
		end
		local obj_size = object_details.required_size
		if split[1] == "L" then
			local dir = openings[1].direction
			local position
			local temp_area
			if dir == 1 or dir == 3 then 		
				temp_area = area_util.from_center(openings[1], 16, openings[1].y2-openings[1].y1)
    		elseif dir == 0 or dir == 2 then 	
    			temp_area = area_util.from_center(openings[1], openings[1].x2-openings[1].x1, 16)
    		end
    		if dir == 3 or dir == 0 then 		
				position = {x1=temp_area.x1, x2=temp_area.x1+16, y1=temp_area.y1, y2=temp_area.y1+16 }
    		elseif dir == 2 or dir == 1 then 	
    			position = {x1=temp_area.x2-16, x2=temp_area.x2, y1=temp_area.y2-16, y2=temp_area.y2 }
    		end
    		local optional = {opening_condition="small_key_map"..map:get_id()}
    		content.place_lock( object_details, dir, position, optional )
			-- create lock (placed upon the entry of the transition)
			-- determine direction
			-- place door in beginning of transition at connected_at
		else
			
			-- create destructible and doors (weak_blocks)
			-- determine direction and the area
			local available_areas = {}

			table.insert(available_areas, area_util.get_side(openings[1], (openings[1].direction+2)%4, math.max(obj_size.x, obj_size.y), -ww))
			for _,t in pairs(transition_details.transitions) do
				local new_t = area_util.resize_area(t, {ww, ww, -ww, -ww})
				local new_t_size = area_util.get_area_size(new_t)
				if new_t_size.x > obj_size.x and new_t_size.y > obj_size.y then table.insert(available_areas, new_t) end
			end
			log.debug("available_areas")
			log.debug(available_areas)
			-- place destructibles in front of the transition or inside the transition
			content.tile_destructible( object_details, available_areas[math.random(#available_areas)], barrier_type, {} )
		end
		
	end
end

-- map:create_destructible(properties)
-- properties (table): A table that describes all properties of the entity to create. Its key-value pairs must be:
-- name (string, optional): Name identifying the entity or nil. If the name is already used by another entity, a suffix (of the form "_2", "_3", etc.) will be automatically appended to keep entity names unique.
-- layer (number): Layer on the map (0: low, 1: intermediate, 2: high).
-- x (number): X coordinate on the map.
-- y (number): Y coordinate on the map.
-- treasure_name (string, optional): Kind of pickable treasure to hide in the destructible object (the name of an equipment item). If this value is not set, then no treasure is placed in the destructible object. If the treasure is not obtainable when the object is destroyed, no pickable treasure is created.
-- treasure_variant (number, optional): Variant of the treasure if any (because some equipment items may have several variants). The default value is 1 (the first variant).
-- treasure_savegame_variable (string, optional): Name of the boolean value that stores in the savegame whether the pickable treasure hidden in the destructible object was found. No value means that the treasure (if any) is not saved. If the treasure is saved and the player already has it, then no treasure is put in the destructible object.
-- sprite (string): Name of the animation set of a sprite to create for the destructible object.
-- destruction_sound (string, optional): Sound to play when the destructible object is cut or broken after being thrown. No value means no sound.
-- weight (number, optional): Level of "lift" ability required to lift the object. 0 allows the player to lift the object unconditionally. The special value -1 means that the object can never be lifted. The default value is 0.
-- can_be_cut (boolean, optional): Whether the hero can cut the object with the sword. No value means false.
-- can_explode (boolean, optional): Whether the object should explode when it is cut, hit by a weapon and after a delay when the hero lifts it. The default value is false.
-- can_regenerate (boolean, optional): Whether the object should automatically regenerate after a delay when it is destroyed. The default value is false.
-- damage_on_enemies (number, optional): Number of life points to remove from an enemy that gets hit by this object after the hero throws it. If the value is 0, enemies will ignore the object. The default value is 1.
-- ground (string, optional): Ground defined by this entity. The ground is usually "wall", but you may set "traversable" to make the object traversable, or for example "grass" to make it traversable too but with an additional grass sprite below the hero. The default value is "wall".
-- Return value (destructible object): The destructible object created.

-- map:create_door(properties)
-- properties (table): A table that describes all properties of the entity to create. Its key-value pairs must be:
-- name (string, optional): Name identifying the entity or nil. If the name is already used by another entity, a suffix (of the form "_2", "_3", etc.) will be automatically appended to keep entity names unique.
-- layer (number): Layer on the map (0: low, 1: intermediate, 2: high).
-- x (number): X coordinate on the map.
-- y (number): Y coordinate on the map.
-- direction (number): Direction of the door, between 0 (East of the room) and 3 (South of the room).
-- sprite (string): Name of the animation set of the sprite to create for the door. The sprite must have an animation "closed", that will be shown while the door is closed. When the door is open, no sprite is displayed. Optionally, the sprite can also have animations "opening" and "closing", that will be shown (if they exist) while the door is being opened or closed, respectively. If they don't exist, the door will open close instantly.
-- savegame_variable (string, optional): Name of the boolean value that stores in the savegame whether this door is open. No value means that the door is not saved. If the door is saved as open, then it appears open.
-- opening_method (string, optional): How the door is supposed to be opened by the player. Must be one of:
-- "none" (default): Cannot be opened by the player. You can only open it from Lua.
-- "interaction": Can be opened by pressing the action command in front of it.
-- "interaction_if_savegame_variable": Can be opened by pressing the action command in front of it, provided that a specific savegame variable is set.
-- "interaction_if_item": Can be opened by pressing the action command in front of it, provided that the player has a specific equipment item.
-- "explosion": Can be opened by an explosion.
-- opening_condition (string, optional): The condition required to open the door. Only for opening methods "interaction_if_savegame_variable" and "interaction_if_item".
-- For opening method "interaction_if_savegame_variable", it must be the name of a savegame variable. The hero will be allowed to open the door if this saved value is either true, an integer greater than zero or a non-empty string.
-- For opening method "interaction_if_item", it must be the name of an equipment item. The hero will be allowed to open the door if he has that item and, for items with an amount, if the amount is greater than zero.
-- For other opening methods, this setting has no effect.
-- opening_condition_consumed (boolean, optional): Whether opening the door should consume the savegame variable or the equipment item that was required. The default setting is false. If you set it to true, the following rules are applied when the hero successfully opens the door:
-- For opening method "interaction_if_savegame_variable", the savegame variable that was required is reset to false, 0 or "" (depending on its type).
-- For opening method is "interaction_if_item", the equipment item that was required is removed. This means setting its possessed variant to 0, unless it has an associated amount: in this case, the amount is decremented.
-- With other opening methods, this setting has no effect.
-- cannot_open_dialog_id (string, optional): Id of the dialog to show if the hero fails to open the door. If you don't set this value, no dialog is shown.
-- Return value (door): The door created.

function content.tile_destructible( details, area, barrier_type, optional )
	local layer = optional.layer or 0
	local details = details
	details.layer = details.layer+layer
	for k,v in pairs(optional) do
		details[k] = v
	end
	for x=area.x1, area.x2-details.offset.x, details.required_size.x do
		for y=area.y1, area.y2-details.offset.y, details.required_size.y do
			details.x, details.y = x+details.offset.x, y+details.offset.y
			if barrier_type == "door" then
				log.debug("creating door")
				log.debug(details)
				map:create_door(details)
			else
				log.debug("creating destructible")
				log.debug(details)
				map:create_destructible(details)
			end
		end
	end
end

function content.place_lock( details, direction, area, optional )
	local layer = optional.layer or 0
	local details = details
	details.layer = details.layer+layer
	for k,v in pairs(optional) do
		details[k] = v
	end
	details.direction = direction
	details.x, details.y = area.x1, area.y1
	log.debug("creating lock")
	log.debug(details)
	map:create_door(details)
end

function content.place_prop(name, area, layer, tileset_id, use_this_lookup, custom_name)
	local temp_name = custom_name or "prop"..name
	local lookup_table = use_this_lookup or lookup.props
	local nr_of_steps = #lookup_table[name]
	local priority_list = {}
	if nr_of_steps > 0 then
		for i=1, nr_of_steps do
			priority_list[i] = lookup_table[name][i]
		end
	else
		priority_list = {lookup_table[name]}
	end
	for _, lookup in ipairs(priority_list) do
		for positioning, tile in pairs(lookup) do
			if "table" == type( positioning ) then
				local temp_pos={x1=area.x1+positioning.x1,
							    y1=area.y1+positioning.y1,
							    x2=area.x1+positioning.x2,
							    y2=area.y1+positioning.y2}
				local temp_layer = layer or 0
				if positioning.layer ~= nil then temp_layer = temp_layer+positioning.layer end
				local temp_tile = tile
				if "table" == type( tile ) then temp_tile = tile[tileset_id] end
				content.place_tile(temp_pos, temp_tile, temp_name, temp_layer)
			end
	    end
	end
end

-- area = {x1, y1, x2, y2}
function content.place_tile(area, pattern_id, par_name, layer)
	map:create_dynamic_tile({name=par_name, 
							layer=layer, 
							x=area.x1, y=area.y1, 
							width=area.x2-area.x1, height=area.y2-area.y1, 
							pattern=pattern_id, enabled_at_start=true})
end


function content.random_area_details(nr_of_areas, preferred_area_surface)
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


return content