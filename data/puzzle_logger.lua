local pl = {}

pl.log = {
	-- data gathered on all puzzles
	total_time=0,
	total_time_maze=0,
	total_time_pike_room=0,
	total_time_sokoban=0,

	sokoban_retries=0,
	sokoban_quits=0,
	sokoban_puzzles=0,
	sokoban_vfm=0,

	pike_room_hearts_lost=0,
	pike_room_deaths=0,
	pike_room_puzzles=0,

	maze_hearts_lost=0,
	maze_deaths=0,
	maze_puzzles=0,
}

pl.current_puzzle_log = {
	time_start=0,
	time_end=0,
	retries=0,
	hearts_lost=0,
	puzzle_type="_",
	deaths=0,
	quit=false,
	completed=false,
	vfm_time=0,
}

function pl.completed_puzzle()
	local cl = pl.current_puzzle_log
	local tl = pl.log
	local puzzle_type = cl.puzzle_type
	tl.total_time = tl.total_time + (cl.time_end - cl.time_start)
	tl["total_time_"..puzzle_type] = tl["total_time_"..puzzle_type] + (cl.time_end - cl.time_start)
	tl[puzzle_type.."_puzzles"] = tl[puzzle_type.."_puzzles"] +1
	if puzzle_type == "sokoban" then
		if cl.quit then	tl.sokoban_quits = tl.sokoban_quits +1 end
		tl.sokoban_retries = tl.sokoban_retries + cl.retries
		tl.sokoban_vfm = tl.sokoban_vfm + cl.vfm_time
	elseif puzzle_type == "pike_room" then
		tl.pike_room_deaths = tl.pike_room_deaths + cl.deaths
		tl.pike_room_hearts_lost = tl.pike_room_hearts_lost + cl.hearts_lost
	elseif puzzle_type == "maze" then
		

	end
end


return pl