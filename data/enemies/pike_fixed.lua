local enemy = ...

-- Pike that does not move.

function enemy:on_created()

  self:set_life(1)
  self:set_damage(2)
  self:create_sprite("enemies/pike_fixed")
  self:set_size(16, 16)
  self:set_origin(8, 13)
  self:set_can_hurt_hero_running(true)
  self:set_invincible()
end

function enemy:on_attacking_hero(hero, enemy_sprite)
	hero:start_hurt(self, self:get_damage())
	hero:set_invincible(true, 800)
	local m = sol.movement.create("path")
	local direction = get_direction_between_pike_and_hero(self, hero)
	m:set_speed(96)
	m:set_path{direction}
	m:set_ignore_obstacles(false)
	hero:freeze()
	hero:set_animation("hurt")
	m:start(hero)
	m.on_obstacle_reached = function () m:stop() end
	m.on_finished = function () hero:unfreeze() end
end

function get_direction_between_pike_and_hero(pike, hero) -- from 1 to 2
	local pike_x, pike_y = pike:get_position()
	local hero_x, hero_y = hero:get_position()
	local x_diff, y_diff = hero_x-pike_x, hero_y-(pike_y-5)
	local dir8
	if x_diff < -8 then
		if y_diff < -8 then 	dir8 = 3
		elseif y_diff > 8 then 	dir8 = 5
		else 				dir8 = 4	end 
	elseif x_diff > 8 then
		if y_diff < -8 then 	dir8 = 1
		elseif y_diff > 8 then 	dir8 = 7
		else 				dir8 = 0	end 
	else
		if y_diff < -8 then 	dir8 = 2
		elseif y_diff > 8 then 	dir8 = 6
		else dir8 = ((hero:get_direction()+2)%4)*2 end 
	end
	return dir8
end