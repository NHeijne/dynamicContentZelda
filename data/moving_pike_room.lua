maze_gen 		= maze_gen or require("maze_generator")
placement 		= placement or require("object_placement")
puzzle_logger 	= puzzle_logger or require("puzzle_logger")

local log 			= require("log")
local table_util 	= require("table_util")
local area_util 	= require("area_util")
local num_util 		= require("num_util")

local pr = {}


function pr.make( parameters )
	local p = parameters
	pr.create_pike_room( p.areanumber, p.area_details, p.area, p.exit_areas, p.speed, p.width, p.movement, p.intersections )
end

function pr.create_pike_room( areanumber, area_details, area, exit_areas, speed, width, movement, intersections )
	local map = area_details.map
	if not map:get_entity("pikeroom_sensor_"..areanumber) then 
		maze_gen.set_map( map )
		maze_gen.set_room( area, 16, 0, "pikeroom_"..areanumber )
		local maze = {}
		maze_gen.initialize_maze( maze )
		local exits = maze_gen.open_exits( maze, exit_areas )
		local floor
		if area_details.outside then
			local outer_ring = maze_gen.get_outer_ring( maze, 1, false )
			for _,pos in ipairs(outer_ring) do
				maze[pos.x][pos.y].visited = "outer_ring"
			end
			local _, closed, _ = maze_gen.generate_path( maze, exits, "grid", width, intersections, 0 )
			local old_floor = map:get_entity("room_floor_"..areanumber)
			local floor_x, floor_y, layer = old_floor:get_position()
			local floor_w, floor_h = old_floor:get_size()
			old_floor:remove()
			floor = map:create_dynamic_tile{name="room_floor_"..areanumber, layer=0, 
											x=floor_x+24, y=floor_y+24, width=floor_w-48, height=floor_h-48, 
											pattern=14, enabled_at_start=true}
			floor:bring_to_back()

			table_util.add_table_to_table(maze_gen.maze_to_square_areas( maze, "exit" ), closed)
			for i,area in ipairs(closed) do
				map:create_dynamic_tile{layer=0, x=area.x1, y=area.y1, width=area.x2-area.x1, 
										height=area.y2-area.y1, pattern=275, enabled_at_start=true}
			end
			local outer_ring_areas = maze_gen.maze_to_square_areas( maze, "outer_ring" )
			for i,area in ipairs(outer_ring_areas) do
				map:create_dynamic_tile{layer=0, x=area.x1, y=area.y1, width=area.x2-area.x1, 
										height=area.y2-area.y1, pattern=275, enabled_at_start=true}
				map:create_dynamic_tile{layer=0, x=area.x1, y=area.y1, width=area.x2-area.x1, 
										height=area.y2-area.y1, pattern=10, enabled_at_start=true}
			end
		else
			local pikes = {}
			local _, _, maze = maze_gen.generate_path( maze, exits, "grid", width, intersections )
			local area_list = {}
			local unvisited = maze_gen.get_not_visited( maze )
			for i,pos in ipairs(unvisited) do
				area_list[i] = maze_gen.pos_to_area(pos)
			end
			for i,area in ipairs(area_list) do
				local pike = map:create_enemy{name="pike_area_"..areanumber.."_nr_1", 
											  layer=0, x=area.x1+8, y=area.y1+13, 
											  direction=3, breed="pike_fixed"}
				pikes[i]=pike
			end
			floor = map:get_entity("room_floor_"..areanumber)
		end

		local direction =  math.random(0, 3)*2
		local x, y, layer = floor:get_position()
		local stream = map:create_stream{name="stream_area_"..areanumber, 
					  layer=0, x=area.x1, y=area.y1, 
					  direction=direction, speed=speed}

		floor:set_optimization_distance(600)
		floor.position, floor.direction, floor.speed, floor.times_till_change, floor.stream = {x=x, y=y}, direction, speed, 4, stream
		local x_offset, y_offset = 0, 0
		if 		floor.direction == 0 then x_offset = -8; y_offset =  8 
		elseif 	floor.direction == 2 then x_offset = -8; y_offset =  8
		elseif 	floor.direction == 4 then x_offset =  8; y_offset = -8
		elseif 	floor.direction == 6 then x_offset =  8; y_offset = -8 end
		floor:set_position(floor.position.x+x_offset, floor.position.y+y_offset, 0)
		pr.move_recurrent( floor, movement )

		local room_sensor = placement.place_sensor( area, "pikeroom_sensor_"..areanumber, 0 )
		room_sensor.on_activated = 
			function() 
				local hero_x, hero_y, layer = hero:get_position()
				hero:save_solid_ground(hero_x, hero_y, layer)
				if hero:get_state() == "jumping" and stream:is_enabled() then stream:set_enabled(false) 
				elseif not stream:is_enabled() then stream:set_enabled() end	
				stream:set_position(num_util.clamp(hero_x, area.x1+8, area.x2-8), num_util.clamp(hero_y, area.y1+13, area.y2-3), layer)
				puzzle_logger.start_recording( "pike_room", areanumber )
			end
		room_sensor.on_activated_repeat = 
			function() 
				if hero:get_state() == "jumping" and stream:is_enabled() then stream:set_enabled(false) 
				elseif not stream:is_enabled() then stream:set_enabled() end	
				local hero_x, hero_y, layer = hero:get_position()
				stream:set_position(num_util.clamp(hero_x, area.x1+8, area.x2-8), num_util.clamp(hero_y, area.y1+13, area.y2-3), layer)
			end
		room_sensor.on_left =
			function()
				map:get_hero():reset_solid_ground()
				puzzle_logger.stop_recording()
			end
		for i, exit in ipairs(exit_areas) do
			local area_to_use = area_util.expand_line( exit, 16 )
			local exit_sensor = placement.place_sensor( area_to_use, "pikeroom_"..areanumber.."_exit_"..i, 0 )
			if i > 1 then 
				exit_sensor.on_activated = 
				function () 
					puzzle_logger.complete_puzzle() 
				end
			end
		end
	else
		local hero_x, hero_y, layer = map:get_hero():get_position()
		map:get_entity("stream_area_"..areanumber):set_position(hero_x, hero_y, layer)
	end
end

function pr.move_recurrent( obj, movement_type )
	local m = sol.movement.create("path")
	if obj.times_till_change == 0 then
		m:set_speed(16)
		obj.stream:set_speed(16)
	else
		m:set_speed(obj.speed)
		obj.stream:set_speed(obj.speed)
	end
	m:set_path{obj.direction, obj.direction}
	m:set_ignore_obstacles()
	m.on_finished = 
		function ()
			if obj.times_till_change == 0 then
				if movement_type == "random" then
					obj.direction = math.random(0, 3)*2
				elseif movement_type == "circle" then
					obj.direction = (obj.direction +2) %8
				elseif movement_type == "back/forth" then
					obj.direction = (obj.direction +4) %8
				elseif movement_type == "straight" then
					-- pass
				end
				obj.stream:set_direction(obj.direction)
				obj.times_till_change = 4
			else
				obj.times_till_change = obj.times_till_change -1
			end
			local x_offset, y_offset = 0, 0
			if 		obj.direction == 0 then x_offset = -8; y_offset =  8 
			elseif 	obj.direction == 2 then x_offset = -8; y_offset =  8
			elseif 	obj.direction == 4 then x_offset =  8; y_offset = -8
			elseif 	obj.direction == 6 then x_offset =  8; y_offset = -8 end
			obj:set_position(obj.position.x+x_offset, obj.position.y+y_offset, 0)
			pr.move_recurrent( obj, movement_type  )
		end
	m:start(obj)
end

return pr