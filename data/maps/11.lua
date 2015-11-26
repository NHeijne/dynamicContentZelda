local map = ...

local q = require("ingamequestionnaire")
-----------------------
local explanation_start = [[
Hello traveler...
Nice to have a customer
at last...
You don't have enough
money for my products
you say?
Well fear not, the next
areas all contain ruins
off the main path...
You would certainly be
able to find something
of value!
Here is something to
help you on your way.
]]

local explanation_continued = [[
You can see if the area
is part of the main
path by looking for 
a signpost at the 
entrance and exit of
an area.
Don't worry, we'll be
right behind you...
And as soon as we find
a clear and safe area
I'll set up shop for
you again!
]]

function map:on_started(destination)
	q.init(map)
	q.map_number = 0
	game:start_dialog("test.variable", explanation_start, function() 
		hero:start_treasure("mystic_mirror", 1, "mystic_mirror", function() 
			game:start_dialog("test.variable", explanation_continued)
		end)
	end)
end