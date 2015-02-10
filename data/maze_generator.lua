local maze_generator = {}

local log = require("log")
local table_util = require("table_util")

-- NOTE TODO this can later be used to find a good path in areas or transitions
-- reason not to use this for pathfinding of transitions: too many possible ways
-- it will fail or take longer than breadth first search of boundary areas

-- area {x1, y1, x2, y2}
-- object width in pixels (walls) --predetermined, in dungeons it can be 8x8 or 24x16 and comprised of multiple parts
	--TODO function that places from top to bottom the areas and corrects the patterns if needed
-- prefered corridor width (easily done if uniform across maze)
-- TODO off limit areas exclude={[1]={area={x1, y1, x2, y2},sides_open={"wind_direction"} } 
-- exit nodes given as areas
-- TODO complexity rating 0-10 
	--  AND overal difficulty increasing mechanics: darkness, crumbling floor
	--  AND length increasing mechanics = teleports, jumps, switch
	--  AND fitness: ( available nodes / amount of nodes ) * 
					-- (length until exit / distance to exit ) * 
					-- ( branching nodes along right route / node amount along right route) * 10
-- TODO combat challenge rating 0-10 
	--	fitness: danger areas/available area * #enemies/#available nodes for enemies * 10 
function maze_generator.generate_maze( area, corridor_width, exit_areas, exclusion, method )
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
	if method == nil or method == "standard" then maze_generator.standard_recursive_maze( maze )
	else -- other methods to construct desired qualities, or generate using genetic algorithms
	end
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
		local selected_x_min, selected_y_min, selected_x_max, selected_y_max
		selected_x_min = math.ceil(x1)
		selected_x_max = math.ceil(x2)
		selected_y_min = math.ceil(y1)
		selected_y_max = math.ceil(y2) 
		if selected_y_min < 1 then selected_y_min = 1 end
		if selected_y_max < 1 then selected_y_max = 1 end
		if selected_y_min > #maze[1] then selected_y_min = #maze[1] end
		if selected_y_max > #maze[1] then selected_y_max = #maze[1] end
		if selected_x_min < 1 then selected_x_min = 1 end
		if selected_x_max < 1 then selected_x_max = 1 end
		if selected_x_min > #maze then selected_x_min = #maze end
		if selected_x_max > #maze then selected_x_max = #maze end
		local direction 
		-- directions 1:north, 2:east, 3:south, 4:west
		if v.y2 <= area.y1 and v.x1 < area.x2 and v.x2 > area.x1 then direction = 1 end
		if v.y1 >= area.y2 and v.x1 < area.x2 and v.x2 > area.x1 then direction = 3 end
		if v.x2 <= area.x1 and v.y1 < area.y2 and v.y2 > area.y1 then direction = 4 end
		if v.x1 >= area.x2 and v.y1 < area.y2 and v.y2 > area.y1 then direction = 2 end
		for x=selected_x_min, selected_x_max do
			for y=selected_y_min, selected_y_max do
				maze[x][y][direction] = false
				exits[#exits+1] = {x=x, y=x}
			end
		end
	end
	return exits
end

function maze_generator.get_neighbors(maze, position)
	local neighbors={}
	if position.x < #maze then neighbors[#neighbors+1]={pos={x=position.x+1, y=position.y}, node=maze[position.x+1][position.y], wall_to=2, wall_from=4} end
	if position.x > 1 then neighbors[#neighbors+1]={pos={x=position.x-1, y=position.y}, node=maze[position.x-1][position.y], wall_to=4, wall_from=2} end
	if position.y < #maze[1] then neighbors[#neighbors+1]={pos={x=position.x, y=position.y+1},node=maze[position.x][position.y+1], wall_to=3, wall_from=1} end
	if position.y > 1 then neighbors[#neighbors+1]={pos={x=position.x, y=position.y-1},node=maze[position.x][position.y-1], wall_to=1, wall_from=3} end
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