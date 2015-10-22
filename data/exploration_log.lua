local el = {}

local table_util 		= require("table_util")
local num_util 			= require("num_util")

el.log = {}

el.new_log = {
	-- personal settings
	name=game:get_player_name(),
	openness=game:get_value("Openness"),
	conscientiousness=game:get_value("Conscientiousness"),
	extraversion=game:get_value("Extraversion"),
	agreeableness=game:get_value("Agreeableness"),
	neuroticism=game:get_value("Neuroticism"),

	-- generation settings
	length=6,
	branches=4,
	branch_length=0,
	fights=0,
	puzzles=0,
	outside=0, 
	mission_type=0,
	area_size=0,
	fights_to_puzzle_rooms_ratio=0,

	-- live data
	total_rooms=0,
	rooms_visited=0,
	unique_rooms_visited=0,
	perc_unique_rooms_visited=0,

	rewards_available=4,
	rewards_retrieved=0,
	perc_rewards_retrieved=0,

	total_time_spent=0,
	total_time_spent_optional=0,
	total_time_spent_main=0,
	perc_total_time_spent_optional=0,
	perc_total_time_spent_main=0,

	total_fights_encountered=0,
	total_fights_finished=0,
	total_time_spent_fighting=0,
	total_puzzles_encountered=0,
	total_puzzles_finished=0,
	total_time_spent_puzzling=0,
	fights_to_puzzle_time_ratio=0,
	total_time_spent_other=0,
	fights_to_puzzle_encounter_ratio=0
}

el.log_order = {
	"name", -- DONE 
	"openness", -- DONE 
	"conscientiousness", -- DONE 
	"extraversion", -- DONE 
	"agreeableness", -- DONE 
	"neuroticism", -- DONE 
	"length", -- DONE 
	"branches", -- DONE 
	"branch_length", -- DONE 
	"fights", -- DONE 
	"puzzles", -- DONE 
	"outside",  -- DONE 
	"mission_type", -- DONE 
	"area_size", -- DONE 
	"fights_to_puzzle_rooms_ratio", -- DONE 
	"total_rooms", --DONE
	"rooms_visited", -- DONE 
	"unique_rooms_visited", -- DONE 
	"perc_unique_rooms_visited", -- DONE 
	"rewards_available", -- DONE
	"rewards_retrieved", -- DONE
	"perc_rewards_retrieved", -- DONE
	"total_time_spent", -- DONE 
	"total_time_spent_optional", -- DONE 
	"total_time_spent_main", -- DONE 
	"perc_total_time_spent_optional", -- DONE
	"perc_total_time_spent_main", -- DONE
	"total_fights_encountered", -- DONE
	"total_fights_finished", -- DONE
	"total_time_spent_fighting", -- DONE
	"total_puzzles_encountered", -- DONE
	"total_puzzles_finished", -- DONE
	"total_time_spent_puzzling", -- DONE
	"fights_to_puzzle_time_ratio", -- DONE
	"total_time_spent_other", -- DONE
	"fights_to_puzzle_encounter_ratio" -- DONE
}

local log_helper = {
	time_start_of_level=0,
	time_start=0,
	time_end=0,
	areanumbers_visited={},
	main_path=true
}

local area_details

function el.generation_input( parameters )
	local l = el.log
	for k,v in pairs(parameters) do	l[k]=v end
	l.fights_to_puzzle_rooms_ratio = l.fights / l.puzzles
end

function el.copy_new_log()
	el.log = table_util.copy(el.new_log)
end

function el.start_recording( area_details )
	area_details = area_details
	el.copy_new_log()

	log_helper.time_start_of_level = os.clock()
end

function el.puzzle_encountered( ) el.incr( "total_puzzles_encountered" ) end
function el.puzzle_finished ( time_spent ) 
	el.incr( "total_time_spent_puzzling", time_spent ) 
	el.incr( "total_puzzles_finished")
end
function el.fight_encountered( ) el.incr( "total_fights_encountered" ) end
function el.fight_finished( time_spent ) 
	el.incr( "total_time_spent_fighting", time_spent )
	el.incr( "total_fights_finished") 
end

function el.incr( key, increment )
	increment = increment or 1
	el.log[key] = el.log[key] + increment
end

function el.entered_area( areanumber ) -- branches or main
	el.incr( "rooms_visited" )
	if not log_helper.areanumbers_visited[areanumber] then 
		el.incr( "unique_rooms_visited" )
	end
	log_helper.areanumbers_visited[areanumber] = true
	log_helper.time_end = os.clock()
	if log_helper.main_path == true then
		el.incr( "total_time_spent_main", log_helper.time_end-log_helper.time_start )
	elseif log_helper.main_path == false then
		el.incr( "total_time_spent_optional", log_helper.time_end-log_helper.time_start )
	end
	log_helper.time_start = os.clock()
	log_helper.main_path=area_details[areanumber].main
end

function el.finished_level( )
	-- calculate the percentages
	local l = el.log
	l.total_time_spent=os.clock()-log_helper.time_start_of_level
	l.perc_branches_visited=l.branches_visited/l.branches
	l.perc_unique_rooms_visited=l.unique_rooms_visited/l.total_rooms
	l.perc_total_time_spent_main=l.total_time_spent_main/l.total_time_spent
	l.perc_total_time_spent_optional=l.total_time_spent_optional/l.total_time_spent
	l.fights_to_puzzle_time_ratio=l.total_time_spent_fighting/l.total_time_spent_puzzling
	l.fights_to_puzzle_encounter_ratio=l.total_fights_encountered/l.total_puzzles_encountered
	l.total_time_spent_other=l.total_time_spent-(l.total_time_spent_fighting+l.total_time_spent_puzzling)

	for i=1,10 do
		local savegame_var = game:get_value("reward_"..i)
		if savegame_var == nil then break end
		if savegame_var == true then 
			l.rewards_retrieved = l.rewards_retrieved + 1 
			game:set_value("reward_"..i, nil)
		end
	end

	l.perc_rewards_retrieved=l.rewards_retrieved/l.rewards_available

	el.log_to_data()
end

function el.log_to_data()
	local data = {}
	for _,v in ipairs(el.log_order) do
		table.insert(data, el.log[v])
	end
	el.writeTableToFile (data, "exploration_log.csv") 
end

function el.writeTableToFile (dataTable, file) 
	local f = sol.file.open(file,"a+")
	for k,v in pairs(dataTable) do
		f:write(tostring(v))
		if k ~= #dataTable then f:write(",")
		else f:write("\n") end
	end
	f:flush(); f:close()
end


return el