local map = ...
local game = map:get_game()

-- witch hut

local witch_talk_a = [[
What do you want? If
you want any potions
you can buy them from
me as long as you have 
an empty bottle.

So what do you want?
I'll be going.
Cure Potion!
]]

local witch_talk_a_ans1 = [[
I don't have the
ingredient for it, so
you'll have to go and
get it! 
Hehehe...

You need a Cure Flower
which grows at the
other side of the mines
to the east.
If you bring me that
flower and 15 rupees
I can make a Cure
Potion for you.
]]

local witch_talk_a_ans1_after=[[
Go through the mines
to get to where the
flower usually grows.
The mines is really
infested nowadays.
Could use some 
cleaning up!
Hehehe...
]]

local witch_talk_end = [[
Here's the cure sonny.
I hope he gets better 
soon...
Hehehe...
]]

local witch_talk_after = [[
Buy some potions or 
leave...
Hehehe...
]]


local witch_flower_question=[[
Give flower and rupees?
Yes.
No.
]]

local witch_not_enough_rupees=[[
You don't have enough
rupees.
Hehehe...
]]

local witch_shoo =[[
Shoo! 
Go get that flower!
Hehehe...
]]

local cure_price = 15

local function potion_buying(shop_item)

  if game:get_first_empty_bottle() == nil then
    game:start_dialog("potion_shop.no_empty_bottle")
    return false
  end

  return true
end
diluted_red_potion.on_buying = potion_buying




function witch:on_interaction( ... )
	if not game:get_value("mine_key") then
		game:start_dialog("test.question", witch_talk_a, function(answer) 
			if answer == 2 then
				game:start_dialog("test.variable", witch_talk_a_ans1, function ()
					hero:start_treasure("rock_key", 1, "mine_key", function()
						game:start_dialog("test.variable", witch_talk_a_ans1_after)
	          		end)
				end)
			else
				game:start_dialog("test.variable", witch_talk_after)
			end
		end)
    elseif game:get_value("mine_key") and not game:get_value("quest_flower") and not game:get_value("diluted_cure") then
		game:start_dialog("test.variable", witch_shoo)
	elseif game:get_value("quest_flower") and not game:get_value("diluted_cure") then
		game:start_dialog("test.question", witch_flower_question, function(answer)
			if answer == 1 then
				if game:get_money() < cure_price then
					game:start_dialog("test.variable", witch_not_enough_rupees)
				else
					game:remove_money(cure_price) 
					game:set_value("quest_flower", false)
					hero:start_treasure("cure", 1, "diluted_cure", function()
			            game:start_dialog("test.variable", witch_talk_end)
			        end)
				end
			else
				game:start_dialog("test.variable", witch_shoo)
			end
		end)
    elseif game:get_value("diluted_cure") or game:get_value("strong_cure") then
    	game:start_dialog("test.variable", witch_talk_after)
	end
end