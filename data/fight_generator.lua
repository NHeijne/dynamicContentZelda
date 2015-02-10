local log 				= require("log")
local table_util 		= require("table_util")
local area_util 		= require("area_util")
local num_util 			= require("num_util")

local fight_generator = {}

function fight_generator.add_effects_to_sensors (map)
	for sensor in map:get_entities("sensor_pathway_") do
		sensor.on_activated = 	
				function() 
			
			
					local split_table = table_util.split(sensor:get_name(), "_")
					if split_table[11] == "intoarea" then 
						sol.audio.play_sound("jump")
						log.debug("goIntoArea")
					else 
						sol.audio.play_sound("secret")
						log.debug("goOutOfArea")
					end
					log.debug(split_table)
					
					
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
		local xPos = math.random(area.x1+8, area.x2-8)
		local yPos = math.random(area.y1+8, area.y2-8)
		local chosenBreed = breedOptions[math.random(1,#breedOptions)] 
		while breedDifficulties[chosenBreed] > difficulty do 
			chosenBreed = breedOptions[math.random(1,#breedOptions)] 
		end
		-- monster = {name, layer, x,y, direction, breed,rank,savegame_variable, treasure_name,treasure_variant,treasure_savegame_variable}
		table.insert(enemiesInFight,{layer=0, x=xPos, y=yPos, direction=0, breed=chosenBreed})
		difficulty = difficulty - breedDifficulties[chosenBreed]
	end
	return enemiesInFight
end

return fight_generator