local map = ...
local game = map:get_game()


-- Hero's house
-- HOUSE
-----------------------
--Sick kid/lil bro: 
local brother_talk =[[
You see your brother 
sweating profusely, 
wide awake but in a 
state of delerium.

What to do...
]]

local brother_talk_2 =[[
You see your brother 
sweating profusely, 
wide awake but in a 
state of delerium.
]]

local feed_cure=[[
You feed him the
Cure potion!
]]

local finale1 = [[
Your brother instantly
regains full 
consciousness!
]]

local finale2a=[[
But he still looks 
weak, he needs 
to rest...$0
You have saved the day!
]]

local finale2b=[[
He looks quite well,
the poison seems to
gone completely!$0
You have saved the day!
]]

-----------------------
--Dad/blacksmith: 
local dad_talk_q1 = game:get_player_name().."!\n"..[[
Your brother is really 
ill, we can't wait for 
the doctor to arrive
from out of town!

We have to save him!
Tell me what to do!
How'd this happen?
]]

--<answer 1> 
local dad_talk_q1_ans1 = [[
Get my sword and shield 
from the shed, here is
the key!
]]
--<hand over wooden key>
--<answer 2> 
local dad_talk_q1_ans2 = [[
He drank something from
the old brewer's stash.
Something poisonous no
doubt. 
]]
--<followed by answer 1>
local dad_talk_after = [[
Go to the witch in the 
woods to the east, ask
her for a cure potion!
Now go! Good luck!
]]
-----------------------
--Mom:
--<question 1>
local mom_talk_q1 = [[
Ohw my dear boy...
I'm worried sick, have
you spoken to your
father? 


I think he has a plan.
I will!
Father's plan?
]]
--<q1 answer 1>
local mom_talk_q1_ans1 =[[
Hurry back, I don't
know how long he can 
hold out...
]]

--<q1 answer 2> <q2>
local mom_talk_q2 =[[
Your father seems to
want to ask the witch
for help and try to
get the cure from her.
Why?
The witch?
]]

--<q2 answer 1>
local mom_talk_q2_ans1 =[[
He seems to hold a 
grudge against the old
brewer now that your 
brother got poisoned.
But your brother's
condition would've 
been much worse if
not for the brewer.
]]

--<q2 answer 2>
local mom_talk_q2_ans2 =[[
The witch lives in the 
woods to the east, 
there have been rumors 
going around, I don't
know the details though
and neither does your 
father...
]]


local function walk(npc)
  local m = sol.movement.create("path")
  m:set_path{0, 0,0, 0,0, 0, 2,2, 4, 4,4, 4,4, 4, 6, 6}
  m:set_speed(32)
  m:set_loop()
  m:start(npc)
end

local function random_walk(npc)

  local m = sol.movement.create("random_path")
  m:set_speed(32)
  m:start(npc)
end


function map:on_started(destination)
	if destination == start_position then
		sol.audio.play_music("beginning")
	end
  	walk(mom)
end

function dad:on_interaction( ... )
	if not game:get_value("shed_key") then
		game:start_dialog("test.question", dad_talk_q1, function(answer) 
			if answer == 1 then
				game:start_dialog("test.variable", dad_talk_q1_ans1, function() 
					hero:start_treasure("wooden_key", 1, "shed_key", function()
		            	game:start_dialog("test.variable", dad_talk_after)
		          	end)
				end)
			else
				game:start_dialog("test.variable", dad_talk_q1_ans2, function() 
					game:start_dialog("test.variable", dad_talk_q1_ans1, function() 
						hero:start_treasure("wooden_key", 1, "shed_key", function()
			            	game:start_dialog("test.variable", dad_talk_after)
			          	end)
					end)
				end)
			end
		end)
	else
		game:start_dialog("test.variable", dad_talk_after)
	end
end

function mom:on_interaction( ... )
	mom:stop_movement()
	game:start_dialog("test.question", mom_talk_q1, function(answer) 
		if answer == 1 then
			game:start_dialog("test.variable", mom_talk_q1_ans1)
		else
			game:start_dialog("test.question", mom_talk_q2, function(answer) 
				if answer == 1 then
					game:start_dialog("test.variable", mom_talk_q2_ans1)
				else
					game:start_dialog("test.variable", mom_talk_q2_ans2)
				end
			end)
		end
 	end)
end

function brother:on_interaction( ... )
	if game:get_value("diluted_cure") or game:get_value("strong_cure") then
		game:start_dialog("test.variable", brother_talk_2, function() 
			local hero_x, hero_y = hero:get_position()
			local c_entity = map:create_npc{ direction=0, x=hero_x, y=hero_y-24, layer=2, subtype=0, sprite="entities/items" }
			hero:freeze()
			hero:set_animation("brandish")
			c_entity:get_sprite():set_animation("cure")
			game:start_dialog("test.variable", feed_cure, function()
				local m = sol.movement.create("target")
				m:set_ignore_obstacles(true)
				local brother_x, brother_y = brother:get_position()
				m:set_target(brother_x, brother_y)
				m:start(c_entity)
				m.on_finished = function() 
					game:start_dialog("test.variable", finale1, function() 
						hero:set_animation("victory")
						if game:get_value("diluted_cure") then 
							game:start_dialog("test.variable", finale2a, function() 
								game_over()
							end)
						elseif game:get_value("strong_cure") then
							sheets:get_sprite():set_animation("empty_open")
							game:start_dialog("test.variable", finale2b, function() 
								game_over()
							end)
						end
					end)
				end
			end)
		end)
	else
		game:start_dialog("test.variable", brother_talk)
	end
end

local credits = [[
Programming:
Norbert Heijne
Arjen Swellengrebel$0$0
Thanks For Playing!
]]


function game_over()
	sol.audio.play_music("fanfare")
	game:start_dialog("test.variable", credits, function()
		    game:set_hud_enabled(false)
		    game:set_pause_allowed(false)
		    sol.timer.start(5000, function()
		      hero:set_visible(false)
		      sol.main.reset()
		    end)
      end)
end