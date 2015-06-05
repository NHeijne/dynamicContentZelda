local table_util = require("table_util")
local log = require("log")

local sp = {}


--arranged by ID as to avoid using duplicates in the same game
sp.sokoban_problems = false

sp.sokoban_difficulty = false

sp.sokoban_files={
	"minicosmos_diff_1_.txt", -- Author: Aymeric du Peloux, aymeric.dupeloux@smile.fr, http://sneezingtiger.com/sokoban/levels/microcosmosText.html
}

sp.prop_types = {
	["exit_block"]={name="exit_block", layer=0, x=8, y=13, sprite="entities/block", pushable=false, pullable=false, maximum_moves=0},
	["wall_block"]={name="unmovable_block", layer=0, x=8, y=13, sprite="entities/block", pushable=false, pullable=false, maximum_moves=0},
	["move_block"]={name="movable_block_1", layer=0, x=8, y=13, sprite="entities/gray_block", pushable=true, pullable=false, maximum_moves=2},
	["block_switch"]={name="block_switch_1", layer=0, x=0, y=0, subtype="walkable", sprite="entities/gray_switch", sound="switch", needs_block=true, inactivate_when_leaving=true},
	["reset_switch"]={name="reset_switch", layer=0, x=0, y=0, subtype="walkable", sprite="entities/switch", sound="switch", needs_block=false, inactivate_when_leaving=true},
	["reset_wall"]={name="reset_wall", layer=0, x=0, y=0, width=16, height=16, stops_blocks=true}

}

sp.puzzles_created = {}

function sp.parse_files ()
	log.debug("parse_files")
	sp.sokoban_problems = {}
	sp.sokoban_difficulty = {}
	for _,filename in ipairs(sp.sokoban_files) do
		local file = sol.file.open("internetsources/sokoban/"..filename)
		local difficulty_rating = tonumber(table_util.split(filename, "_")[3])
		while true do
			local level = file:read()
			if level == nil or string.len(level) == 0 then break end
			local lvl_nr = table_util.split(level, "_")[2]
			local name = file:read()
			local puzzle = {}
			local line
			local max_length = 0
			while true do
				line = file:read()
				if not line then break end
				local length = string.len(line)
				if length > max_length then max_length = length end
				if length > 0 then 
					table.insert(puzzle, line)
				else break end
			end
			sp.sokoban_problems[lvl_nr]= {puzzle=puzzle, difficulty=difficulty_rating, dim={x=max_length, y=#puzzle}}
			sp.sokoban_difficulty[difficulty_rating] = sp.sokoban_difficulty[difficulty_rating] or {}
			table.insert(sp.sokoban_difficulty[difficulty_rating], lvl_nr)
		end
	end
end

function sp.get_corrected_puzzle_table( problem, to_direction )
	log.debug("get_corrected_puzzle_table")
	local puzzle_table = sp.get_table_from_string_representation( problem )
	local from_direction = sp.get_direction_of_entrance( puzzle_table, problem.dim )
	local rotate_puzzle_table = sp.rotate_puzzle_to_direction( from_direction, to_direction, puzzle_table )
	log.debug("rotate_puzzle_table")
	return rotate_puzzle_table
end

function sp.get_random_sized_sokoban_puzzle( difficulty )
	if not sp.sokoban_problems then sp.parse_files() end
	return sp.select_puzzle( nil , difficulty ) 
end

function sp.get_sokoban_puzzle( area, difficulty )
	if not sp.sokoban_problems then sp.parse_files() end
	local max_x, max_y = math.floor((area.x2-area.x1)/16), math.floor((area.y2-area.y1)/16)
	local max_dimensions = {x=max_x, y=max_y}
	return sp.select_puzzle( max_dimensions , difficulty )
end

function sp.select_puzzle( max_dimensions, difficulty )
	if not sp.sokoban_problems then sp.parse_files() end
	local puzzles = sp.sokoban_difficulty[difficulty]
	while true do
		local picked_puzzle = table.remove(puzzles, 1)--math.random(#puzzles))
		local problem = sp.sokoban_problems[picked_puzzle]
		if ( max_dimensions == nil or (problem.dim.x <= max_dimensions.x and problem.dim.y < max_dimensions.y) ) then

			return problem
		end
	end
end

function sp.get_table_from_string_representation( problem )
	log.debug("get_table_from_string_representation")
	local string_rep = table_util.copy(problem.puzzle)
	for i=#string_rep,1, -1 do
		if #string_rep[i]==0 then table.remove(string_rep, i)
		else
			string_rep[i] = sp.string_to_table ( string_rep[i] )
			for j=#string_rep[i]+1, problem.dim.x, 1 do
				string_rep[i][j]="_"
			end
		end
	end
	return string_rep
end

function sp.string_to_table ( str )
	local t = {}
	str:gsub(".",function(c) table.insert(t,c) end)
	return t
end

-- 0:east - 3:south
function sp.get_direction_of_entrance( puzzle_table, max_dimensions )
	-- check left and right side
	for i=1, #puzzle_table do
		if puzzle_table[i][1] == "@" then return 2 end
		if puzzle_table[i][max_dimensions.x] == "@" then return 0 end
	end
	-- check top and bottom side
	for i=1, #puzzle_table[1] do
		if puzzle_table[1][i] == "@" then return 1 end
		if puzzle_table[max_dimensions.y][i] == "@" then return 3 end
	end
end

function sp.get_sorted_list_of_objects( puzzle_table, max_dimensions, area ) -- objects are all 16 x 16
	log.debug("get_sorted_list_of_objects")
	local conversion_table = { ["@"]={"entrance"}, ["#"]={"wall"}, ["*"]={"block", "goal"}, ["$"]={"block"}, ["."]={"goal"}, ["_"]={"floor"}, ["E"]={"exit"} }
	local output_table = { ["wall"]={}, ["floor"]={}, ["block"]={}, ["goal"]={}, ["entrance"]={}, ["exit"]={} }
	for i,row in ipairs(puzzle_table) do
		for j,node in ipairs(row) do
			for _,output_type in ipairs(conversion_table[node]) do
				table.insert(output_table[output_type], {x1=area.x1+(j-1)*16, x2=area.x1+j*16, y1=area.y1+(i-1)*16, y2=area.y1+i*16})
			end
		end
	end
	return output_table
end

function sp.place_sokoban_puzzle( map, area_list )
	log.debug("place_sokoban_puzzle")
	-- place normal blocks as walls, cannot be pushed
	for _, area in ipairs(area_list.wall) do
		local wall_block = table_util.copy(sp.prop_types.wall_block)
		wall_block.x, wall_block.y = wall_block.x+area.x1, wall_block.y+area.y1
		map:create_block(wall_block)
	end
	local block_stopper = table_util.copy(sp.prop_types.reset_wall)
	block_stopper.x, block_stopper.y = block_stopper.x+area_list.entrance[1].x1, block_stopper.y+area_list.entrance[1].y1
	map:create_wall(block_stopper)
	-- place switch at entrance for resetting 
	local next_index = sp.get_next_available_index( )
	local reset_switch = table_util.copy(sp.prop_types.reset_switch)
	reset_switch.name = "reset_switch_"..next_index
	reset_switch.x, reset_switch.y = reset_switch.x+area_list.entrance[1].x1, reset_switch.y+area_list.entrance[1].y1
	reset_switch = map:create_switch(reset_switch)
	sp.puzzles_created[next_index] = area_list
	reset_switch.on_activated = 
		function() 
			local index = next_index
			local map = map
			for sokoban_object in map:get_entities("sokoban_"..index) do
				sokoban_object:remove()
			end
			local area_list = sp.puzzles_created[index]
			-- place switches,
			for i, area in ipairs(area_list.goal) do
				local block_switch = table_util.copy(sp.prop_types.block_switch)
				block_switch.name = "sokoban_"..index.."_"..block_switch.name.."_"..i
				block_switch.x, block_switch.y = block_switch.x+area.x1, block_switch.y+area.y1
				local switch = map:create_switch(block_switch)
				switch.on_activated = 
					function ( )
						sp.check_switches(index, map, nr_of_switches)
					end
			end
			-- place gray blocks as movable blocks, infinite moves, can only be pushed
			for _, area in ipairs(area_list.block) do
				local move_block = table_util.copy(sp.prop_types.move_block)
				move_block.name = "sokoban_"..index.."_"..move_block.name
				move_block.x, move_block.y = move_block.x+area.x1, move_block.y+area.y1
				map:create_block(move_block)
			end
			-- place wall for the blocks at the entrance
			for _, area in ipairs(area_list.exit) do
				local exit_block = table_util.copy(sp.prop_types.exit_block)
				exit_block.name = "sokoban_"..index.."_"..exit_block.name
				exit_block.x, exit_block.y = exit_block.x+area.x1, exit_block.y+area.y1
				map:create_block(exit_block)
			end
			-- logging retries and start time
		end
end

-- sokoban_1_wall_block_1
function sp.get_next_available_index( )
	return #sp.puzzles_created+1
end

function sp.check_switches( index, map, nr_of_switches )
	for switch in map:get_entities("sokoban_"..index.."_block_switch") do
		if not switch:is_activated() then return end
	end
	-- log completion of sokoban puzzle 
	for sokoban_object in map:get_entities("sokoban_"..index) do
		sokoban_object:remove()
	end
	local reset_switch = map:get_entity("reset_switch_"..index)
	reset_switch:remove()
end


function sp.rotate_puzzle_to_direction( from_direction, to_direction, puzzle_table )
	log.debug("rotate_puzzle_to_direction")
	-- example from 0 to 3 | (7-0)%4 = 3 or from 3 to 0 then (4-3)%4 = 1
	local rotated_table = puzzle_table
	local rotations = (to_direction+4-from_direction)%4
	for i=1, rotations do
	 	rotated_table = sp.rotate_table_ccw( rotated_table )
	end 
	return rotated_table
end

function sp.rotate_table_ccw( tbl )
	local max_y, max_x = #tbl, #tbl[1]
	local rotated_table = {}
	for x=1, max_x do
		for y=1, max_y do
			rotated_table[max_x-(x-1)] = rotated_table[max_x-(x-1)] or {}
			rotated_table[max_x-(x-1)][y]=tbl[y][x]
		end
	end
	return rotated_table
end

return sp