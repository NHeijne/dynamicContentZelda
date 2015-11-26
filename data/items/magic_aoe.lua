local item = ...

function item:on_created()
	self:set_savegame_variable("i1100")
 	self:set_assignable(true)
end		

-- light up the screen, take example from light manager
-- immobilize all enemies on_screen
-- uses magic
-- animation: brandish mirror and flash -> immobilize 
