local log 				= require("log")
local table_util 		= require("table_util")
local area_util 		= require("area_util")
local num_util 			= require("num_util")
local matrix			= require("matrix")

local fight_generator = {}
local lowestDifficulty = 1
local highestDifficulty = 5
local difficultyOfFights = lowestDifficulty

--OLD:
--[[
0.2244 * monsters +
-0.1209 * startLife +
0.8654 * globul +
-0.0779 * tentacle +
-0.2317 * snap +
1.0567 * greenKnight +
-0.1819 * mandible +
0.4246 * redKnight +
-0.1387 * egg +
0.68   * hardhat +
0.8188 * bullblin +
3.8072
]]
--[[
local allowedVariance = 0.1
local startLifeDifficulty = -0.1209
local monsterAmountDifficulty = 0.2244
local baseDifficulty = 3.8072
local breedDifficulties = {["globul"]=0.8654,["tentacle"]=-0.0779,["snap_dragon"]=-0.2317,--["pike_auto"]=2,["fireball_statue"]=2,
							["green_knight_soldier"]=1.0567,["mandible"]=-0.1819,["red_knight_soldier"]=0.4246,
							["minillosaur_egg_fixed"]=-0.1387,["blue_hardhat_beetle"]=0.68,["blue_bullblin"]=0.8188}
]]
	
--NEW:	
--[[
0.7312 * monsters +
-1.1636 * tentacle +
0.3998 * sna7yp +
-0.1424 * mandible +
0.9962 * redKnight +
-0.233  * egg +
0.5852 * hardhat +
1.3709
]]
local allowedVariance = 0.1
local startLifeDifficulty = 0
local monsterAmountDifficulty = 0.7312
local baseDifficulty = 1.3709
local breedDifficulties = {["globul"]=0,["tentacle"]=-1.1636,["snap_dragon"]=0.3998,
							["green_knight_soldier"]=0,["mandible"]=-0.1424,["red_knight_soldier"]=0.9962,
							["minillosaur_egg_fixed"]=-0.233,["blue_hardhat_beetle"]=0.5852,["blue_bullblin"]=0}

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
					local spawnArea = areas["walkable"][tonumber(split_table[3])][1]
					
					local diff = difficultyOfFights
					local f = sol.file.open("userExperience.txt","a+"); f:write(diff .. "-difficulty\n"); f:flush(); f:close()
					local enemiesInEncounter, resultingDiff = fight_generator.make(spawnArea, diff, map, game:get_life()) 
					local f = sol.file.open("userExperience.txt","a+"); f:write(resultingDiff .. "-intendedDifficulty\n"); f:flush(); f:close()

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
								if difficultyOfFights > highestDifficulty then difficultyOfFights = lowestDifficulty end
								local game = map:get_game()
								local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-life\n"); f:flush(); f:close()
								local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-time\n"); f:flush(); f:close()
								local f = sol.file.open("userExperience.txt","a+"); f:write("finished the fight\n"); f:flush(); f:close()
								
							end
							return false
						end
						
					end
					map:close_doors("door_normal_area_"..split_table[3])
					
					if not map:has_entities("generatedEnemy") then 
						map:open_doors("door_normal_area_"..split_table[3])
						
						analyseGameplaySoFar(map)
						difficultyOfFights = difficultyOfFights + 1
						if difficultyOfFights > highestDifficulty then difficultyOfFights = lowestDifficulty end
						local game = map:get_game()
						local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-life\n"); f:flush(); f:close()
						local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-time\n"); f:flush(); f:close()
						local f = sol.file.open("userExperience.txt","a+"); f:write("finished the fight\n"); f:flush(); f:close()
						
					end
					return false
					
				end
		end
				
	end
end

function analyseGameplaySoFar(map)
	local f = sol.file.open("userExperience.txt","r")
	local nothing = {swordHits=0, monsters=0, timeInRoom=0, directionChange=0, 
			lifeLostInRoom=0, uselessKeys=0, monsterTypes={}, heroStates={}, 
			moving=0, standing=0, percentageStanding=0, startingLife=0, intendedDifficulty=0}
	local room = table_util.copy( nothing )

	while true do
		local line = f:read("*line")
		if not line then 
			break 
		end
		
		local splitLine = table_util.split(line, "-")
		if line=="sword-enemy" then room.swordHits = room.swordHits + 1 end
		if splitLine[2] == "hero" then 
			if room.heroStates[splitLine[1]] == nil then
				room.heroStates[splitLine[1]] = 1
			else
				room.heroStates[splitLine[1]] = room.heroStates[splitLine[1]] + 1
			end
		end

		if splitLine[2] == "spawned" then 
			room.monsters = room.monsters + 1 
			if room.monsterTypes[splitLine[1]] == nil then
				room.monsterTypes[splitLine[1]] = 1
			else
				room.monsterTypes[splitLine[1]] = room.monsterTypes[splitLine[1]] + 1
			end
		end
		if line == "moving around" then 
			room.moving = room.moving + 1
		end
		if line == "standing still" then 
			room.standing = room.standing + 1
		end
		if string.find(line, "life") then 
			local game = map:get_game()
			room.lifeLostInRoom = tonumber (splitLine[1]) - game:get_life()
			room.startingLife = tonumber (splitLine[1])
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
		
		if splitLine[2] == "intendedDifficulty" then
			room.intendedDifficulty = tonumber (splitLine[1]) 
		end
	end
	
	if (room.moving+room.standing) ~= 0 then
		room.percentageStanding = room.standing/(room.moving+room.standing)
	end
	
	f:flush(); f:close()
	logTheRoom (room)
end

function logTheRoom (room) 
	local f = sol.file.open("roomSummaries.csv","a+")
	
	--hits,monsters,time,dirChange,lostLife,useless,moving,standing,percStand,startLife,
	--globul,tentacle,snap,greenKnight,mandible,redKnight,egg,hardhat,bullblin
	--free,freezed,grabbing,hurt,stairs,loading,spin,swinging,tapping
	
	f:write(room.swordHits .. ",")
	f:write(room.monsters .. ",")
	f:write(room.timeInRoom .. ",")
	f:write(room.directionChange .. ",")
	f:write(room.lifeLostInRoom .. ",")
	f:write(room.uselessKeys .. ",")
	f:write(room.moving .. ",")
	f:write(room.standing .. ",")
	f:write(room.percentageStanding .. ",")
	f:write(room.startingLife .. ",")
	
	f:write(room.monsterTypes.globul or 0); f:write(",")
	f:write(room.monsterTypes.tentacle or 0); f:write(",")
	f:write(room.monsterTypes.snap_dragon or 0); f:write(",")
	f:write(room.monsterTypes.green_knight_soldier or 0); f:write(",")
	f:write(room.monsterTypes.mandible or 0); f:write(",")
	f:write(room.monsterTypes.red_knight_soldier or 0); f:write(",")
	f:write(room.monsterTypes.minillosaur_egg_fixed or 0); f:write(",")
	f:write(room.monsterTypes.blue_hardhat_beetle or 0); f:write(",")
	f:write(room.monsterTypes.blue_bullblin or 0); f:write(",")

	f:write(room.heroStates.free or 0); f:write(",")
	f:write(room.heroStates.freezed or 0); f:write(",")
	f:write(room.heroStates.grabbing or 0); f:write(",")
	f:write(room.heroStates.hurt or 0); f:write(",")
	f:write(room.heroStates.stairs or 0); f:write(",")
	f:write(room.heroStates["sword loading"] or 0); f:write(",")
	f:write(room.heroStates["sword spin attack"] or 0); f:write(",")
	f:write(room.heroStates["sword swinging"] or 0); f:write(",")
	f:write(room.heroStates["sword tapping"] or 0); f:write(",")
	-- The following aren't being logged because they are not very useful for now.
	--"back to solid ground", "boomerang", "bow", "carrying", "falling", "forced walking", "hookshot", "jumping", 
	--"lifting", "plunging", "pulling", "pushing", "running", "stream", "swimming", "treasure", "using item", "victory"
	
--[[
0.1652 * hits +
-0.0269 * standing +
0.499  * hurt +
0.0412 * swinging +
1.3787
]]

	f:write( 0.1652 * room.swordHits + 
			-0.0269 * room.standing + 
			 0.499 * (room.heroStates.hurt or 0) + 
			 0.0412 * (room.heroStates["sword swinging"] or 0) + 
			 1.3787 ); f:write(",")
	f:write( room.intendedDifficulty )
	
	f:write("\n")
	f:flush(); f:close()
end

function fight_generator.make(area, maxDiff, map, currentLife) 

	local difficulty = baseDifficulty + startLifeDifficulty * currentLife
	local enemiesInFight = {}
	
	local breedOptions={}
	for k,_ in pairs(breedDifficulties) do
		table.insert( breedOptions, k )
	end
	while difficulty < maxDiff - allowedVariance do
		local hero = map:get_hero()
		local xPos,yPos = hero:get_position()
		while hero:get_distance(xPos,yPos) < 100 do
			xPos = math.random(area.x1+40, area.x2-40)
			yPos = math.random(area.y1+40, area.y2-40)
		end
		local chosenBreed = breedOptions[math.random(1,#breedOptions)] 

		while breedDifficulties[chosenBreed] + monsterAmountDifficulty + difficulty > maxDiff + allowedVariance  do 
			chosenBreed = breedOptions[math.random(1,#breedOptions)] 
		end
		-- monster = {name, layer, x,y, direction, breed,rank,savegame_variable, treasure_name,treasure_variant,treasure_savegame_variable}
		table.insert(enemiesInFight,{name="generatedEnemy_thisOne", layer=0, x=xPos, y=yPos, direction=0, breed=chosenBreed})
		difficulty = difficulty + breedDifficulties[chosenBreed] + monsterAmountDifficulty
	end
	return enemiesInFight, difficulty
end

return fight_generator