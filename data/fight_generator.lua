local log 				= require("log")
local table_util 		= require("table_util")
local area_util 		= require("area_util")
local num_util 			= require("num_util")

local fight_generator = {}
difficultyOfFights = 0
local breedDifficulties = {["Tentacle"]=1,["lizalfos"]=4,["green_knight_soldier"]=2,["green_duck_soldier"]=3,["ropa"]=1}

function fight_generator.add_effects_to_sensors (map, areas, area_details)
	for sensor in map:get_entities("sensor_pathway_") do
		-- sensor_pathway_<path_type: direct / indirect>_<direction: fwd / bkw >
		--		 _f_<from areanumber>_t_<to areanumber>
		--		 _con_<connection_nr for specific transition>_<exitarea / intoarea>
		local split_table = table_util.split(sensor:get_name(), "_")
		local is_fight_area = area_details[tonumber(split_table[8])].area_type == "F" 

		if is_fight_area then sensor.on_activated = 	
				
				function() 
					local split_table = split_table
					if split_table[11] == "intoarea" then 
						for enemy in map:get_entities("pregenEnemy") do
							enemy:remove()
						end
						local spawnArea = areas["walkable"][tonumber(split_table[8])]
						
						analyseGameplaySoFar()
						
						difficultyOfFights = difficultyOfFights + 1
						local diff = difficultyOfFights
						local f = sol.file.open("userExperience.txt","a+"); f:write(diff .. "-difficulty\n"); f:flush(); f:close()
						
						local enemiesInEncounter = fight_generator.make(spawnArea, diff) 
						for _,enemy in pairs(enemiesInEncounter) do

							local theEnemyIJustMade = map:create_enemy(enemy)
							local f = sol.file.open("userExperience.txt","a+")
							f:write(theEnemyIJustMade:get_breed() .. "-spawned\n")
							f:flush(); f:close()
							
							function theEnemyIJustMade:on_hurt(attack)
								local f = sol.file.open("userExperience.txt","a+"); f:write(attack .. "-enemy\n"); f:flush(); f:close()
								-- returning false gives it back to the engine to handle
								return false
							end
							
						end
					end
					local f = sol.file.open("userExperience.txt","a+"); f:write(sensor:get_name() .. "\n"); f:flush(); f:close()
				end
		end
				
	end
end

function analyseGameplaySoFar()
	local f = sol.file.open("userExperience.txt","r")
	local nothing = {swordSwings=0, swordHits=0, gotHit=0, monsters=0}
	local room = table_util.copy( nothing )

	while true do
		local line = f:read("*line")
		if not line then 
			log.debug( room ); break 
		end
		
		if line=="sword swinging-hero" then room.swordSwings = room.swordSwings + 1 end
		if line=="sword-enemy" then room.swordHits = room.swordHits + 1 end
		if line=="hurt-hero" then room.gotHit = room.gotHit + 1 end
		if string.find(line, "spawned") then room.monsters = room.monsters + 1 end
		if string.find(line, "intoarea") or string.find(line, "A NEW GAME IS STARTING NOW") then 
			log.debug( room )
			room = table_util.copy( nothing )
		end	
	end
	
	f:flush(); f:close()
	log.debug( room )
end

function fight_generator.make(area, diff) 
	local difficulty = diff
	local enemiesInFight = {}
	
	local breedOptions={}
	for k,_ in pairs(breedDifficulties) do
		table.insert( breedOptions, k )
	end
	
	while difficulty > 0 do
		local xPos = math.random(area.x1+32, area.x2-32)
		local yPos = math.random(area.y1+32, area.y2-32)
		local chosenBreed = breedOptions[math.random(1,#breedOptions)] 
		while breedDifficulties[chosenBreed] > difficulty do 
			chosenBreed = breedOptions[math.random(1,#breedOptions)] 
		end
		-- monster = {name, layer, x,y, direction, breed,rank,savegame_variable, treasure_name,treasure_variant,treasure_savegame_variable}
		table.insert(enemiesInFight,{name="pregenEnemy_thisOne", layer=0, x=xPos, y=yPos, direction=0, breed=chosenBreed})
		difficulty = difficulty - breedDifficulties[chosenBreed]
	end
	return enemiesInFight
end

return fight_generator