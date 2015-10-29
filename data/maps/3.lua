local map = ...
game = map:get_game()

local content = require("content_generator")

function map:on_started(destination)
	content.set_planned_items_for_this_zone({"bomb_bag-1"})
	content.start_test(map, {branch_length=5}, {map_id="14", destination_name=nil})
end
