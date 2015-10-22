local map = ...
game = map:get_game()

local content = require("content_generator")

function map:on_started(destination)
	content.start_test(map, {mission_type="tutorial", fights=4, puzzles=3, length=7, area_size=1}, {map_id="1", destination_name=nil})
end
