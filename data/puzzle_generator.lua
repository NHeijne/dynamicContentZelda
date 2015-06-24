maze_gen 	= maze_gen or require("maze_generator")
pike_room 	= pike_room or require("moving_pike_room")
sokoban 	= sokoban or require("sokoban_parser")
placement 	= placement or require("object_placement")

local log 			= require("log")
local table_util 	= require("table_util")
local area_util 	= require("area_util")
local num_util 		= require("num_util")

local pg ={}

pg.pike_room_min_difficulty = 1
pg.pike_room_max_difficulty = 1
pg.sokoban_min_difficulty = 1
pg.sokoban_max_difficulty = 1
pg.maze_min_difficulty = 1
pg.maze_max_difficulty = 1

pg.puzzles_instantiated = {["maze"]=0, ["sokoban"]=0, ["pike_room"]=0}
pg.time_requirements = {["maze"]=30, ["sokoban"]=90, ["pike_room"]=20}
pg.areanumbers_filled = {}

function pg.create_puzzle( selection_type, area, areanumber, exit_areas, exclusion, area_details )
	local map_id = tonumber(map:get_id())
	pg.areanumbers_filled[map_id] = pg.areanumbers_filled[map_id] or {}
	if not pg.areanumbers_filled[map_id][areanumber] then pg.areanumbers_filled[map_id][areanumber] = true 
	else return end
	-- determine puzzle type
	local puzzle_type
	if table_util.contains({"maze", "pike_room", "sokoban"}, selection_type) then
		puzzle_type = selection_type
	elseif selection_type == "equal_amounts" then
		local min_amount = math.huge
		local puzzle_types_available = table_util.get_keys(pg.puzzles_instantiated)
		table_util.shuffleTable( puzzle_types_available )
		for _,pt in pairs(puzzle_types_available) do
			if pg.puzzles_instantiated[pt] < min_amount then 
				puzzle_type = pt
				min_amount = pg.puzzles_instantiated[pt]
			end
		end
		pg.puzzles_instantiated[puzzle_type] = pg.puzzles_instantiated[puzzle_type] + 1
	else puzzle_type = table_util.random({"maze", "pike_room", "sokoban"}) end

	-- determine difficulty to be used
	local difficulty = pg[puzzle_type.."_min_difficulty"]
	if game:get_life() > 16 then difficulty = pg[puzzle_type.."_max_difficulty"] end
	-- determine parameters to be used
	local parameters = pg.get_parameters( puzzle_type, difficulty )
	parameters.area = area; 			parameters.areanumber = areanumber    
	parameters.exit_areas = exit_areas; parameters.exclusion = exclusion
	parameters.area_details = area_details
	-- create a puzzle for a given room using the parameters
	return pg.make_puzzle( puzzle_type, parameters )
end

function pg.interpret_log( completed_puzzle_log )
	local cl = completed_puzzle_log
	if cl.deaths > 0 or cl.quit or ( cl.got_hurt > 4 and cl.time_end-cl.time_start > pg.time_requirements[cl.puzzle_type] )  then
		pg.decrease_min_max_difficulty( cl.puzzle_type )
	else
		pg.increase_min_max_difficulty( cl.puzzle_type )
	end
end

function pg.increase_min_max_difficulty( puzzle_type )
	if pg[puzzle_type.."_min_difficulty"] == 5 then
		return
	elseif pg[puzzle_type.."_max_difficulty"] == pg[puzzle_type.."_min_difficulty"] then
		pg[puzzle_type.."_max_difficulty"] = pg[puzzle_type.."_max_difficulty"] +1
	else
		pg[puzzle_type.."_min_difficulty"] = pg[puzzle_type.."_min_difficulty"] +1
	end
end

function pg.decrease_min_max_difficulty( puzzle_type )
	if pg[puzzle_type.."_max_difficulty"] == 1 then
		return
	elseif pg[puzzle_type.."_max_difficulty"] == pg[puzzle_type.."_min_difficulty"] then
		pg[puzzle_type.."_min_difficulty"] = pg[puzzle_type.."_min_difficulty"] -1
	else
		pg[puzzle_type.."_max_difficulty"] = pg[puzzle_type.."_max_difficulty"] -1
	end
end


function pg.get_parameters( puzzle_type, difficulty )
	return pg["get_"..puzzle_type.."_parameters"]( difficulty )
end

function pg.get_maze_parameters( difficulty )
	parameters = {darkness=false, fireball_statues=0}
	if difficulty >=2 then parameters.darkness = true end
	if difficulty >=3 then parameters.fireball_statues = difficulty-2 end
	return parameters
end

function pg.get_sokoban_parameters( difficulty )
	return {difficulty=difficulty}
end

function pg.get_pike_room_parameters( difficulty )
	local parameters = {}
	local choices = {	
						[-2]={{32, 2}},
						[-1]={{32,1.5}},
						[0]={{48, 1.5}, {32, 1}, {16, 0.5}},
						[1]={{56, 1.5}, {48, 1}, {32, 0.5}},
						[2]={{56, 1}, {48, 0.5}},
						movement={{"random",4}, {"circle",3}, {"back/forth",2}}}
	local current_difficulty = 0
	local movement
	repeat
		movement = table_util.random(choices.movement)
	until difficulty - movement[2] >= -2 and difficulty - movement[2] <= 2
	local selected_option = table_util.random(choices[difficulty-movement[2]])
	parameters.speed = 		selected_option[1]
	parameters.width = 		selected_option[2]
	parameters.movement = 	movement[1]
	return parameters
end

function pg.make_puzzle( puzzle_type, parameters )
	return pg["make_"..puzzle_type.."_puzzle"]( parameters )
end

function pg.make_sokoban_puzzle( parameters )
	sokoban.make( parameters )
end

function pg.make_pike_room_puzzle( parameters )
	pike_room.make( parameters )
end

function pg.make_maze_puzzle( parameters )
	maze_gen.make( parameters )
end

return pg