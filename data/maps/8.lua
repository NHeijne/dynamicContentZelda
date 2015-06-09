local map = ...

local direction = 0
local speed = 32
local times_till_change = 4

local mf = map:create_dynamic_tile{name="movingfloor", layer=0, x=16, y=16, width=320-32, height=240-32, pattern="2", enabled_at_start=true}
--map:create_dynamic_tile{name="wall", layer=0, x=0, y=0, width=32, height=240, pattern="369", enabled_at_start=true}
--map:create_dynamic_tile{name="wall", layer=0, x=320-32, y=0, width=32, height=240, pattern="369", enabled_at_start=true}
--map:create_dynamic_tile{name="wall", layer=0, x=32, y=0, width=320-64, height=32, pattern="369", enabled_at_start=true}
--map:create_dynamic_tile{name="wall", layer=0, x=32, y=240-32, width=320-64, height=32, pattern="369", enabled_at_start=true}
local stream1 = map:create_stream{name="stream_1", 
					  layer=0, x=32+8, y=32+13, 
					  direction=direction, speed=speed}
local hero = map:get_hero()

function map:on_started()
	move( mf )
end

function move( obj )
	obj:bring_to_back()
	local m = sol.movement.create("path")
	m:set_speed(speed)
	m:set_path{direction, direction}
	m:set_ignore_obstacles()
	m.on_finished = 
		function ()
			obj:set_position(16, 16, 0)
			if times_till_change == 0 then
				direction = (direction +2) %8
				stream1:set_direction(direction)
				times_till_change = 4
			else
				times_till_change = times_till_change -1
			end
			move( obj )
		end
	m:start(obj)
end

function moving_sensor:on_activated()
	local hero_x, hero_y, layer = hero:get_position()
	stream1:set_position(hero_x, hero_y, layer)
end

function moving_sensor:on_activated_repeat()
	local hero_x, hero_y, layer = hero:get_position()
	stream1:set_position(hero_x, hero_y, layer)
end
