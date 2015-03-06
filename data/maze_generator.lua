local maze_generator = {}

local log = require("log")
local table_util = require("table_util")
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

function maze_generator.set_map( given_map )
	map = given_map
end

function maze_generator.set_room( area )
	room = area
end

function maze_generator.generate_maze( area, corridor_width, exit_areas, exclusion)
	local maze = {}
	local wall_width = 8
	log.debug("initialize_maze")
	maze_generator.initialize_maze( maze, area, wall_width, corridor_width )
	log.debug(maze)
	log.debug("excluding areas")
	if exclusion ~= nil and next(exclusion) ~= nil then maze_generator.exclude( area, maze, exclusion, corridor_width, wall_width ) end
	log.debug("open_exits")
	log.debug(exit_areas)
	local exits = maze_generator.open_exits( maze, exit_areas, area, wall_width, corridor_width )
	log.debug("maze pathfinding start")
	maze_generator.create_maze_puzzle( maze, exits, area )
	log.debug("maze pathfinding end")
	log.debug(maze)
	local area_list = maze_generator.create_area_list( maze, area, corridor_width, wall_width )
	log.debug(area_list)
 	return area_list
end

function maze_generator.exclude( area, maze, exclusion, corridor_width, wall_width )
	log.debug("excluding areas")
	log.debug(exclusion)
	-- determine in which node the topleft area is located
	local excluded_node_area = {}
	for _, exclusion_details in ipairs(exclusion) do
		local exclusion_area = exclusion_details
		local sides_open = exclusion_details.sides_open

		-- identify in which nodes the exclusion area is located
		local x1 = math.ceil((exclusion_area.x1-area.x1)/(wall_width+corridor_width))
		local y1 = math.ceil((exclusion_area.y1-area.y1)/(wall_width+corridor_width))
		local x2 = math.ceil((exclusion_area.x2-area.x1)/(wall_width+corridor_width))
		local y2 = math.ceil((exclusion_area.y2-area.y1)/(wall_width+corridor_width))

		-- directions 1:north, 2:east, 3:south, 4:west
		for x=x1, x2 do
			for y=y1, y2 do
				if not(x < 1 or y<1 or x>#maze or y >#maze[1]) then
					-- open up everything
					maze[x][y][1] = false
					maze[x][y][2] = false
					maze[x][y][3] = false
					maze[x][y][4] = false
					-- close the side if it's not supposed to be open
					if x == x1 and not table_util.contains(sides_open, "west") then
						maze[x][y][4] = true end
					if x == x2 and not table_util.contains(sides_open, "east") then
						maze[x][y][2] = true end
					if y == y1 and not table_util.contains(sides_open, "north") then
						maze[x][y][1] = true end
					if y == y2 and not table_util.contains(sides_open, "south") then
						maze[x][y][3] = true end
					maze[x][y].visited = true
				end
			end
		end
		table.insert(excluded_node_area, {x1=x1, y1=y1, x2=x2, y2=y2})
	end
end

function maze_generator.create_area_list( maze, area, corridor_width, wall_width )
	-- standard 8x8 patterns
	local max_x=#maze
	local max_y=#maze[1]
	local area_list = {}
	-- if at least one wall is connected to the post then create it
	if maze[1][1][1] or maze[1][1][4] then
		table.insert(area_list, {area={x1=area.x1, y1=area.y1, x2=area.x1+wall_width, y2=area.y1+wall_width}, pattern="maze_post"})
	end
	-- directions 1:north, 2:east, 3:south, 4:west
	for x=1, max_x do
		for y=1, max_y do
			if x==1 then -- create left side, skipping topleft
				if maze[x][y][4] then area_list[#area_list+1] = {area={x1=area.x1, y1=area.y1+wall_width+(wall_width+corridor_width)*(y-1),
												 x2=area.x1+wall_width, y2=area.y1+(wall_width+corridor_width)*y}, pattern="maze_wall_ver"} end
			 	if maze[x][y][4] or maze[x][y][3] or ( y<max_y and maze[x][y+1][4]) then
					area_list[#area_list+1] = {area={x1=area.x1, y1=area.y1+(wall_width+corridor_width)*y, 
												  	 x2=area.x1+wall_width, y2=area.y1+(wall_width+corridor_width)*y+wall_width}, 
											   pattern="maze_post"} end
			end
			if y==1 then -- create top side, skipping topleft
				if maze[x][y][1] then area_list[#area_list+1] = {area={x1=area.x1+wall_width+(wall_width+corridor_width)*(x-1), y1=area.y1,
												 x2=area.x1+(wall_width+corridor_width)*x, y2=area.y1+wall_width}, pattern="maze_wall_hor"} end
				-- if at least one wall is connected to the post then create it
				if maze[x][y][1] or maze[x][y][2] or ( x<max_x and maze[x+1][y][1]) then
					area_list[#area_list+1] = {area={x1=area.x1+(wall_width+corridor_width)*x, y1=area.y1, 
												  	 x2=area.x1+(wall_width+corridor_width)*x+wall_width, y2=area.y1+wall_width}, 
											   pattern="maze_post"} end
			end
			-- bottom side
			if maze[x][y][3] then area_list[#area_list+1] = {area={x1=area.x1+wall_width+(wall_width+corridor_width)*(x-1),
															 	   y1=area.y1+(wall_width+corridor_width)*y,
															 	   x2=area.x1+(wall_width+corridor_width)*x,
															 	   y2=area.y1+wall_width+(wall_width+corridor_width)*y,
															 	   }, pattern="maze_wall_hor"} end
			-- right side
			if maze[x][y][2] then area_list[#area_list+1] = {area={x1=area.x1+(wall_width+corridor_width)*x,
															 	   y1=area.y1+wall_width+(wall_width+corridor_width)*(y-1),
															 	   x2=area.x1+wall_width+(wall_width+corridor_width)*x,
															 	   y2=area.y1+(wall_width+corridor_width)*y,
															 	   }, pattern="maze_wall_ver"} end
			-- maze post
			-- if at least one wall is connected to the post then create it
			if maze[x][y][2] or maze[x][y][3] or ( x<max_x and maze[x+1][y][3]) or (y<max_y and maze[x][y+1][2]) then
				area_list[#area_list+1] = {area={x1=area.x1+(wall_width+corridor_width)*x,
										 	   y1=area.y1+(wall_width+corridor_width)*y,
										 	   x2=area.x1+wall_width+(wall_width+corridor_width)*x,
										 	   y2=area.y1+wall_width+(wall_width+corridor_width)*y,
										 	   }, pattern="maze_post"} end
		end
	end
	return area_list
end

function maze_generator.initialize_maze( maze, area, wall_width, corridor_width )
	local width = area.x2-area.x1
	local height = area.y2-area.y1
	local x_amount = math.floor((width-wall_width)/(wall_width+corridor_width))
	local y_amount = math.floor((height-wall_width)/(wall_width+corridor_width))
	for x=1,x_amount do
		maze[x]={}
		for y=1, y_amount do
			maze[x][y] = {[1]=true, [2]=true, [3]=true, [4]=true, visited = false} 
		end
	end
end

function maze_generator.open_exits( maze, exit_areas, area, wall_width, corridor_width )
	local width = area.x2-area.x1
	local height = area.y2-area.y1
	local exits = {}
	for _, v in ipairs(exit_areas) do
		-- identify in which node the exit area is located
		local x1 = (v.x1-area.x1)/(wall_width+corridor_width)
		local y1 = (v.y1-area.y1)/(wall_width+corridor_width)
		local x2 = (v.x2-area.x1-wall_width)/(wall_width+corridor_width)
		local y2 = (v.y2-area.y1-wall_width)/(wall_width+corridor_width)

		local selected_x_min = num_util.clamp(math.ceil(x1), 1, #maze)
		local selected_x_max = num_util.clamp(math.ceil(x2), 1, #maze)
		local selected_y_min = num_util.clamp(math.ceil(y1), 1, #maze[1])
		local selected_y_max = num_util.clamp(math.ceil(y2), 1, #maze[1])
		
		local direction 
		-- directions 1:north, 2:east, 3:south, 4:west
		if v.y2 <= area.y1 and v.x1 < area.x2 and v.x2 > area.x1 then direction = 1 end
		if v.y1 >= area.y2 and v.x1 < area.x2 and v.x2 > area.x1 then direction = 3 end
		if v.x2 <= area.x1 and v.y1 < area.y2 and v.y2 > area.y1 then direction = 4 end
		if v.x1 >= area.x2 and v.y1 < area.y2 and v.y2 > area.y1 then direction = 2 end
		for x=selected_x_min, selected_x_max do
			for y=selected_y_min, selected_y_max do
				maze[x][y][direction] = false
				exits[#exits+1] = {x=x, y=y}
			end
		end
	end
	return exits
end

-- directions 1:north, 2:east, 3:south, 4:west
function maze_generator.get_neighbors(maze, position, only_get_unvisited)
	local neighbors={}
	if position.x < #maze then neighbors[#neighbors+1]={pos={x=position.x+1, y=position.y}, node=maze[position.x+1][position.y], wall_to=2, wall_from=4} end
	if position.x > 1 then neighbors[#neighbors+1]={pos={x=position.x-1, y=position.y}, node=maze[position.x-1][position.y], wall_to=4, wall_from=2} end
	if position.y < #maze[1] then neighbors[#neighbors+1]={pos={x=position.x, y=position.y+1},node=maze[position.x][position.y+1], wall_to=3, wall_from=1} end
	if position.y > 1 then neighbors[#neighbors+1]={pos={x=position.x, y=position.y-1},node=maze[position.x][position.y-1], wall_to=1, wall_from=3} end
	if only_get_unvisited then
		for i=#neighbors,1,-1 do
			if neighbors[i].node.visited then table.remove(neighbors, i) end
		end
	end
	return neighbors
end

-- http://wiki.roblox.com/index.php?title=Recursive_Backtracker
function maze_generator.standard_recursive_maze( maze )
	-- Create a table of cells, starting with just one random one
	local Cells = {[1]={x=math.random(#maze), y=math.random(#maze[1])}}
	maze[Cells[1].x][Cells[1].y].visited = true
	repeat
	     -- Select the most recent cell from the cells list (see note at bottom)
	     local CurCellIndex = #Cells
	     local CurCell = Cells[CurCellIndex]
	     local neighbors = maze_generator.get_neighbors(maze, CurCell)
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

function maze_generator.create_maze_puzzle( maze, exits, complexity )
	--maze_generator.make_dark_room()
	local length_till_exit
	local distance_to_exit
	local branches = {}
	local correct_paths = maze_generator.create_initial_paths( maze, exits )
	-- deform and create branches
	for i=1, 10 do
		table.insert(branches, maze_generator.create_straight_branch( maze, correct_paths[math.random(#correct_paths)], 2))
		table_util.add_table_to_table(maze_generator.deform( maze,  correct_paths[math.random(#correct_paths)] ), branches)
	end
end

function maze_generator.deform( maze, correct_path )
	log.debug("start deforming")
	--deformation of the path: placing a wall between two positions and connect via a path of nodes which have not been visited yet
	-- first select a node to travel to
	local first_node = math.random(#correct_path)
	local second_node = num_util.random_except({first_node}, 1, #correct_path)
	if second_node < first_node then first_node, second_node = second_node, first_node end
	-- that node should be part of the same correct path
	-- find a path from and to using maze_generator.create_direct_path
	local path = maze_generator.create_direct_path(correct_path[first_node], correct_path[second_node], maze)	
	-- IF FOUND
	local new_branches = {}
	if path then
		log.debug("found path")
		log.debug(path)
		-- place the wall somewhere in between the two selected nodes (random)
		local wall_node = math.random(first_node, second_node-1)
		maze_generator.place_wall_between(correct_path[wall_node], correct_path[wall_node+1], maze)
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
		maze_generator.open_path(maze, path)
	end
	log.debug("deform success")
	return new_branches
end

function maze_generator.create_straight_branch( maze, correct_path, length, from )
	log.debug("creating straight branch")
	local possible_branches = {}
	-- random, but exhaustive, until one has been found
	local pos_list = table_util.copy(correct_path) 
	log.debug(pos_list)
	table_util.shuffleTable( pos_list )
	if from then table.insert(pos_list, 1, from) end
	for _,pos in ipairs(pos_list) do
		local path
		path=maze_generator.check_straight_path( maze, pos, {x=pos.x+length, y=pos.y} )
		if path then table.insert(possible_branches, path) end
		path=maze_generator.check_straight_path( maze, pos, {x=pos.x-length, y=pos.y} )
		if path then table.insert(possible_branches, path) end
		path=maze_generator.check_straight_path( maze, pos, {x=pos.x, y=pos.y+length} )
		if path then table.insert(possible_branches, path) end
		path=maze_generator.check_straight_path( maze, pos, {x=pos.x, y=pos.y-length} )
		if path then table.insert(possible_branches, path) end
		if next(possible_branches) ~= nil then break end
	end
	if next(possible_branches) == nil then
		log.debug("failed to create")
	 	return nil 
	end
	-- IF FOUND
	-- pick a branch
	local branch = possible_branches[math.random(#possible_branches)]
	-- open path
	maze_generator.open_path(maze, branch)
	log.debug("create straight branch success")
	return branch
end



-- check_straight_path always ignores the first node
function maze_generator.check_straight_path( maze, from, to )
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
				if not maze[x] or not maze[x][y] or maze[x][y].visited then 
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

function maze_generator.place_wall_between( pos1, pos2, maze )
	local neighbors = maze_generator.get_neighbors(maze, pos1)
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
function maze_generator.make_dark_room()
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

function maze_generator.create_initial_paths( maze, exits )
	local possible_nodes, nr_of_nodes = maze_generator.get_not_visited(maze) 
	local starting_point = possible_nodes[math.random(nr_of_nodes)]

	local paths = {}
	for index, exit in ipairs(exits) do
		local found_path = maze_generator.create_direct_path( starting_point, exit , maze )
		if not found_path and next(paths) ~= nil then -- will fail if the starting point is in a closed off area of the maze 
			local min_dist = maze_generator.distance(starting_point, exit)
			local next_start = starting_point
			for _,path in ipairs(paths) do
				for _,pos in ipairs(path) do
					if maze_generator.distance(pos, exit) < min_dist then next_start = pos end
				end
			end
			found_path = maze_generator.create_direct_path( next_start, exit , maze )
			-- sanity check
			if not found_path then log.debug("maze_generator no found path... what, why not?!")	end	
		end
		table.insert(paths, found_path)
	end
	for _,path in ipairs(paths) do
		maze_generator.open_path( maze, path )
	end
	return paths
end

-- directions 1:north, 2:east, 3:south, 4:west
function maze_generator.open_path( maze, path )
	for i = 1, #path-1, 1 do
		local from, to
		if path[i+1].x > path[i].x then from, to = 4, 2
		elseif path[i+1].x < path[i].x then from, to = 2, 4
		elseif path[i+1].y > path[i].y then from, to = 1, 3
		elseif path[i+1].y < path[i].y then from, to = 3, 1 end
		maze[path[i].x][path[i].y][to]=false
 		maze[path[i+1].x][path[i+1].y][from]=false
        maze[path[i+1].x][path[i+1].y].visited = true
	end
end

function maze_generator.get_not_visited( maze )
	local n = 0
	local result = {}
	for x=1, #maze do
		for y=1, #maze[1] do
			if maze[x][y].visited == false then 
				n=n+1
				result[n] = {x=x, y=y}
			end
		end
	end
	return result, n
end

-- TODO test this, not yet functional
function maze_generator.create_direct_path( from, to, maze )
	local maze_copy = table_util.copy(maze)
	maze_copy[from.x][from.y].visited=true
	local path = {from}
	local current_pos = from
	local done = false
	repeat
		local neighbors = maze_generator.get_neighbors(maze_copy, current_pos, true)
		if #neighbors == 0 then 
			repeat
				table.remove(path)
				local path_length = #path
				if path_length == 0 then return false end
				neighbors = maze_generator.get_neighbors(maze_copy, path[path_length], true)
			until #neighbors ~= 0
		end 
		local next_node = nil
		local min_dist = math.huge
		for i=1, #neighbors, 1 do
			local node = neighbors[i]
			local dist = maze_generator.distance(node.pos, to)
			if dist < min_dist then min_dist=dist; next_node=node end
		end
		table.insert(path, next_node.pos); current_pos = next_node.pos
		maze_copy[current_pos.x][current_pos.y].visited=true
		if min_dist == 1 then table.insert(path, to); done=true end
	until done

	return path
end

function maze_generator.distance( pos1, pos2 )
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

return maze_generator