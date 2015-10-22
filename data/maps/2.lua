local map = ...
game = map:get_game()

local content = require("content_generator")

function map:on_started(destination)
	content.set_planned_items_for_this_zone({"glove-2"})
	content.start_test(map, {}, {map_id="5", destination_name="dungeon_entrance_left"})
end
