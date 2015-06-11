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
pg.pike_room_max_difficulty = 5
pg.sokoban_min_difficulty = 1
pg.sokoban_max_difficulty = 5
pg.maze_min_difficulty = 1
pg.maze_max_difficulty = 5


function pg.create_puzzle( puzzle_type, area, areanumber, exit_areas, exclusion, area_details )
	-- determine difficulty to be used
	local difficulty = math.random(pg[puzzle_type.."_min_difficulty"], pg[puzzle_type.."_max_difficulty"])
	-- determine parameters to be used
	local parameters = pg.get_parameters( puzzle_type, difficulty )
	parameters.area = area; 			parameters.areanumber = areanumber
	parameters.exit_areas = exit_areas; parameters.exclusion = exclusion
	parameters.area_details = area_details
	-- create a puzzle for a given room using the parameters
	return pg.make_puzzle( puzzle_type, parameters )
end

function pg.interpret_log( log )
	-- decide whether to increase/decrease the difficulty based on the log
	-- iff fast enough and not lost too many hearts then increase else decrease
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
	if difficulty >=3 then parameters.fireball_statues = num_util.difficulty-2 end
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