local map = ...
game = map:get_game()

local content = require("content_generator")

function map:on_started(destination)
	content.set_planned_items_for_this_zone({"glove-2"})
	content.start_test(map, {branch_length=3}, {map_id="13", destination_name=nil})
end
