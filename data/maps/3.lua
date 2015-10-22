local map = ...
game = map:get_game()

local content = require("content_generator")

function map:on_started(destination)
	content.set_planned_items_for_this_zone({"bomb_bag-1"})
	content.start_test(map, {}, {map_id="4", destination_name=nil})
end
