local map = ...
game = map:get_game()

local content = require("content_generator")

function map:on_started(destination)
	content.set_planned_items_for_this_zone({"glove-1"})
	content.start_test(map, {branch_length=1}, {map_id="12", destination_name=nil})
end
