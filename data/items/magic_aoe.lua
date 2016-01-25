local item = ...

function item:on_created()
	self:set_savegame_variable("i1100")
 	self:set_assignable(true)
end		

local bright_surfaces = {
  [0] = sol.surface.create("entities/bright0.png"),
  [1] = sol.surface.create("entities/bright1.png"),
  [2] = sol.surface.create("entities/bright2.png"),
  [3] = sol.surface.create("entities/bright3.png")
}
local white = {255, 255, 255}

function item:on_using()
	map.draw_these_effects.magic_aoe = map.draw_these_effects.magic_aoe or function(map, dst_surface)
			if map.magic_aoe_surface then
				local hero_x, hero_y = hero:get_position()
				local screen_width, screen_height = dst_surface:get_size()
				local camera_x, camera_y = map:get_camera_position()
			    local x = 320 - hero_x + camera_x
			    local y = 240 - hero_y + camera_y -24
			    map.magic_aoe_surface:draw_region(x, y, screen_width, screen_height, dst_surface)
			end
		end
	local magic_needed = 24
	local game = self:get_game()
	local map = self:get_map()
	if game:get_magic() >= magic_needed then
		local f = sol.file.open("userExperience.txt","a+"); f:write("mirror-used\n"); f:flush(); f:close()
		sol.audio.play_sound("magic_bar")
		game:remove_magic(magic_needed)
		hero:freeze()
		hero:set_animation("brandish")
		local hero_x, hero_y = hero:get_position()
		local c_entity = map:create_npc{ direction=0, x=hero_x, y=hero_y-24, layer=2, subtype=0, sprite="entities/items" }
		c_entity:get_sprite():set_animation("magic_aoe")
		-- light up the screen, take example from light manager
		self:light_up_room()
	    self:immobilize_enemies() 
		map.magic_aoe_surface = bright_surfaces[0]
	    sol.timer.start(item, 100, 
	    	function () 
	    		map.magic_aoe_surface = bright_surfaces[1]
			    sol.timer.start(item, 100, 
		    	function () 
		    		map.magic_aoe_surface = bright_surfaces[2]
				    sol.timer.start(item, 100, 
			    	function () 
					    map.magic_aoe_surface:fill_color(white)
					    sol.timer.start(item, 100, function () 
					    	hero:unfreeze()
	    					c_entity:remove()
	    					map.magic_aoe_surface = nil
	    				end)
			    	end)
		    	end)
	    	end)

    else
		sol.audio.play_sound("wrong")	
	end
end





function item:light_up_room()
	if map.light then
		map.temporary_light = true
		sol.timer.start(item, 3000, function () map.temporary_light = false end) 
	end
end

function item:immobilize_enemies() 
	for entity in map:get_entities("generatedEnemy") do
		if entity:get_sprite():has_animation("immobilized") then
			entity:immobilize()
		end
	end
end