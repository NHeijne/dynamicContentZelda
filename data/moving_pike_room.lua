maze_gen 			= maze_gen or require("maze_generator")
placement 	= placement or require("object_placement")

local log 			= require("log")
local table_util 	= require("table_util")
local area_util 	= require("area_util")
local num_util 		= require("num_util")

local pr = {}


function pr.make( parameters )
	pr.create_pike_room( parameters.areanumber, parameters.area_details, parameters.area, parameters.exit_areas, parameters.speed, parameters.width, parameters.movement )
end

function pr.create_pike_room( areanumber, area_details, area, exit_areas, speed, width, movement )
	local map = area_details.map
	if not map:get_entity("pikeroom_sensor_"..areanumber) then 
		if area_details.outside then
			maze_gen.set_map( map )
			maze_gen.set_room( area, 16, 0, "pikeroom_"..areanumber )
			local _, closed, _ = maze_gen.generate_path( exit_areas, false, width )
			local floor = map:get_entity("room_floor_"..areanumber)
			local floor_x, floor_y, layer = floor:get_position()
			local floor_w, floor_h = floor:get_size()
			floor:remove()
			local new_floor = map:create_dynamic_tile{name="room_floor_"..areanumber, layer=0, x=floor_x-24, y=floor_y-24, width=floor_w+48, height=floor_h+48, pattern=14, enabled_at_start=true}
			new_floor:bring_to_back()
			new_floor:set_optimization_distance(600)
			for i,area in ipairs(closed) do
				map:create_dynamic_tile{layer=0, x=area.x1, y=area.y1, width=area.x2-area.x1, height=area.y2-area.y1, pattern=275, enabled_at_start=true}
			end
			local hero_x, hero_y, layer = map:get_hero():get_position()
			local direction =  math.random(0, 3)*2
			local stream = map:create_stream{name="stream_area_"..areanumber, 
						  layer=0, x=floor_x, y=floor_y, 
						  direction=direction, speed=speed}
			local x, y, layer = new_floor:get_position()
			new_floor.position, new_floor.direction, new_floor.speed, new_floor.times_till_change, new_floor.stream = {x=x, y=y}, direction, speed, 4, stream
			pr.move_recurrent( new_floor, movement )
		else
			maze_gen.set_map( map )
			maze_gen.set_room( area, 16, 0, "pikeroom_"..areanumber )
			local pikes = {}
			local _, _, maze = maze_gen.generate_path( exit_areas, false, width )
			local area_list = {}
			local unvisited = maze_gen.get_not_visited( maze )
			for i,pos in ipairs(unvisited) do
				area_list[i] = maze_gen.pos_to_area(pos)
			end
			for i,area in ipairs(area_list) do
				local pike = map:create_enemy{name="pike_area_"..areanumber.."_nr_1", layer=0, x=area.x1+8, y=area.y1+13, direction=3, breed="pike_fixed"}
				pikes[i]=pike
			end
			local direction =  math.random(0, 3)*2
			local stream = map:create_stream{name="stream_area_"..areanumber, 
						  layer=0, x=area.x1, y=area.y1, 
						  direction=direction, speed=speed}
			local floor = map:get_entity("room_floor_"..areanumber)
			floor:set_optimization_distance(600)
			local x, y, layer = floor:get_position()
			floor.position, floor.direction, floor.speed, floor.times_till_change, floor.stream = {x=x, y=y}, direction, speed, 4, stream
			pr.move_recurrent( floor, movement )
		end
		local sensor_area = area_util.resize_area(area, {-32, -32, 32, 32})
		local room_sensor = placement.place_sensor( sensor_area, "pikeroom_sensor_"..areanumber, 0 )
		room_sensor.on_activated = 
			function() 
				local hero_x, hero_y, layer = map:get_hero():get_position()
				map:get_hero():save_solid_ground(hero_x, hero_y, layer)
				map:get_entity("stream_area_"..areanumber):set_position(hero_x, hero_y, layer)
				pr.start_logging( area_details, areanumber )
			end
		room_sensor.on_activated_repeat = 
			function() 
				local hero_x, hero_y, layer = map:get_hero():get_position()
				map:get_entity("stream_area_"..areanumber):set_position(hero_x, hero_y, layer)
			end
		room_sensor.on_left =
			function()
				map:get_hero():reset_solid_ground()
				pr.stop_logging()
			end
	else
		local hero_x, hero_y, layer = map:get_hero():get_position()
		map:get_entity("stream_area_"..areanumber):set_position(hero_x, hero_y, layer)
	end
end

function pr.start_logging( area_details, areanumber )
	
end

function pr.stop_logging()
end

function pr.move_recurrent( obj, movement_type )
	local m = sol.movement.create("path")
	m:set_speed(obj.speed)
	m:set_path{obj.direction, obj.direction}
	m:set_ignore_obstacles()
	m.on_finished = 
		function ()
			obj:set_position(obj.position.x, obj.position.y, 0)
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
			pr.move_recurrent( obj, movement_type  )
		end
	m:start(obj)
end

return pr