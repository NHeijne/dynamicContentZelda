local map = ...

local content = require("content_generator")

function map:on_started(destination)
	content.set_planned_items_for_this_zone({"glove-1"})
	content.start_test(map)
end
