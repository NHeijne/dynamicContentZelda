local pl = {}

pl.log = {
	-- data gathered on all puzzles
	total_time=0,
	
	sokoban_total_time=0,
	sokoban_retries=0,
	sokoban_quits=0,
	sokoban_puzzles=0,
	sokoban_vfm=0,

	pike_room_total_time=0,
	pike_room_got_hurt=0,
	pike_room_deaths=0,
	pike_room_puzzles=0,

	maze_total_time=0,
	maze_got_hurt=0,
	maze_deaths=0,
	maze_puzzles=0,
}


pl.current_areanumber = 0
pl.current_puzzle_log = {}

function pl.complete_puzzle()
	local cl = pl.current_puzzle_log[pl.current_areanumber]
	if not cl.completed then
		cl.completed = true
		pl.stop_recording()
		pl.update_total_log( cl )
		puzzle_gen.interpret_log( cl )
		pl.current_log_to_data( cl )
	end
end

function pl.update_total_log( current_puzzle_log )
	local cl = current_puzzle_log
	local tl = pl.log
	local puzzle_type = cl.puzzle_type
	tl.total_time = tl.total_time + (cl.time_end - cl.time_start)
	tl[puzzle_type.."_total_time"] = tl[puzzle_type.."_total_time"] + (cl.time_end - cl.time_start)
	tl[puzzle_type.."_puzzles"] = tl[puzzle_type.."_puzzles"] +1
	if puzzle_type == "sokoban" then
		if cl.quit then	tl.sokoban_quits = tl.sokoban_quits +1 end
		tl.sokoban_retries = tl.sokoban_retries + cl.retries
		tl.sokoban_vfm = tl.sokoban_vfm + (cl.vfm_time - cl.time_start)
	elseif puzzle_type == "pike_room" then
		tl[cl.puzzle_type.."_deaths"] = tl[cl.puzzle_type.."_deaths"] + cl.deaths
		tl.pike_room_got_hurt = tl.pike_room_got_hurt + cl.got_hurt
	elseif puzzle_type == "maze" then
		tl[cl.puzzle_type.."_deaths"] = tl[cl.puzzle_type.."_deaths"] + cl.deaths
		tl.maze_got_hurt = tl.maze_got_hurt + cl.got_hurt
	end
end

function pl.start_recording( puzzle_type, areanumber, difficulty )
	pl.current_areanumber = areanumber
	local cl = pl.current_puzzle_log[areanumber]
	if cl == nil then 
		pl.current_puzzle_log[areanumber] = 
		{
			started_recording = true,
			difficulty=difficulty,
			time_start=os.clock(),
			time_end=0,
			retries=0,
			got_hurt=0,
			puzzle_type=puzzle_type,
			quit=false,
			completed=false,
			died=false,
			deaths=0,
			vfm_time=0,
			total_vfm_time=0,
		}
		cl = pl.current_puzzle_log[areanumber]
	elseif cl.completed or cl.quit then 
		return
	else
		cl.started_recording = true
		cl.died = false
		cl.time_start=os.clock()
		cl.vfm_time = 0
	end
	
	function hero:on_state_changed(state)
		if state == "hurt" then 
			cl.got_hurt = cl.got_hurt +1
			if game:get_life() <= 2 and not cl.died then
				pl.stop_recording()
				cl.died = true
				cl.deaths = cl.deaths +1
			end
		end
		return false
	end
end

function pl.pressed_quit()
	local cl = pl.current_puzzle_log[pl.current_areanumber]
	if cl.started_recording and not cl.quit and not cl.completed then
		pl.current_puzzle_log.quit = true
		pl.stop_recording()
		pl.update_total_log( cl )
		puzzle_gen.interpret_log( cl )
		pl.current_log_to_data( cl )
		return true
	else
		return false
	end
end

function pl.retry()
	cl = pl.current_puzzle_log[pl.current_areanumber]
	if cl.vfm_time ~= 0 then  
		cl.retries = cl.retries+1
		cl.total_vfm_time = cl.total_vfm_time + cl.vfm_time
		cl.vfm_time = 0
	end
end

function pl.made_first_move()
	local cl = pl.current_puzzle_log[pl.current_areanumber]
	if cl.vfm_time == 0 and cl.started_recording then
		cl.vfm_time = os.clock() - cl.time_start
	end
end

function pl.stop_recording()
	local cl = pl.current_puzzle_log[pl.current_areanumber]
	cl.time_end = os.clock()
	cl.total_vfm_time = cl.total_vfm_time + cl.vfm_time
	cl.started_recording = false
	function hero:on_state_changed(state)
		return false
	end
end

function pl.current_log_to_data( current_puzzle_log )
	local cl = current_puzzle_log
	local data ={}
	table.insert(data, game:get_player_name()) 		-- name
	table.insert(data, cl.puzzle_type) 				-- puzzle_type
	table.insert(data, cl.difficulty) 				-- difficulty 1-5
	table.insert(data, cl.time_end - cl.time_start) -- time spent
	table.insert(data, cl.retries) 					-- retries
	table.insert(data, cl.got_hurt) 				-- got_hurt
	table.insert(data, cl.deaths) 					-- deaths
	table.insert(data, cl.quit) 					-- quit
	table.insert(data, cl.completed) 				-- completed
	table.insert(data, cl.total_vfm_time/(cl.retries+1)) -- average vfm_time
	pl.writeTableToFile (data, "individual_puzzles.csv") 
end

function pl.log_to_data( )
	local l = pl.log
	local data ={}
	table.insert(data, game:get_player_name()) 	-- name
	table.insert(data, l.total_time) 			-- total_time
	table.insert(data, l.sokoban_total_time) 	-- sokoban_total_time
	table.insert(data, l.sokoban_retries) 		-- sokoban_retries
	table.insert(data, l.sokoban_quits) 		-- sokoban_quits
	table.insert(data, l.sokoban_puzzles) 		-- sokoban_puzzles
	table.insert(data, l.sokoban_vfm) 			-- sokoban_vfm
	table.insert(data, l.pike_room_total_time) 	-- pike_room_total_time
	table.insert(data, l.pike_room_got_hurt) -- pike_room_got_hurt
	table.insert(data, l.pike_room_deaths) 		-- pike_room_deaths
	table.insert(data, l.pike_room_puzzles) 	-- pike_room_puzzles
	table.insert(data, l.maze_total_time) 		-- maze_total_time
	table.insert(data, l.maze_got_hurt) 		-- maze_got_hurt
	table.insert(data, l.maze_deaths) 			-- maze_deaths
	table.insert(data, l.maze_puzzles) 			-- maze_puzzles
	pl.writeTableToFile (data, "all_puzzles.csv") 
end

function pl.writeTableToFile (dataTable, file) 
	local f = sol.file.open(file,"a+")
	for k,v in pairs(dataTable) do
		f:write(tostring(v))
		if k ~= #dataTable then f:write(",")
		else f:write("\n") end
	end
	f:flush(); f:close()
end

return pl