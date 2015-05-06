local maze_gen = {}

local log = require("log")
local table_util = require("table_util")
local area_util = require("area_util")
local num_util = require("num_util")

-- NOTE TODO this can later be used to find a good path in areas or transitions
-- reason not to use this for pathfinding of transitions: too many possible ways
-- it will fail or take longer than breadth first search of boundary areas

-- area {x1, y1, x2, y2}
-- object width in pixels (walls) --predetermined, in dungeons it can be 8x8 or 24x16 and comprised of multiple parts
	--TODO function that places from top to bottom the areas and corrects the patterns if needed
-- prefered corridor width (easily done if uniform across maze)
-- TODO off limit areas exclude={[1]={area={x1, y1, x2, y2},sides_open={"wind_direction"} } 
-- exit nodes given as areas

local map
local room

-- direction (number): between 0 (East of the room) and 3 (South of the room).

function maze_gen.set_map( given_map )
	map = given_map
end

function maze_gen.set_room( area, corridor_width, wall_width, name_prefix )
	room = table_util.copy(area)
	if type(corridor_width) == "table" then room.corridor_width = corridor_width
	else room.corridor_width = {x=corridor_width, y=corridor_width} end
	if type(wall_width) == "table" then room.wall_width = wall_width
	else room.wall_width = {x=wall_width, y=wall_width} end
	room.name_prefix = name_prefix or "space"
end

function maze_gen.generate_maze( area, exit_areas, exclusion)
	local corridor_width = room.corridor_width
	local maze = {}
	local wall_width = room.wall_width

	maze_gen.initialize_maze( maze, area, wall_width, corridor_width )

	if exclusion ~= nil and next(exclusion) ~= nil then maze_gen.exclude( maze, exclusion ) end

	maze_gen.place_walls_around( maze, maze_gen.get_not_visited( maze ) )
	
	local exits = maze_gen.open_exits( maze, exit_areas, area, wall_width, corridor_width )

	maze_gen.create_maze_puzzle( maze, exits, area )

	local area_list, prop_list = maze_gen.create_area_list( maze, area, corridor_width, wall_width )
	-- log.debug(area_list)
 	return area_list, prop_list
end

function maze_gen.generate_rooms( area_details )
	local width, height = map:get_size(); local corridor_width = room.corridor_width; local wall_width = room.wall_width
	local maze = {}
	maze_gen.initialize_maze( maze, room, wall_width, corridor_width )
	maze_gen.place_walls_around( maze, maze_gen.get_not_visited( maze ) )
	local start_pos = {x=1, y=math.floor(#maze[1]/2)}-- entrance is always west center
	maze[start_pos.x][start_pos.y].visited = true
	if not area_details.outside then
		maze[start_pos.x][start_pos.y+1].visited = true
	end	if area_details.outside then 
		maze[start_pos.x][start_pos.y][2] = "other_map" -- exit to the left because the witch hut exit is to the right
	else
		maze[start_pos.x][start_pos.y][3] = "other_map" -- exit to the bottom because of the tile for the exit
	end
	maze_gen.recursive_rooms( maze, area_details, "start", start_pos )
	return maze_gen.create_room_list( maze, corridor_width, {x=wall_width.x/2, y=wall_width.y/2} )
end

-- direction (number): between 0 (East of the room) and 3 (South of the room).
-- area size = 1, 2, or 4
function maze_gen.recursive_rooms( maze, area_details, areanumber, pos )
	-- if the area contains multiple tasks then we assign multiple nodes in random directions
	local area_size = area_details.area_size
	maze[pos.x][pos.y].areanumber = areanumber
	-- expand the area if P or F
	local room_positions={pos}
	if table_util.contains({"F", "P"}, area_details[areanumber].area_type) and area_size > 1 or area_details[areanumber].area_type == "BOSS" then
		if area_size >= 2 or area_details[areanumber].area_type == "BOSS" then
			local neighbors = maze_gen.get_neighbors(maze, pos, true)
			local second_neighbor = maze_gen.get_most_isolated_neighbor( maze, neighbors )
			room_positions[2] = second_neighbor.pos
			second_neighbor.node.areanumber = areanumber

			maze_gen.open_path(maze, {pos, second_neighbor.pos}, "opening")
			local first_node_neighbors = maze_gen.get_neighbors(maze, pos, true)
			local second_node_neighbors = maze_gen.get_neighbors(maze, second_neighbor.pos, true)

			if area_size == 4 or area_details[areanumber].area_type == "BOSS" then

				local second_degree_neighbors_of_first_node = {}
				for _, nb in ipairs(first_node_neighbors) do
					table_util.add_table_to_table( maze_gen.get_neighbors(maze, nb.pos, true), second_degree_neighbors_of_first_node )
				end

				-- now match the second_node_neighbors with the second_degree_neighbors_of_first_node
				local found_match = false
				for _, nb1 in ipairs(second_node_neighbors) do -- use the node pos on this
					for _, nb2 in ipairs(second_degree_neighbors_of_first_node) do -- use the from pos with this one
						if nb1.pos.x == nb2.pos.x and nb1.pos.y == nb2.pos.y then
							found_match = true
							local third_node = nb1
							local fourth_node = maze[nb2.from_pos.x][nb2.from_pos.y]
							room_positions[3] = nb1.pos
							room_positions[4] = nb2.from_pos
							third_node.node.areanumber = areanumber
							fourth_node.areanumber = areanumber

							maze_gen.open_path(maze, {pos, nb2.from_pos, nb1.pos, second_neighbor.pos}, "opening")
							break
						end
					end
					if found_match then break end
				end
			end
		end
	end
	-- find new nodes for the next rooms
	if areanumber ~= "goal" then
		for _,connection in ipairs(area_details[areanumber]) do
			local neighbors = maze_gen.get_neighbors_from_pos_list( maze, room_positions, true )
			-- create the room with a given size
			local selected_nb = maze_gen.get_most_isolated_neighbor( maze, neighbors )
			maze_gen.open_path(maze, {selected_nb.from_pos, selected_nb.pos}, "exit")
			maze_gen.recursive_rooms( maze, area_details, connection.areanumber, selected_nb.pos )
		end
	elseif area_details.outside then
		for _,i in ipairs({0, 1, 2, 3}) do
			if maze[pos.x][pos.y][i] == true then -- exit to the right to the mine entrance
				maze[pos.x][pos.y][i]="other_map" 
				break
			end
		end
	else
		for _,i in ipairs({3, 1}) do -- exit to the bottom because of the tile for the exit
			if maze[pos.x][pos.y][i] == true then
				maze[pos.x][pos.y][i]="other_map" -- exit to the right to the mine entrance
				break
			end
		end
	end
end

function maze_gen.get_neighbors_from_pos_list( maze, pos_list, get_not_visited )
	local neighbors = {}
	for _, pos in ipairs(pos_list) do
		table_util.add_table_to_table( maze_gen.get_neighbors(maze, pos, get_not_visited), neighbors )
	end
	return neighbors
end

function maze_gen.get_most_isolated_neighbor( maze, neighbors )
	local ranking = {}
	local highest_rank = 0
	for _,nb in ipairs(neighbors) do
		local first_degree_neighbors = maze_gen.get_neighbors(maze, nb.pos, true)
		local second_degree_neighbors = {}
		for _, nb2 in ipairs(first_degree_neighbors) do
			table_util.add_table_to_table( maze_gen.get_neighbors(maze, nb2.pos, true), second_degree_neighbors )
		end
		local nr_of_second_degree_nb = #second_degree_neighbors
		if nr_of_second_degree_nb > highest_rank then highest_rank = nr_of_second_degree_nb end
		ranking[nr_of_second_degree_nb] = ranking[nr_of_second_degree_nb] or {}
		table.insert(ranking[nr_of_second_degree_nb], nb)
	end
	local selected_nb
	log.debug("ranking:")
	log.debug(ranking)
	for i=highest_rank, 0, -1 do
		if ranking[i] and #ranking[i] > 0 then 
			selected_nb = ranking[i][1]; break
		end
	end
	return selected_nb
end


function maze_gen.create_room_list ( maze, corridor_width, wall_width )
	result = {["walkable"]={}, ["opening"]={}, ["exit"]={}, ["nodes"]={}, ["other_map"]={}}
	local w = result["walkable"]; local o = result["opening"]; local e = result["exit"]; local n = result["nodes"]; local m = result["other_map"]
	for x=1, #maze do
		for y=1, #maze[1] do
			-- add corridor to walkable, walls which are false to opening and exits to exit
			if maze[x][y].areanumber ~= nil then
				local a_nr = maze[x][y].areanumber
				w[a_nr] = w[a_nr] or {}; o[a_nr] = o[a_nr] or {}; e[a_nr] = e[a_nr] or {}; n[a_nr] = n[a_nr] or {}; m[a_nr]= m[a_nr] or {}
				local walkable = maze_gen.pos_to_area({x=x, y=y})
				local node = area_util.resize_area(walkable, {-wall_width.x, -wall_width.y, wall_width.x, wall_width.y})
				local p = maze_gen.maze_wall_to_areas( maze, {x=x, y=y}, corridor_width, wall_width, node)
				table.insert(w[a_nr], walkable); table.insert(n[a_nr], node);table.insert(e[a_nr], p.exit); table.insert(o[a_nr], p.opening); table.insert(m[a_nr], p.other_map)
			end
		end
	end
	for _, a in pairs(result["walkable"]) do
		a.area = nil
		for _, area in ipairs(a) do
			if a.area == nil then a.area = table_util.copy(area)
			else a.area = area_util.merge_areas(a.area, area) end
		end
	end
	for _, a in pairs(result["nodes"]) do
		a.area = nil
		for _, area in ipairs(a) do
			if a.area == nil then a.area = table_util.copy(area)
			else a.area = area_util.merge_areas(a.area, area) end
		end
	end
	return result
end

function maze_gen.maze_wall_to_areas( maze, pos, corridor_width, wall_width, node)
	local exits = {} -- 32 wide
	local openings = {} -- 64 wide?
	local walls = {[1]={x1=node.x1+wall_width.x, x2=node.x2-wall_width.x, y1=node.y1, y2=node.y1+wall_width.y},
				   [0]={x1=node.x2-wall_width.x, x2=node.x2, y1=node.y1+wall_width.y, y2=node.y2-wall_width.y},
				   [2]={x1=node.x1, x2=node.x1+wall_width.x, y1=node.y1+wall_width.y, y2=node.y2-wall_width.y},
				   [3]={x1=node.x1+wall_width.x, x2=node.x2-wall_width.x, y1=node.y2-wall_width.y, y2=node.y2}}
	local result = {["exit"]={}, ["opening"]={}, ["other_map"]={}}
	if type(maze[pos.x][pos.y][0]) == "string" then
		result[maze[pos.x][pos.y][0]][0] = area_util.from_center( walls[0], wall_width.x, 32) 
		result[maze[pos.x][pos.y][0]][0].to_area = table_util.get(maze, {pos.x+1, pos.y, "areanumber"}) end
	if type(maze[pos.x][pos.y][1]) == "string" then
		result[maze[pos.x][pos.y][1]][1] = area_util.from_center( walls[1], 32, wall_width.y) 
		result[maze[pos.x][pos.y][1]][1].to_area = table_util.get(maze, {pos.x, pos.y-1, "areanumber"}) end
	if type(maze[pos.x][pos.y][2]) == "string"  then	
		result[maze[pos.x][pos.y][2]][2] = area_util.from_center( walls[2], wall_width.x, 32) 
		result[maze[pos.x][pos.y][2]][2].to_area = table_util.get(maze, {pos.x-1, pos.y, "areanumber"}) end
	if type(maze[pos.x][pos.y][3]) == "string"  then
		result[maze[pos.x][pos.y][3]][3] = area_util.from_center( walls[3], 32, wall_width.y) 
		result[maze[pos.x][pos.y][3]][3].to_area = table_util.get(maze, {pos.x, pos.y+1, "areanumber"}) end
	return result
end


function maze_gen.generate_path( exit_areas, straight_path )
	-- for inside the areas
	local wall_width, corridor_width = room.wall_width, room.corridor_width
	local maze = {}
	maze_gen.initialize_maze( maze, room, wall_width, corridor_width )
	local exits = maze_gen.open_exits( maze, exit_areas, room, wall_width, corridor_width )
	-- check along the path what the max distance is to the exits
	local paths = maze_gen.create_initial_paths( maze, exits )
	if not straight_path then
		-- get not visited, pick a spot, create a branch
		local available_points = {}
		local stepsize_x, stepsize_y = math.ceil(#maze/math.floor(#maze/6)), math.ceil(#maze[1]/math.floor(#maze[1]/6))
		local max_x, max_y =  #maze-1, #maze[1]-1
		for i=2, #maze-1, stepsize_x do
			for j=2, #maze[1]-1, stepsize_y do
				local x, y = math.random(i, num_util.clamp(i+stepsize_x, 2, max_x)), math.random(j, num_util.clamp(j+stepsize_y, 2, max_y))
				table.insert(available_points, {x=x, y=y})
			end
		end
		repeat
			local next_point = table.remove(available_points, math.random(#available_points))
			local path1 = maze_gen.create_direct_path( maze_gen.find_closest_node( maze, next_point, paths ), next_point, maze )
			if path1 then 
				table.insert(paths, path1) 
			end
		until #available_points == 0
	end
	-- got a path to all exits
	for _,path in ipairs(paths) do
		for _, node in ipairs(path) do
			local neighbors = maze_gen.get_neighbors(maze, node)
			for _, n in ipairs(neighbors) do
				maze[n.pos.x][n.pos.y].visited = true
			end
		end
	end
	for _,exit_list in ipairs(exits) do
		neighbors = maze_gen.get_neighbors(maze, exit_list[math.ceil(#exit_list/2)])
		for _, n in ipairs(neighbors) do
			neighbors = maze_gen.get_neighbors(maze, n.pos)
			for _, n2 in ipairs(neighbors) do
				maze[n2.pos.x][n2.pos.y].visited = "exit"
			end
			maze[n.pos.x][n.pos.y].visited = "exit"
		end
	end
	-- we have an expanded path, now to make areas from those nodes
	local closed_areas = maze_gen.visited_to_area_list( maze, false )
	local open_areas = maze_gen.visited_to_area_list( maze, true )
	return open_areas, closed_areas
end

function maze_gen.close_path( maze, path )
	for i = 1, #path-1, 1 do
		local from, to
		if path[i+1].x > path[i].x then from, to = 2, 0
		elseif path[i+1].x < path[i].x then from, to = 0, 2
		elseif path[i+1].y > path[i].y then from, to = 1, 3
		elseif path[i+1].y < path[i].y then from, to = 3, 1 end
		maze[path[i].x][path[i].y][to]= true
 		maze[path[i+1].x][path[i+1].y][from]= true
        maze[path[i+1].x][path[i+1].y].visited = false
	end
end

function maze_gen.visited_to_area_list( maze, visit_status )
	local area_list = {}
	local max_x, max_y = #maze, #maze[1]
	for x = 1, max_x do
		for y = 1, max_y do
			local tl_node = maze[x][y]
			local tl_pos = {x=x, y=y}
			if tl_node.visited == visit_status and not tl_node.assigned then
				tl_node.assigned=true
				-- remember topleft (x, y) and the bottomright node 
				local br_pos = {x=x, y=y}
				while true do
					if br_pos.x+1 > max_x or br_pos.y+1 > max_y then table.insert(area_list, maze_gen.nodes_to_area( tl_pos, br_pos ) );break end
					-- check if the block is expandable to the right and bottom of the current block
					local right, bottom = true, true
					for x2 = x, br_pos.x+1 do
						if maze[x2][br_pos.y+1].visited ~= visit_status or maze[x2][br_pos.y+1].assigned then bottom=false end
					end
					if bottom then 
						for y2 = y, br_pos.y+1 do
							if maze[br_pos.x+1][y2].visited ~= visit_status or maze[br_pos.x+1][y2].assigned then right=false end
						end
						if right then
							br_pos = {x=br_pos.x+1, y=br_pos.y+1}
							for x2 = x, br_pos.x do
								maze[x2][br_pos.y].assigned = true
							end
							for y2 = y, br_pos.y do
								maze[br_pos.x][y2].assigned = true
							end
						else
							table.insert(area_list, maze_gen.nodes_to_area( tl_pos, br_pos ) );	break
						end
					else
						table.insert(area_list, maze_gen.nodes_to_area( tl_pos, br_pos ) );	break
					end
				end
			end
		end
	end
	return area_list
end

function maze_gen.nodes_to_area( topleft_pos, bottomright_pos )
	local cw = room.corridor_width
	local ww = room.wall_width
	return {x1=(topleft_pos.x-1)*(cw.x+ww.x)+room.x1,
			x2=bottomright_pos.x*(cw.x+ww.x)+ww.x+room.x1,
			y1=(topleft_pos.y-1)*(cw.y+ww.y)+room.y1,
			y2=bottomright_pos.y*(cw.y+ww.y)+ww.y+room.y1}
end

function maze_gen.exclude( maze, exclusion )
	for _, exclusion_area in ipairs(exclusion) do
		local pos_list = maze_gen.area_to_pos ( exclusion_area )
		local max_x, max_y= #maze, #maze[1]
		for _, pos in ipairs(pos_list) do
			if not (pos.x < 1 or pos.x > max_x or pos.y < 1 or pos.y > max_y) then
				maze[pos.x][pos.y].visited = "excluded"
			end
		end
	end
end

function maze_gen.area_to_pos ( area )
	local pos_list = {}
	local cw = room.corridor_width
	local ww = room.wall_width
	local x1 = math.floor((area.x1-room.x1)/(cw.x+ww.x))
	local x2 = math.ceil((area.x2-room.x1-ww.x)/(cw.x+ww.x))
	local y1 = math.floor((area.y1-room.y1)/(cw.y+ww.y))
	local y2 = math.ceil((area.y2-room.y1-ww.y)/(cw.y+ww.y))
	for x=x1, x2 do
		for y=y1, y2 do
			table.insert(pos_list, {x=x, y=y})
		end
	end
	return pos_list
end 

function maze_gen.create_area_list( maze, area, corridor_width, wall_width )
	-- standard 8x8 patterns
	local max_x=#maze
	local max_y=#maze[1]
	local area_list = {}
	-- if at least one wall is connected to the post then create it
	if maze[1][1][1] or maze[1][1][4] then
		table.insert(area_list, {area={x1=area.x1, y1=area.y1, x2=area.x1+wall_width.x, y2=area.y1+wall_width.y}, pattern="maze_post"})
	end
	-- direction (number): between 0 (East of the room) and 3 (South of the room).
	for x=1, max_x do
		for y=1, max_y do
			if x==1 then -- create left side, skipping topleft
				if maze[x][y][2] then area_list[#area_list+1] = {area={x1=area.x1, y1=area.y1+wall_width.y+(wall_width.y+corridor_width.y)*(y-1),
												 x2=area.x1+wall_width.x, y2=area.y1+(wall_width.y+corridor_width.y)*y}, pattern="maze_wall_ver"} end
			 	if maze[x][y][2] or maze[x][y][3] or ( y<max_y and maze[x][y+1][2]) then
					area_list[#area_list+1] = {area={x1=area.x1, y1=area.y1+(wall_width.y+corridor_width.y)*y, 
												  	 x2=area.x1+wall_width.x, y2=area.y1+(wall_width.y+corridor_width.y)*y+wall_width.y}, 
											   pattern="maze_post"} end
			end
			if y==1 then -- create top side, skipping topleft
				if maze[x][y][1] then area_list[#area_list+1] = {area={x1=area.x1+wall_width.x+(wall_width.x+corridor_width.x)*(x-1), y1=area.y1,
												 x2=area.x1+(wall_width.x+corridor_width.x)*x, y2=area.y1+wall_width.y}, pattern="maze_wall_hor"} end
				-- if at least one wall is connected to the post then create it
				if maze[x][y][1] or maze[x][y][0] or ( x<max_x and maze[x+1][y][1]) then
					area_list[#area_list+1] = {area={x1=area.x1+(wall_width.x+corridor_width.x)*x, y1=area.y1, 
												  	 x2=area.x1+(wall_width.x+corridor_width.x)*x+wall_width.x, y2=area.y1+wall_width.y}, 
											   pattern="maze_post"} end
			end
			-- bottom side
			if maze[x][y][3] then area_list[#area_list+1] = {area={x1=area.x1+wall_width.x+(wall_width.x+corridor_width.x)*(x-1),
															 	   y1=area.y1+(wall_width.y+corridor_width.y)*y,
															 	   x2=area.x1+(wall_width.x+corridor_width.x)*x,
															 	   y2=area.y1+wall_width.y+(wall_width.y+corridor_width.y)*y,
															 	   }, pattern="maze_wall_hor"} end
			-- right side
			if maze[x][y][0] then area_list[#area_list+1] = {area={x1=area.x1+(wall_width.x+corridor_width.x)*x,
															 	   y1=area.y1+wall_width.y+(wall_width.y+corridor_width.y)*(y-1),
															 	   x2=area.x1+wall_width.x+(wall_width.x+corridor_width.x)*x,
															 	   y2=area.y1+(wall_width.y+corridor_width.y)*y,
															 	   }, pattern="maze_wall_ver"} end
			-- maze post
			-- if at least one wall is connected to the post then create it
			if maze[x][y][0] or maze[x][y][3] or ( x<max_x and maze[x+1][y][3]) or (y<max_y and maze[x][y+1][0]) then
				area_list[#area_list+1] = {area={x1=area.x1+(wall_width.x+corridor_width.x)*x,
										 	   y1=area.y1+(wall_width.y+corridor_width.y)*y,
										 	   x2=area.x1+wall_width.x+(wall_width.x+corridor_width.x)*x,
										 	   y2=area.y1+wall_width.y+(wall_width.y+corridor_width.y)*y,
										 	   }, pattern="maze_post"} end
		end
	end
	return area_list, prop_list
end

function maze_gen.initialize_maze( maze, area, wall_width, corridor_width )
	local width = area.x2-area.x1
	local height = area.y2-area.y1
	local x_amount = math.floor((width-wall_width.x)/(wall_width.x+corridor_width.x))
	local y_amount = math.floor((height-wall_width.y)/(wall_width.y+corridor_width.y))
	for x=1,x_amount do
		maze[x]={}
		for y=1, y_amount do
			maze[x][y] = {[1]=false, [2]=false, [3]=false, [0]=false, visited = false} 
		end
	end
end

function maze_gen.place_walls_around( maze, pos_list )
	local max_x, max_y= #maze, #maze[1]
	for _, pos in ipairs(pos_list) do
		local node = maze[pos.x][pos.y]
		local neighbors = maze_gen.get_neighbors( maze, pos)
		if 		pos.x == 1 then 	node[2] = true 
		elseif 	pos.x == max_x then node[0] = true end
		if 		pos.y == 1 then 	node[1] = true 
		elseif 	pos.y == max_y then node[3] = true end
		for _, n in ipairs(neighbors) do
			node[n.wall_to] = true
			n.node[n.wall_from]=true
		end
	end
end

function maze_gen.open_unvisited( maze )
	local unvisited = maze_gen.get_not_visited( maze )
	for _, u in ipairs(unvisited) do
		local neighbors = maze_gen.get_neighbors(maze, u, true)
		for _, n in ipairs(neighbors) do
			maze_gen.open_path(maze, {n.from_pos, n.pos})
		end
	end
end

function maze_gen.open_exits( maze, exit_areas, area, wall_width, corridor_width )
	local width = area.x2-area.x1
	local height = area.y2-area.y1
	local exits = {}
	for _, v in ipairs(exit_areas) do
		-- identify in which node the exit area is located
		local x1 = (v.x1-area.x1)/(wall_width.x+corridor_width.x)
		local y1 = (v.y1-area.y1)/(wall_width.y+corridor_width.y)
		local x2 = (v.x2-area.x1-wall_width.x)/(wall_width.x+corridor_width.x)
		local y2 = (v.y2-area.y1-wall_width.y)/(wall_width.y+corridor_width.y)

		local selected_x_min = num_util.clamp(math.ceil(x1), 1, #maze)
		local selected_x_max = num_util.clamp(math.ceil(x2), 1, #maze)
		local selected_y_min = num_util.clamp(math.ceil(y1), 1, #maze[1])
		local selected_y_max = num_util.clamp(math.ceil(y2), 1, #maze[1])
		
		local direction 
		-- direction (number): between 0 (East of the room) and 3 (South of the room).
		if v.y2 <= area.y1 and v.x1 < area.x2 and v.x2 > area.x1 then direction = 1 end
		if v.y1 >= area.y2 and v.x1 < area.x2 and v.x2 > area.x1 then direction = 3 end
		if v.x2 <= area.x1 and v.y1 < area.y2 and v.y2 > area.y1 then direction = 2 end
		if v.x1 >= area.x2 and v.y1 < area.y2 and v.y2 > area.y1 then direction = 0 end
		-- create an entrance/exit area spanning from the min to the max of the exit
		local exit_nodes = {}
		for x=selected_x_min, selected_x_max do
			for y=selected_y_min, selected_y_max do
				maze[x][y][direction] = false
				maze[x][y].visited = true
				table.insert(exit_nodes, {x=x, y=y})
			end
		end
		maze_gen.open_path(maze, exit_nodes)
		table.insert(exits, exit_nodes)
	end
	return exits
end

-- direction (number): between 0 (East of the room) and 3 (South of the room).
function maze_gen.get_neighbors(maze, position, only_get_unvisited)
	local neighbors={}
	if position.x < #maze then neighbors[#neighbors+1]={pos={x=position.x+1, y=position.y}, node=maze[position.x+1][position.y], wall_to=0, wall_from=2, from_pos=position} end
	if position.x > 1 then neighbors[#neighbors+1]={pos={x=position.x-1, y=position.y}, node=maze[position.x-1][position.y], wall_to=2, wall_from=0, from_pos=position} end
	if position.y < #maze[1] then neighbors[#neighbors+1]={pos={x=position.x, y=position.y+1},node=maze[position.x][position.y+1], wall_to=3, wall_from=1, from_pos=position} end
	if position.y > 1 then neighbors[#neighbors+1]={pos={x=position.x, y=position.y-1},node=maze[position.x][position.y-1], wall_to=1, wall_from=3, from_pos=position} end
	if only_get_unvisited then
		for i=#neighbors,1,-1 do
			if neighbors[i].node.visited then table.remove(neighbors, i) end
		end
	end
	return neighbors
end

-- http://wiki.roblox.com/index.php?title=Recursive_Backtracker
function maze_gen.standard_recursive_maze( maze )
	-- Create a table of cells, starting with just one random one
	local Cells = {[1]={x=math.random(#maze), y=math.random(#maze[1])}}
	maze[Cells[1].x][Cells[1].y].visited = true
	repeat
	     -- Select the most recent cell from the cells list (see note at bottom)
	     local CurCellIndex = #Cells
	     local CurCell = Cells[CurCellIndex]
	     local neighbors = maze_gen.get_neighbors(maze, CurCell)
	     -- Make sure that this cell has unvisited neighbors
	     local unvisited = {}
	     -- Collect all unvisited neighbors...
	     for _, v in ipairs(neighbors) do
	     	if not v.node.visited then unvisited[#unvisited+1] = v end
	     end
	     if #unvisited > 0 then
	          -- ...and select a random one.
	          local next_node = unvisited[math.random(#unvisited)]
	          -- Then carve a path to it by deleting the wall between them
	          maze[CurCell.x][CurCell.y][next_node.wall_to]=false
	          maze[next_node.pos.x][next_node.pos.y][next_node.wall_from]=false
	          maze[next_node.pos.x][next_node.pos.y].visited = true
	          -- Add the neighbor to the end of the list of cells to make sure it is picked as the current one
	          table.insert(Cells, next_node.pos)
	     else
	          -- If the current cell has only visited neighbors, remove it from the list.
	          table.remove(Cells, CurCellIndex)
	     end
	until #Cells == 0
end

-- TODO complexity rating 0-10 
	--  AND overal difficulty increasing mechanics: darkness, crumbling floor, fireball spewers
	--  AND length increasing mechanics = teleports, jumps, switch, crystal blocks
	--  AND fitness:  
					-- ( maze size / viewing distance ) *
					-- ( length until exit / distance to exit ) * 
					-- ( branching nodes along right route / length until exit) * 10
	--  Complexity categories, 0-2: 0m, 2-4: 1m, 4-6: 2m, 6-8: 1d;2m, 8-10: 2d;2m
	--  when using crumbling floor then no switches or crystals should be used
-- TODO combat challenge rating 0-10 
	--	fitness: danger areas/available area * #enemies/#available nodes for enemies * 10 


-- TODO create new maze method
-- we have a complexity rating which we calculate each step
-- 2 ways to do this, deform a standard path or walk path and calculate each step
-- deforming requires more work, but could also be done in tiny steps
-- walking a path might cause it to create a path that is not reachable with a current setup, 
-- so instead of checking if it is possible we would then also have to check whether it would cause problems along the line

-- so we take a deforming route

-- deform tactics:
-- 		create a path directly to each exit from a random point in the maze 
--		by taking the closest available point that has an available neighbour that is even closer, we know that will give us a good path
--		do that for each exit
-- 		keep track of the current paths from the center point to the exits
--		deform a random node along current path, branch at the same random node, add random path at branch till you hit a wall, repeat until we either hit all nodes or reached a proper fitness rating
-- 		if we hit all nodes and do not have the proper fitness rating yet, then we add length increasing mechanics

-- Length increasing mechanics
--		Crystal switches and crystal blocks: add block along the right path and place a switch in a branch
											 -- OR add throwable to branch (if hero does not have bow or bombs), block right path, place switch at 
											 -- 	position which is visible and reachable (max 16 to 48 distance) on both sides of the right path
-- 		Jumps: place hole or block in front of intersection, place jump next to a branch that leads to the intersection and back over the hole
				-- OR place multiple jumps that lead to other branches and block the right path before the intersection, place a jump back as well
-- 		Teleports: block off main path, and place teleporters in branches, create a jump back
-- 		Darkness: use library file for that
-- 		Crumbling floor: create 2 overlays, a drop and the floor, and create a reset with the room entry sensor

function maze_gen.create_maze_puzzle( maze, exits, complexity )
	--maze_gen.make_dark_room()
	local length_till_exit
	local distance_to_exit
	local branches = {}
	local correct_paths = maze_gen.create_initial_paths( maze, exits ) -- the first correct path from end to beginning is the entry point
	-- log.debug(correct_paths)
	-- log.debug("correct_paths")
	-- so we reverse that one so we can always go forward with each path
	correct_paths[1] = table_util.reverse_table(correct_paths[1])
	-- deform and create branches
	for i=1, 10 do
		local path_nr = math.random(#correct_paths)
		branches[path_nr] = branches[path_nr] or {}
		table.insert(branches[path_nr], maze_gen.create_straight_branch( maze, correct_paths[path_nr], 2))
		table_util.add_table_to_table(maze_gen.deform( maze, correct_paths[path_nr] ), branches[path_nr])
	end
	-- form a plan of additions
	-- analyse the game so far

	-- replace parts of the maze with templates
	-- switch
	-- 

	-- add those special parts based on order of placement priority
	-- pikes
	-- teleports
	-- jumps
	-- <open>
end

function maze_gen.deform( maze, correct_path )
	-- log.debug("start deforming")
	--deformation of the path: placing a wall between two positions and connect via a path of nodes which have not been visited yet
	-- first select a node to travel to
	local first_node = math.random(#correct_path)
	local second_node = num_util.random_except({first_node}, 1, #correct_path)
	if second_node < first_node then first_node, second_node = second_node, first_node end
	-- that node should be part of the same correct path
	-- find a path from and to using maze_gen.create_direct_path
	local path = maze_gen.create_direct_path(correct_path[first_node], correct_path[second_node], maze)	
	-- IF FOUND
	local new_branches = {}
	if path then
		-- log.debug("found path")
		-- log.debug(path)
		-- place the wall somewhere in between the two selected nodes (random)
		local wall_node = math.random(first_node, second_node-1)
		maze_gen.place_wall_between(correct_path[wall_node], correct_path[wall_node+1], maze)
		-- add the nodes which fall in between the selected nodes to the branches

		if first_node~=wall_node then 
			table.insert(new_branches, {})
			for i=first_node+1, wall_node do table.insert(new_branches[#new_branches], correct_path[i]) end 
		end
		if second_node~=wall_node+1 then
			table.insert(new_branches, {})
			for i=second_node-1, wall_node+1, -1 do table.insert(new_branches[#new_branches], correct_path[i]) end 
		end
		-- remove nodes in between
		if second_node - first_node > 1 then
			for i=second_node-1, first_node+1, -1 do
				table.remove(correct_path, i)
			end
		end
		-- add the found path in between the selected nodes to the correct path
		for i=#path-1, 1, -1 do
			table.insert(correct_path, first_node+1, path[i])
		end
		-- open path
		maze_gen.open_path(maze, path)
	end
	-- log.debug("deform success")
	return new_branches
end

function maze_gen.create_teleport_junction( maze, correct_path, branches, nr_of_teleports)
	-- find a spot along the path that has enough branches for the nr_of_teleports
	local selected_spot
	local branches_encountered = 0
	local nodes_left = {}
	local selected_branches = {}
	for i=1, #correct_path-1, 1 do
		local pos = correct_path[i]
		for _, branch in ipairs(branches) do
			local branch_at_pos, nodes = maze_gen.branch_at_pos(maze, branch, pos)
			if branch_at_pos then 
				branches_encountered = branches_encountered + 1
				nodes_left[branches_encountered] = nodes
				selected_branches[branches_encountered] = branch
			end
			if branches_encountered == nr_of_teleports then
				selected_spot = i
				break
			end
		end
		if selected_spot ~= nil then break end
	end 
	selected_spot = selected_spot or #correct_path-1
	-- we can add a wall after that spot
	maze_gen.place_wall_between(correct_path[selected_spot], correct_path[selected_spot+1], maze)
	-- if that spot is the start of a branch then place the teleport back at the end of the branch and the way forward one spot removed
	local correct_dest, incorrect_dest
	local extra_branch_found = false
	for _, branch in ipairs(branches) do
		local branch_at_pos, nodes = maze_gen.branch_at_pos(maze, branch, correct_path[selected_spot+1])
		if branch_at_pos then 
			extra_branch_found = true
			correct_dest = maze_gen.teleport_dest( maze, branch[nodes+1] )
		end
	end
	if not extra_branch_found then correct_dest = maze_gen.teleport_dest( maze, correct_path[selected_spot+1] ) end
	incorrect_dest = maze_gen.teleport_dest( maze, correct_path[selected_spot] )
	-- add teleports to the end of the branches whereever there is space, add a destination to the beginning of the path
	--TODO
	--
end

function maze_gen.pos_to_area( pos )
	local x1 = room.x1 + room.wall_width.x + (pos.x-1)*(room.wall_width.x+room.corridor_width.x)
	local y1 = room.y1 + room.wall_width.y + (pos.y-1)*(room.wall_width.y+room.corridor_width.y)
	local x2 = room.x1 + pos.x*(room.wall_width.x+room.corridor_width.x)
	local y2 = room.y1 + pos.y*(room.wall_width.y+room.corridor_width.y)
	return {x1=x1, x2=x2, y1=y1, y2=y2}
end

function maze_gen.teleport_dest( maze, pos )
	local area = maze_gen.pos_to_area(pos)
	local prop_name = "teletransporter_destination"
	maze[pos.x][pos.y].prop = prop_name
	local details = {name=room.name_prefix..prop_name, layer=0, x=(area.x1+area.x2)/2, y=(area.y1+area.y2)/2+5, direction=-1,  sprite="entities/"..prop_name }
	local destination = map:create_destination(details)
	return destination
end

function maze_gen.teleport_entry(maze, pos, destination)

end

function maze_gen.branch_at_pos( maze, branch, pos )
	local branch_at_pos = false
	local nodes = 0
	if table_util.tbl_contains_tbl( branch[1], pos) then
		branch_at_pos = true
		for k = 2, #branch do
			if maze[branch[k].x][branch[k].y].prop then break else nodes = nodes+1 end
		end
	end
	return branch_at_pos, nodes
end

function maze_gen.create_pike_trap( maze, branches, nr_pikes )
	-- place at the end of the branch where there is space enough and that is far away enough to function as trap
	for _,branch in ipairs(branches) do
		local branch_total = #branch
		local straight_length = maze_gen.check_straight_length( maze, branch )
		-- if length is small then we can use either a detect or auto pike
		if straight_length <= 2 then
			maze[branch[straight_length].x][branch[straight_length].y].prop = "pike_detect"
		end
		--TODO
		-- if length is large then a detect might have more effect
		-- if there are two branches at a single node then we can use an auto pike that is in the same direction as the correct path
	end
end

function maze_gen.create_fireball_statue( maze )
	-- check the unused parts of the maze for this
	-- use mostly corners or far away points, which is likely the most interesting way to use the fireball statues
end

function maze_gen.check_straight_length( maze, branch )
	local pos_a = branch[1]
	local pos_b = branch[2]
	local direction, last_direction
	local straight_length = 0
	for i=2,#branch do
		pos_a = branch[i-1]
		pos_b = branch[i]
		if pos_a.x ~= pos_b.x then direction = "v" else direction = "h" end
		if last_direction == nil then last_direction = direction; straight_length = straight_length + 1
		elseif last_direction ~= direction or maze[pos_b.x][pos_b.y].prop then return straight_length
		else straight_length = straight_length + 1 end
	end
	return straight_length
end

function maze_gen.create_straight_branch( maze, correct_path, length, from )
	-- log.debug("creating straight branch")
	local possible_branches = {}
	-- random, but exhaustive, until one has been found
	local pos_list = table_util.copy(correct_path) 
	-- log.debug(pos_list)
	table_util.shuffleTable( pos_list )
	if from then table.insert(pos_list, 1, from) end
	for _,pos in ipairs(pos_list) do
		local path
		path=maze_gen.check_straight_path( maze, pos, {x=pos.x+length, y=pos.y} )
		if path then table.insert(possible_branches, path) end
		path=maze_gen.check_straight_path( maze, pos, {x=pos.x-length, y=pos.y} )
		if path then table.insert(possible_branches, path) end
		path=maze_gen.check_straight_path( maze, pos, {x=pos.x, y=pos.y+length} )
		if path then table.insert(possible_branches, path) end
		path=maze_gen.check_straight_path( maze, pos, {x=pos.x, y=pos.y-length} )
		if path then table.insert(possible_branches, path) end
		if next(possible_branches) ~= nil then break end
	end
	if next(possible_branches) == nil then
		-- log.debug("failed to create")
	 	return nil 
	end
	-- IF FOUND
	-- pick a branch
	local branch = possible_branches[math.random(#possible_branches)]
	-- open path
	maze_gen.open_path(maze, branch)
	-- log.debug("create straight branch success")
	return branch
end



-- check_straight_path always ignores the first node
function maze_gen.check_straight_path( maze, from, to )
	local path = {from}
	if from.x == to.x or from.y == to.y then
		local stepsize_x, stepsize_y = 1, 1
		if from.x > to.x then stepsize_x = -1 end
		if from.y > to.y then stepsize_y = -1 end
		local offset_x, offset_y = 0, 0
		if from.x == to.x then offset_y = stepsize_y end
		if from.y == to.y then offset_x = stepsize_x end
		for x=from.x+offset_x, to.x, stepsize_x do
			for y=from.y+offset_y, to.y, stepsize_y do
				if not maze[x] or not maze[x][y] or maze[x][y].visited == true then 
					return false 
				else
					table.insert(path, {x=x, y=y})
				end
			end
		end
	else
		error("check_straight_path: Expected aligned from and to")
		return false
	end
	return path
end

function maze_gen.place_wall_between( pos1, pos2, maze )
	local neighbors = maze_gen.get_neighbors(maze, pos1)
	for k,v in ipairs(neighbors) do
		if table_util.tbl_contains_tbl(v.pos, pos2) then 
			maze[v.pos.x][v.pos.y][v.wall_from] = true
			maze[pos1.x][pos1.y][v.wall_to] = true
			return true
		end
	end
	return false
end


-- map:create_sensor(properties)
-- Creates an entity of type sensor on the map.

-- properties (table): A table that describes all properties of the entity to create. Its key-value pairs must be:
-- name (string, optional): Name identifying the entity or nil. If the name is already used by another entity, a suffix (of the form "_2", "_3", etc.) will be automatically appended to keep entity names unique.
-- layer (number): Layer on the map (0: low, 1: intermediate, 2: high).
-- x (number): X coordinate on the map.
-- y (number): Y coordinate on the map.
-- width (number): Width of the entity in pixels.
-- height (number): Height of the entity in pixels.
-- Return value (sensor): the sensor created.
function maze_gen.make_dark_room()
	local room_sensor = map:create_sensor({layer=0, x=room.x1, y=room.y1, width=room.x2-room.x1, height=room.y2-room.y1})
	room_sensor.on_activated = 
		function() 
			local map=map; map:set_light(0) 
		end
	room_sensor.on_left = 
		function() 
			local map=map; map:set_light(1) 
		end
end

function maze_gen.create_initial_paths( maze, exits, convergence_pos )
	local starting_point
	if convergence_pos == nil then
		local possible_nodes, nr_of_nodes = maze_gen.get_not_visited(maze) 
		local viable_positions, v_pos_nr = {}, 0
		local min_dist_required = math.floor(0.4 * (0.5 * #maze + 0.5 * #maze[1]))--at least 40% of the maze size away from the exits
		for _, pos in ipairs(possible_nodes) do
			local add_node = true
			for _, exit in ipairs(exits) do
				if maze_gen.distance(pos, table_util.random(exit)) < min_dist_required then add_node = false end
			end
			if add_node then 
				v_pos_nr = v_pos_nr +1
				viable_positions[v_pos_nr] = pos
			end
		end
		starting_point = table_util.random(viable_positions)
	else
		starting_point = convergence_pos
	end

	local paths = {}
	for index, exit_list in ipairs(exits) do
		local exit = table_util.random(exit_list)
		local found_path = maze_gen.create_direct_path( starting_point, exit , maze )
		if not found_path and next(paths) ~= nil then -- will fail if the starting point is in a closed off area of the maze 
			local min_dist = maze_gen.distance(starting_point, exit)
			local next_start = starting_point

			for _,path in ipairs(paths) do
				for _,pos in ipairs(path) do
					local dist = maze_gen.distance(pos, exit)
					if dist < min_dist then 
						min_dist = dist
						next_start = pos 
					end
				end
			end
			found_path = maze_gen.create_direct_path( next_start, exit , maze )
			-- sanity check
			-- if not found_path then log.debug("maze_gen no found path... what, why not?!")	end	
		end
		table.insert(paths, found_path)
	end
	for _,path in ipairs(paths) do
		maze_gen.open_path( maze, path )
	end
	return paths
end

function maze_gen.find_closest_node( maze, to_pos, paths )
	local result
	local min_dist = math.huge
	for _,path in ipairs(paths) do
		for _,pos in ipairs(path) do
			local dist = maze_gen.distance(pos, to_pos)
			if dist < min_dist then 
				local neighbors = maze_gen.get_neighbors( maze, pos, true)
				for _, nb in ipairs(neighbors) do
					local dist_nb = maze_gen.distance(nb.pos, to_pos)
					if dist_nb < dist then
						min_dist = dist 
						result = pos 
						break
					end
				end
			end
		end
	end
	return result
end

-- direction (number): between 0 (East of the room) and 3 (South of the room).
function maze_gen.open_path( maze, path, custom_value )
	for i = 1, #path-1, 1 do
		local from, to
		if path[i+1].x > path[i].x then from, to = 2, 0
		elseif path[i+1].x < path[i].x then from, to = 0, 2
		elseif path[i+1].y > path[i].y then from, to = 1, 3
		elseif path[i+1].y < path[i].y then from, to = 3, 1 end
		maze[path[i].x][path[i].y][to]= custom_value or false
 		maze[path[i+1].x][path[i+1].y][from]=custom_value or false
        maze[path[i+1].x][path[i+1].y].visited = true
	end
end

function maze_gen.get_not_visited( maze )
	return maze_gen.get_nodes_with_visit_status( maze, false )
end

function maze_gen.get_nodes_with_visit_status( maze, visit_status )
	local n = 0
	local result = {}
	for x=1, #maze do
		for y=1, #maze[1] do
			if maze[x][y].visited == visit_status then 
				n=n+1
				result[n] = {x=x, y=y}
			end
		end
	end
	return result, n
end
 
function maze_gen.create_direct_path( from, to, maze )
	local maze_copy = table_util.copy(maze)
	maze_copy[from.x][from.y].visited=true
	local path = {from}
	local current_pos = from
	local done = false
	repeat
		local neighbors = maze_gen.get_neighbors(maze_copy, current_pos, true)
		if #neighbors == 0 then 
			repeat
				table.remove(path)
				local path_length = #path
				if path_length == 0 then return false end
				neighbors = maze_gen.get_neighbors(maze_copy, path[path_length], true)
			until #neighbors ~= 0
		else
			table_util.shuffleTable(neighbors)
		end 
		local next_node = nil
		local min_dist = math.huge
		for i=1, #neighbors, 1 do
			local node = neighbors[i]
			local dist = maze_gen.distance(node.pos, to)
			if dist < min_dist then min_dist=dist; next_node=node end
		end
		table.insert(path, next_node.pos); current_pos = next_node.pos
		maze_copy[current_pos.x][current_pos.y].visited=true
		if min_dist == 1 then table.insert(path, to); done=true end
	until done

	return path
end

function maze_gen.distance( pos1, pos2 )
	return math.abs(pos1.x - pos2.x)+math.abs(pos1.y - pos2.y)
end

--[[
-- http://wiki.roblox.com/index.php?title=Recursive_Backtracker
-- Create a table of cells, starting with just one random one
local Cells = {Vector2.new(math.random(MazeSizeX), math.random(MazeSizeY))}
repeat
     -- Select the most recent cell from the cells list (see note at bottom)
     local CurCellIndex = #Cells
     local CurCell = Cells[CurCellIndex]
     -- Make sure that this cell has unvisited neighbors
     if HasUnvisitedNeighbors(CurCell) then
          -- Collect all unvisited neighbors...
          local UnvisitedNeighbors = GetUnvisitedNeighbors(CurCell)
          -- ...and select a random one.
          local WallToDelete = UnvisitedNeighbors[math.random(#UnvisitedNeighbors)]
          -- Then carve a path to it by deleting the wall between them
          DeleteWall(WallToDelete)
          -- Add the neighbor to the end of the list of cells to make sure it is picked as the current one
          table.insert(Cells, NewCell)
     else
          -- If the current cell has only visited neighbors, remove it from the list.
          table.remove(Cells, CurCellIndex)
     end
until #Cells == 0

-- http://wiki.roblox.com/index.php?title=Prim%27s_Algorithm
function Prim(start)
	local closed = {}
	closed[start] = true
 
	--search until all nodes have been found
	while nodes_to_be_found do
		local current_best
		--go through the closed set and find their neighbors
		for parent in pairs(closed) do
			for _, node in ipairs(parent:neighbors()) do
				--make sure node is not in closed set already
				if not closed[node] then
					--compare to what is currently the best node
					if not current_best or node:distance(parent) < current_best:distance(current_best.parent) then
						node.parent = parent
						current_best = node
					end
				end
			end
		end
		--add the selected node to closed set
		closed[current_best] = true
	end
end

-- http://wiki.roblox.com/index.php?title=Hunt-and-Kill
function Hunt_and_Kill(node)
	node.visited = true
 
	--Take visited neighbors out of the possible selections
	local neighbors = node:neighbors()
	for i=#neighbors,1,-1 do
		if neighbors[i].visited then
			table.remove(neighbors,i)
		end
	end
	--if there are unvisited neighbors of node, select a random one
	if #neighbors>0 then
		local new_node = neighbors[math.random(#neighbors)]
		--delete the wall between the two nodes
		deleteBetween(node,new_node)
		--repeat process on new_node
		Hunt_and_Kill(new_node)
 
	--if there are no unvisited neighbors, begin hunt for new neighbor
	else
		for y = 1, bottom_of_maze do
			for x = 1, end_of_maze do
				--if the node has not been visited and is next to a visited neighbor, select
				if not maze[x][y].visited then
					local visitedNeighbor = false
					for _, neighbor in pairs(maze[x][y]:neighbors()) do
						if v.visted then
							visitedNeighbor = neighbor
							break
						end
					end
					--if found, begin process over again
					if visitedNeighbor then
						Hunt_and_Kill(visitedNeighbor)
					end
				end
			end
		end
	end
end
]]--

return maze_gen