local map = ...

local q = require("ingamequestionnaire")

function map:on_started(destination)
	q.init("bouncer", map)
	q.map_number = 2
end