local log 				= require("log")
local table_util 		= require("table_util")
local area_util 		= require("area_util")
local num_util 			= require("num_util")

local fight_generator = {}
local difficultyOfFights = 1
local breedDifficulties = {["globul"]=3,["tentacle"]=1,["snap_dragon"]=3,--["pike_auto"]=2,["fireball_statue"]=2,
							["green_knight_soldier"]=2,["mandible"]=2,["red_knight_soldier"]=3,
							["minillosaur_egg_fixed"]=2,["blue_hardhat_beetle"]=3,["blue_bullblin"]=3}

function fight_generator.add_effects_to_sensors (map, areas, area_details)
	for sensor in map:get_entities("areasensor_inside_") do
		-- areasensor_<inside/outside>_5_type_<F for fights>
		local sensorname = sensor:get_name()
		local split_table = table_util.split(sensorname, "_")
		
		if split_table[5] == "F" then 
			sensor.on_activated = 
				function()
					local f = sol.file.open("userExperience.txt","a+"); f:write(sensor:get_name() .. "\n"); f:flush(); f:close()
					local game = map:get_game()
					local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-life\n"); f:flush(); f:close()
					local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-time\n"); f:flush(); f:close()
					local split_table = split_table
					
					for enemy in map:get_entities("generatedEnemy") do enemy:remove() end
					local spawnArea = areas["walkable"][tonumber(split_table[3])]
					
					local diff = difficultyOfFights
					local f = sol.file.open("userExperience.txt","a+"); f:write(diff .. "-difficulty\n"); f:flush(); f:close()
					
					local enemiesInEncounter = fight_generator.make(spawnArea, diff, map) 
					for _,enemy in pairs(enemiesInEncounter) do
						local theEnemyIJustMade = map:create_enemy(enemy)
						theEnemyIJustMade:set_treasure("random")
						local f = sol.file.open("userExperience.txt","a+") 
						f:write(theEnemyIJustMade:get_breed() .. "-spawned\n")
						f:flush(); f:close()
						
						function theEnemyIJustMade:on_hurt(attack)
							local f = sol.file.open("userExperience.txt","a+"); f:write(attack .. "-enemy\n"); f:flush(); f:close()
							-- returning false gives it back to the engine to handle
							return false
						end
						
						function theEnemyIJustMade:on_dead()
							if not map:has_entities("generatedEnemy") then 
								map:open_doors("door_normal_area_"..split_table[3])
								
								analyseGameplaySoFar(map)
								difficultyOfFights = difficultyOfFights + 1
								local game = map:get_game()
								local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-life\n"); f:flush(); f:close()
								local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-time\n"); f:flush(); f:close()
								local f = sol.file.open("userExperience.txt","a+"); f:write("finished the fight\n"); f:flush(); f:close()
								
							end
							return false
						end
						
					end
					map:close_doors("door_normal_area_"..split_table[3])
				end
		end
				
	end
end

function analyseGameplaySoFar(map)
	local f = sol.file.open("userExperience.txt","r")
	local nothing = {swordSwings=0, swordHits=0, gotHit=0, monsters=0, timeInRoom=0, 
			directionChange=0, lifeLostInRoom=0, uselessKeys=0, monsterTypes={}}
	local room = table_util.copy( nothing )

	while true do
		local line = f:read("*line")
		if not line then 
			break 
		end
		
		if line=="sword swinging-hero" then room.swordSwings = room.swordSwings + 1 end
		if line=="sword-enemy" then room.swordHits = room.swordHits + 1 end
		if line=="hurt-hero" then room.gotHit = room.gotHit + 1 end
		local splitLine = table_util.split(line, "-")
		if splitLine[2] == "spawned" then 
			room.monsters = room.monsters + 1 
			if room.monsterTypes[splitLine[1]] == nil then
				room.monsterTypes[splitLine[1]] = 1
			else
				room.monsterTypes[splitLine[1]] = room.monsterTypes[splitLine[1]] + 1
			end
		end
		if string.find(line, "life") then 
			local game = map:get_game()
			room.lifeLostInRoom = tonumber (splitLine[1]) - game:get_life()
		end
		if string.find(line, "time") then 
			room.timeInRoom = os.time() - tonumber (splitLine[1])
		end
		if line=="right-keypress" or line=="left-keypress" or line=="up-keypress" or line=="down-keypress" then 
			room.directionChange = room.directionChange + 1
		end
		if splitLine[2] == "keypress" and splitLine[1]~="right" and splitLine[1]~="left" and splitLine[1]~="up" and splitLine[1]~="down" 
				and splitLine[1]~="c" and splitLine[1]~="space" and splitLine[1]~="x" and splitLine[1]~="v" and splitLine[1]~="d" then 
			room.uselessKeys = room.uselessKeys + 1
		end
		if string.find(line, "areasensor") or string.find(line, "A NEW GAME IS STARTING NOW") then 
			room = table_util.copy( nothing )
		end	
	end
	
	f:flush(); f:close()
	log.debug( room )
end

function fight_generator.make(area, diff, map) 
	local difficulty = diff
	local enemiesInFight = {}
	
	local breedOptions={}
	for k,_ in pairs(breedDifficulties) do
		table.insert( breedOptions, k )
	end
	
	while difficulty > 0 do
		local hero = map:get_hero()
		local xPos,yPos = hero:get_position()
		while hero:get_distance(xPos,yPos) < 100 do
			xPos = math.random(area.x1+40, area.x2-40)
			yPos = math.random(area.y1+40, area.y2-40)
		end
		local chosenBreed = breedOptions[math.random(1,#breedOptions)] 
		while breedDifficulties[chosenBreed] > difficulty do 
			chosenBreed = breedOptions[math.random(1,#breedOptions)] 
		end
		-- monster = {name, layer, x,y, direction, breed,rank,savegame_variable, treasure_name,treasure_variant,treasure_savegame_variable}
		table.insert(enemiesInFight,{name="generatedEnemy_thisOne", layer=0, x=xPos, y=yPos, direction=0, breed=chosenBreed})
		difficulty = difficulty - breedDifficulties[chosenBreed]
	end
	return enemiesInFight
end

return fight_generator