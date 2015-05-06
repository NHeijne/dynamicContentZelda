local map = ...

local content = require("content_generator")

function map:on_started(destination)
	content.start_test(map, {mission_type="tutorial", fights=4, puzzles=0, length=4}, {map_id="0", destination_name=nil})
end
