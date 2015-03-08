custom_entity = ...

local attack_on = false
local map = nil
local x, y
local interval = 4000

function custom_entity:attack()
  local son_name = self:get_name() .. "_son_1" 
  
    local son = map:create_enemy{
      name = son_name,
      breed = "red_projectile",
      x = x,
      y = y,
      layer = 2,
      direction=0
    }
  sol.timer.start(self, 500, function()
    sol.audio.play_sound("boss_fireball")
    son:go(angle)
  end)
end

function custom_entity:start()
  attack_on = true
  sol.timer.start(self, math.random(1000, 3000), function()
  	self:check()
  end)
end

function custom_entity:stop()
  attack_on = false
end

function custom_entity:check()
  if attack_on then
    self:attack()
    sol.timer.start(self, interval, function()
      self:check()
    end)
  end
end

function custom_entity:set_interval(milliseconds)
	interval = milliseconds
end

function custom_entity:on_created()
	map = self:get_map()
	x, y = self:get_position()
	self:set_traversable_by(false)
	self:create_sprite("entities/fireball_statue")
end