local table_util = require("table_util")

local vl = {}

vl.log = {
	-- personal settings
	name=game:get_player_name(),

	start_time = 0,
	village_exit_time=0,
	cure_brewer=false,
	cure_witch=false,
	apples=0,
	found_bottle=false,
	filled_bottle=false,
	rupees = 0,
	village_logged=false,
	areas_visited={ bush_area=false, woods_exit=false, plaza=false, brewer_area=false},
	NPC={
			-- witch area
			witch={talked=false, options_explored={}, options_available=1},
			-- house area
			mom={talked=false, options_explored={}, options_available=3},
			dad={talked=false, options_explored={}, options_available=2},
			brother={talked=false, options_explored={}, options_available=1},
			-- village area
			lefttwin={talked=false, options_explored={}, options_available=1}, 
			righttwin={talked=false, options_explored={}, options_available=1}, 
			glassesguy={talked=false, options_explored={}, options_available=1}, 
			oldwoman={talked=false, options_explored={}, options_available=2}, 
			oldguyleft={talked=false, options_explored={}, options_available=1}, 
			oldguyright={talked=false, options_explored={}, options_available=1}, 
			innkeeper={talked=false, options_explored={}, options_available=1}, 
			youngfellow={talked=false, options_explored={}, options_available=1}, 
			merchant={talked=false, options_explored={}, options_available=2}, 
			marketguy={talked=false, options_explored={}, options_available=1}, 
			brewer={talked=false, options_explored={}, options_available=2}, 
			littleguy={talked=false, options_explored={}, options_available=2}
		}
}

vl.log_before_dungeons ={}

function vl.copy_log()
	vl.log_before_dungeons = table_util.copy(vl.log)
end

function vl.to_file( game, suffix )
	-- name, npcs_talked_to, options_taken, total_options, % options_taken, % npcs talked to, 
	-- cure brewer, cure witch, apples gotten, rupees, bottle_found, filled_bottle, 
	-- bush_area_visited, woods_exit_visited, plaza_visited, brewer_area_visited
	-- time_spent_in_village
	local npc_order = {	"witch", 
						"mom", "dad", "brother",
						"lefttwin", "righttwin", "glassesguy", "oldwoman", "oldguyleft", "oldguyright", 
						"innkeeper", "youngfellow", "merchant", "marketguy", "brewer", "littleguy"}
	local area_order = {"bush_area", "woods_exit", "plaza", "brewer_area"}
	-- the csv will contain data in this order:
	local data_to_write={}	
	local logbd = vl.log_before_dungeons
	-- Player name
	table.insert(data_to_write, logbd.name)
	-- # NPCs talked to
	-- NPCs options explored, options_available
	-- fraction of options explored of the talked to npcs
	-- fraction of NPCs talked to
	local npcs_talked_to = 0
	local total_options =0
	local options_taken =0
	for index,name in ipairs(npc_order) do
		local data_point = logbd.NPC[name]
		if data_point.talked then 
			npcs_talked_to = npcs_talked_to+1
			total_options = total_options + data_point.options_available
			for i=1,data_point.options_available do
				if data_point.options_explored[i] then options_taken = options_taken + 1 end
			end
		end
	end
	table.insert(data_to_write, npcs_talked_to)
	table.insert(data_to_write, options_taken)
	table.insert(data_to_write, total_options)
	table.insert(data_to_write, options_taken/total_options)
	table.insert(data_to_write, npcs_talked_to/#npc_order)
	-- cure brewer
	-- cure witch
	if logbd.cure_brewer then 
		table.insert(data_to_write, 1)
		table.insert(data_to_write, 0)
	elseif logbd.cure_witch then
		table.insert(data_to_write, 0)
		table.insert(data_to_write, 1)
	else 
		table.insert(data_to_write, 0)
		table.insert(data_to_write, 0)
	end
	-- apples
	table.insert(data_to_write, logbd.apples)
	-- rupees
	table.insert(data_to_write, logbd.rupees)
	-- found_bottle
	-- filled_bottle
	if game:get_value("bottle_1") then
		table.insert(data_to_write, 1)
		if logbd.filled_bottle then 
			table.insert(data_to_write, 1)
		else
			table.insert(data_to_write, 0)
		end
	else
		table.insert(data_to_write, 0)
		table.insert(data_to_write, 0)
	end
	-- areas visited
	for index,name in ipairs(area_order) do
		if logbd.areas_visited[name] then table.insert(data_to_write, 1)
	    else  table.insert(data_to_write, 0) end
	end
	-- time spent in village
	table.insert(data_to_write, logbd.village_exit_time-logbd.start_time)
	vl.writeTableToFile(data_to_write, "village_log_"..suffix.."_dungeon.csv")
end

function vl.writeTableToFile (dataTable, file) 
	local f = sol.file.open(file,"a+")
	for k,v in pairs(dataTable) do
		f:write(v)
		if k ~= #dataTable then f:write(",")
		else f:write("\n") end
		f:flush()
	end
	f:flush(); f:close()
end



return vl