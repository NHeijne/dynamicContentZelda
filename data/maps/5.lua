map = ...
local game = map:get_game()

local variable_string1a = [[
With a large questhub 
we can split the 
available dialog among 
any number of NPCs.
]]
local variable_string1b=[[
So we determine which 
NPC says what based on
the player's actions 
at runtime.
]]

local variable_string1c=[[
Not only to keep it 
generatable but also 
to ensure that the 
player gets all the 
required info.
]]

local variable_string2 = [[
With a small questhub 
we place more info on 
a single NPC and give 
the player some 
options during the 
conversation.
]]

local question_1 = [[
Wanna hear more?
Yes
No
]]

local variable_string3 = [[
Going in depth with a 
single NPC might be 
more interesting for 
some than to run 
around the entire hub 
in search of answers.
]]

function test_npc_large_a:on_interaction()
	game:start_dialog("test.variable", variable_string1a)
end
function test_npc_large_b:on_interaction()
	game:start_dialog("test.variable", variable_string1b)
end
function test_npc_large_c:on_interaction()
	game:start_dialog("test.variable", variable_string1c)
end

function test_npc_small:on_interaction()
	game:start_dialog("test.variable", variable_string2, function() 
	game:start_dialog("test.question", question_1, function ( answer )
		if answer == 1 then
			game:start_dialog("test.variable", variable_string3)
		end
		-- body
	end)
	end)
end
