local log 				= require("log")
local table_util 		= require("table_util")
local area_util 		= require("area_util")
local num_util 			= require("num_util")

local fight_generator = {}

function fight_generator.add_effects_to_sensors (map, areas)
	for sensor in map:get_entities("sensor_pathway_") do
		sensor.on_activated = 	
				
				
				function() 
					-- sensor_pathway_<path_type: direct / indirect>_<direction: fwd / bkw >
					--		 _f_<from areanumber>_t_<to areanumber>
					--		 _con_<connection_nr for specific transition>_<exitarea / intoarea>
					local split_table = table_util.split(sensor:get_name(), "_")
					if split_table[11] == "intoarea" then 
						for enemy in map:get_entities("pregenEnemy") do
							enemy:remove()
						end
						local spawnArea = areas["walkable"][tonumber(split_table[8])]
						local enemiesInEncounter = fight_generator.make(spawnArea, 5) 
						for _,enemy in pairs(enemiesInEncounter) do
							enemy.layer = 0
							local theEnemyIJustMade = map:create_enemy(enemy)
							
							function theEnemyIJustMade:on_hurt(attack)
								-- log the key
								local f = sol.file.open("userExperience.txt","a+"); f:write(attack .. "-enemy\n"); f:flush(); f:close()
								-- returning false gives it back to the engine to handle
								return false
							end
							
						end
					else 
						log.debug("goOutOfArea")
						local f = sol.file.open("userExperience.txt","a+"); f:write("Just-Exited-An-Area" .. "\n"); f:flush(); f:close()
					end
				end
				
				
	end
end

function fight_generator.make(area, diff) 
	local difficulty = diff
	local enemiesInFight = {}
	local breedDifficulties = {["Tentacle"]=1,["lizalfos"]=4,["green_knight_soldier"]=2,["green_duck_soldier"]=3}
	
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