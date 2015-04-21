local log 				= require("log")
local table_util 		= require("table_util")
local area_util 		= require("area_util")
local num_util 			= require("num_util")
local learningAlgorithms = require("learningAlgorithms")
local matrix			= require("matrix")

local fight_generator = {}
local lowestDifficulty = 2
local highestDifficulty = 5
local difficultyOfFights = lowestDifficulty

local baseStress = 1.3787
local startLifeDifficulty = 0
local monsterAmountDifficulty = 0
local baseDifficulty = 0
local breedDifficulties = {	["minillosaur_egg_fixed"]	= 1,
							["mandible"]				= 1,
							["blue_hardhat_beetle"]		= 1,
							["green_knight_soldier"]	= 1}
							
local roomContentsData = {{0,0,0,0,1}}
local roomDifficulties = {{baseStress}}
		
local enemyTried = 1 -- To initialize the training data, we need to try every enemy.

function fight_generator.add_effects_to_sensors (map, areas, area_details)
	sensorSide = "areasensor_inside_"
	if area_details.outside then sensorSide = "areasensor_outside_" end

	for sensor in map:get_entities(sensorSide) do
		-- areasensor_<inside/outside>_5_type_<F for fights>
		local sensorname = sensor:get_name()
		local split_table = table_util.split(sensorname, "_")
		
		if split_table[5] == "F" then 
		
			sensor.on_activated = 
				function()
					local f = sol.file.open("userExperience.txt","a+"); f:write(sensor:get_name() .. "\n"); f:flush(); f:close()
					local f = sol.file.open("userExperience.txt","a+"); f:write(split_table[2] .. "-ofADungeon\n"); f:flush(); f:close()
					local game = map:get_game()
					local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-beginlife\n"); f:flush(); f:close()
					local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-starttime\n"); f:flush(); f:close()
					local split_table = split_table
					
					for enemy in map:get_entities("generatedEnemy") do enemy:remove() end
					local spawnArea = areas["walkable"][tonumber(split_table[3])][1]
					
					local diff = difficultyOfFights
					local f = sol.file.open("userExperience.txt","a+"); f:write(diff .. "-difficulty\n"); f:flush(); f:close()
					local enemiesInEncounter, resultingDiff = fight_generator.make(spawnArea, diff, map, game:get_life()) 
					local f = sol.file.open("userExperience.txt","a+"); f:write(resultingDiff .. "-intendedDifficulty\n"); f:flush(); f:close()

					for _,enemy in pairs(enemiesInEncounter) do
						local theEnemyIJustMade = map:create_enemy(enemy)
						theEnemyIJustMade:set_life(3)
						theEnemyIJustMade:set_damage(2)
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
							local f = sol.file.open("userExperience.txt","a+") 
							f:write(theEnemyIJustMade:get_breed() .. "-waskilled\n")
							f:flush(); f:close()
							
							if not map:has_entities("generatedEnemy") then 
								map:open_doors("door_normal_area_"..split_table[3])
								
								difficultyOfFights = difficultyOfFights + 1
								if difficultyOfFights > highestDifficulty then difficultyOfFights = lowestDifficulty end
								local game = map:get_game()
								local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-endlife\n"); f:flush(); f:close()
								local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-endtime\n"); f:flush(); f:close()
								local f = sol.file.open("userExperience.txt","a+"); f:write("finished-thefight\n"); f:flush(); f:close()
								analyseGameplaySoFar(map)
							end
							return false
						end
						
					end
					map:close_doors("door_normal_area_"..split_table[3])
					
					if not map:has_entities("generatedEnemy") then 
						map:open_doors("door_normal_area_"..split_table[3])
						
						difficultyOfFights = difficultyOfFights + 1
						if difficultyOfFights > highestDifficulty then difficultyOfFights = lowestDifficulty end
						local game = map:get_game()
						local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-endlife\n"); f:flush(); f:close()
						local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-endtime\n"); f:flush(); f:close()
						local f = sol.file.open("userExperience.txt","a+"); f:write("finished-thefight\n"); f:flush(); f:close()
						analyseGameplaySoFar(map)
						
					end
					return false
					
				end
				
			sensor.on_left = 
				function()
					if map:has_entities("generatedEnemy") then
						difficultyOfFights = difficultyOfFights + 1
						if difficultyOfFights > highestDifficulty then difficultyOfFights = lowestDifficulty end
						local game = map:get_game()
						local f = sol.file.open("userExperience.txt","a+"); f:write(game:get_life() .. "-endlife\n"); f:flush(); f:close()
						local f = sol.file.open("userExperience.txt","a+"); f:write(os.time() .. "-endtime\n"); f:flush(); f:close()
						local f = sol.file.open("userExperience.txt","a+"); f:write("ranawayfrom-thefight\n"); f:flush(); f:close()
						analyseGameplaySoFar(map)
					end
				end
		end
				
	end
end

function analyseGameplaySoFar(map)
	local f = sol.file.open("userExperience.txt","r")
	local nothing = {fightFinished=0, swordHits=0, monstersKilled=0, timeInRoom=0, directionChange=0, 
			lifeLostInRoom=0, uselessKeys=0, monsterTypes={}, monsterTypesKilled={}, heroStates={}, 
			moving=0, standing=0, percentageStanding=0, startingLife=0, intendedDifficulty=0, insideDungeon=0}
	local room = table_util.copy( nothing )

	while true do
		local line = f:read("*line")
		if not line then break end
		
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
			if room.monsterTypes[splitLine[1]] == nil then
				room.monsterTypes[splitLine[1]] = 1
			else
				room.monsterTypes[splitLine[1]] = room.monsterTypes[splitLine[1]] + 1
			end
		end
		if splitLine[2] == "waskilled" then 
			room.monstersKilled = room.monstersKilled + 1 
			if room.monsterTypesKilled[splitLine[1]] == nil then
				room.monsterTypesKilled[splitLine[1]] = 1
			else
				room.monsterTypesKilled[splitLine[1]] = room.monsterTypesKilled[splitLine[1]] + 1
			end
		end
		if line == "moving around" then 
			room.moving = room.moving + 1
		end
		if line == "standing still" then 
			room.standing = room.standing + 1
		end
		if string.find(line, "beginlife") then 
			local game = map:get_game()
			room.lifeLostInRoom = tonumber (splitLine[1]) - game:get_life()
			room.startingLife = tonumber (splitLine[1])
		end
		if string.find(line, "thefight") then 
			room.fightFinished = (splitLine[1] == "finished") and 1 or 0
		end
		if string.find(line, "ofADungeon") then 
			room.insideDungeon = (splitLine[1] == "inside") and 1 or 0
		end
		if string.find(line, "starttime") then 
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
	local weights = learningAlgorithms.linearRegression(roomContentsData, roomDifficulties)
	
	if weights then updateWeights( weights ) end
end

function updateWeights (weights)
	breedDifficulties["minillosaur_egg_fixed"] = weights[1][1] --room.monsterTypes.minillosaur_egg_fixed
	breedDifficulties["mandible"] = weights[2][1] --room.monsterTypes.mandible
	breedDifficulties["blue_hardhat_beetle"] = weights[3][1] --room.monsterTypes.blue_hardhat_beetle
	breedDifficulties["green_knight_soldier"] = weights[4][1] --room.monsterTypes.green_knight_soldier
	--startLifeDifficulty = weights[6][1] --room.startingLife
	baseDifficulty = weights[5][1]--bias
	
	log.debug( weights )
end

function absolute( number )
	if number < 0 then
		return -number
	else
		return number
	end
end

function logTheRoom (room) 
	local fightRoomData = {}
	local playerBehaviourData = {}
	local bias = 1
	
	fightRoomData[#fightRoomData+1] = room.monsterTypes.minillosaur_egg_fixed or 0
	fightRoomData[#fightRoomData+1] = room.monsterTypes.mandible or 0
	fightRoomData[#fightRoomData+1] = room.monsterTypes.blue_hardhat_beetle or 0
	fightRoomData[#fightRoomData+1] = room.monsterTypes.green_knight_soldier or 0
	--fightRoomData[#fightRoomData+1] = room.startingLife
	fightRoomData[#fightRoomData+1] = bias
	
	
	playerBehaviourData[#playerBehaviourData+1] = room.insideDungeon
	playerBehaviourData[#playerBehaviourData+1] = room.fightFinished
	playerBehaviourData[#playerBehaviourData+1] = room.swordHits
	playerBehaviourData[#playerBehaviourData+1] = room.timeInRoom
	playerBehaviourData[#playerBehaviourData+1] = room.directionChange
	playerBehaviourData[#playerBehaviourData+1] = room.lifeLostInRoom
	playerBehaviourData[#playerBehaviourData+1] = room.uselessKeys
	playerBehaviourData[#playerBehaviourData+1] = room.moving
	playerBehaviourData[#playerBehaviourData+1] = room.standing
	playerBehaviourData[#playerBehaviourData+1] = room.percentageStanding
	
	playerBehaviourData[#playerBehaviourData+1] = room.monsterTypesKilled.minillosaur_egg_fixed or 0
	playerBehaviourData[#playerBehaviourData+1] = room.monsterTypesKilled.mandible or 0
	playerBehaviourData[#playerBehaviourData+1] = room.monsterTypesKilled.blue_hardhat_beetle or 0
	playerBehaviourData[#playerBehaviourData+1] = room.monsterTypesKilled.green_knight_soldier or 0

	playerBehaviourData[#playerBehaviourData+1] = room.heroStates.free or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates.freezed or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates.grabbing or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates.hurt or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates.stairs or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["sword loading"] or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["sword spin attack"] or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["sword swinging"] or 0
	playerBehaviourData[#playerBehaviourData+1] = room.heroStates["sword tapping"] or 0
	
	-- The following aren't being logged because they are not very useful for now.
	--"back to solid ground", "boomerang", "bow", "carrying", "falling", "forced walking", "hookshot", "jumping", 
	--"lifting", "plunging", "pulling", "pushing", "running", "stream", "swimming", "treasure", "using item", "victory"
	
	roomDifficultyPrediction = { 0.1652 * room.swordHits + 
			-0.0269 * room.standing + 
			 0.499 * (room.heroStates.hurt or 0) + 
			 0.0412 * (room.heroStates["sword swinging"] or 0) + 
			 1.3787 }
	roomDifficultyIntention = { room.intendedDifficulty }
	
	writeTableToFile (fightRoomData, "roomSummaries.csv")
	local f = sol.file.open("roomSummaries.csv","a+"); f:write(","); f:flush(); f:close()
	writeTableToFile (playerBehaviourData, "roomSummaries.csv")
	local f = sol.file.open("roomSummaries.csv","a+"); f:write(","); f:flush(); f:close()
	writeTableToFile (roomDifficultyPrediction, "roomSummaries.csv")
	local f = sol.file.open("roomSummaries.csv","a+"); f:write(","); f:flush(); f:close()
	writeTableToFile (roomDifficultyIntention, "roomSummaries.csv")
	local f = sol.file.open("roomSummaries.csv","a+"); f:write("\n"); f:flush(); f:close()
	
	roomContentsData[#roomContentsData+1] = fightRoomData
	roomDifficulties[#roomDifficulties+1] = roomDifficultyPrediction
	
end

function writeTableToFile (dataTable, file) 
	local f = sol.file.open(file,"a+")
	for k,v in pairs(dataTable) do
		f:write(v); 
		if k ~= #dataTable then
			f:write(",") 
		end
	end
	f:flush(); f:close()
end

function fight_generator.make(area, maxDiff, map, currentLife) 

	local breedOptions={}
	for k,_ in pairs(breedDifficulties) do
		table.insert( breedOptions, k )
	end

	if enemyTried <= 4 then 
		local hero = map:get_hero()
		local xPos,yPos = hero:get_position()
		while hero:get_distance(xPos,yPos) < 100 do
			xPos = math.random(area.x1+40, area.x2-40)
			yPos = math.random(area.y1+40, area.y2-40)
		end
		local chosenBreed = breedOptions[enemyTried]
		enemyTried=enemyTried+1
		return {{name="generatedEnemy_thisOne", layer=0, x=xPos, y=yPos, direction=0, breed=chosenBreed}}, breedDifficulties[chosenBreed]
	end
	
	if enemyTried == 5 then enemyTried=6; difficultyOfFights = lowestDifficulty end

	local difficulty = baseDifficulty + startLifeDifficulty * currentLife
	local enemiesInFight = {}
	
	while difficulty < maxDiff do
		local hero = map:get_hero()
		local xPos,yPos = hero:get_position()
		while hero:get_distance(xPos,yPos) < 100 do
			xPos = math.random(area.x1+40, area.x2-40)
			yPos = math.random(area.y1+40, area.y2-40)
		end
		
		local chosenBreed = breedOptions[math.random(1,#breedOptions)] 
		local chosenDifficulty = breedDifficulties[chosenBreed]
		if chosenDifficulty <= 0 then chosenDifficulty = 1 end
		
		local iterations = 0
		while absolute( maxDiff - (difficulty+chosenDifficulty+monsterAmountDifficulty) ) >= absolute( maxDiff - difficulty ) do
			iterations = iterations + 1
			if iterations > 40 then break end
			chosenBreed = breedOptions[math.random(1,#breedOptions)] 
			chosenDifficulty = breedDifficulties[chosenBreed]
			if chosenDifficulty <= 0 then chosenDifficulty = 1 end
		end
		
		-- monster = {name, layer, x,y, direction, breed,rank,savegame_variable, treasure_name,treasure_variant,treasure_savegame_variable}
		table.insert(enemiesInFight,{name="generatedEnemy_thisOne", layer=0, x=xPos, y=yPos, direction=0, breed=chosenBreed})
		difficulty = difficulty + chosenDifficulty + monsterAmountDifficulty
	end
	return enemiesInFight, difficulty
end

return fight_generator