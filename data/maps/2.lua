local map = ...

local content = require("content_generator")

function map:on_started(destination)
	content.start_test(map, {mission_type="tutorial", fights=0, puzzles=5, length=5, area_size=1}, {map_id="0", destination_name=nil})
end
