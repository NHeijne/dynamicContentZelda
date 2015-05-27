local vl = {}

local log = {
	cure_brewer=false,
	cure_witch=false,
	apples=0,
	found_bottle=false,
	filled_bottle=false,
	rupees = 0,
	rupees_after_village_logged=false,
	areas_visited={ bush_patch=false, woods_exit=false, plaza=false, brewer=false},
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

function vl.to_file()
	local npc_order = {	"witch", 
						"mom", "dad", "brother",
						"lefttwin", "righttwin", "glassesguy", "oldwoman", "oldguyleft", "oldguyright", 
						"innkeeper", "youngfellow", "merchant", "marketguy", "brewer", "littleguy"}
	local area_order = {"bush_patch", "woods_exit", "plaza", "brewer"}
	-- the csv will contain data in this order:
	-- Player name
	-- # NPCs talked to
	-- cure brewer
	-- cure witch
	-- apples
	-- rupees
	-- found_bottle
	-- filled_bottle
	-- areas visited
	-- NPCs options explored, options_available
	-- fraction of options explored of the talked to npcs
	-- fraction of NPCs talked to
end



return vl