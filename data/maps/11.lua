local map = ...

local q = require("ingamequestionnaire")

function map:on_started(destination)
	q.init(map)
	q.map_number = 0
end