local map = ...

local content = require("content_generator")

function map:on_started(destination)
	content.start_test(map)
end
