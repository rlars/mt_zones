
zones_path = minetest.get_modpath("zones")

dofile(zones_path.."/hud_helpers.lua");
dofile(zones_path.."/global_step_callback.lua");
dofile(zones_path.."/datastore.lua");


GlobalStepCallback.register_globalstep_per_player("update_hud", function (player, dtime)
	local zones_hud = datastore.get_or_create_table(player, "zones_hud")
	if zones_hud and zones_hud.hud then
		Hud.update_hud(zones_hud.hud, player)
	end
end)

zones = {
	dropsites = {}
}

local function each_min(a, b)
	--vector.combine(v, w, func)
	return vector.new(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z))
end

local function each_max(a, b)
	return vector.new(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z))
end

MinMaxArea = {}
function MinMaxArea.Create(a, b)
	return {
		min = each_min(a, b),
		max = each_max(a, b)
	}
end

function MinMaxArea.is_in_zone(self, p)
	return self.min.x <= p.x and self.min.y <= p.y and self.min.z <= p.z and
		   self.max.x >= p.x and self.max.y >= p.y and self.max.z >= p.z
end

-- returns the position with the lowest y coordinate that is empty
function MinMaxArea.get_lowest_empty(self)
	local diff = vector.subtract(self.max, self.min)
	for dy = 0, diff.y do
		for dx = 0, diff.x do
			for dz = 0, diff.z do
				local node = minetest.get_node(vector.offset(self.min, dx, dy, dz))
				if node.name == "air" or node.name == "vacuum:vacuum" then
					return vector.offset(self.min, dx, dy, dz)
				end
			end
		end
	end
end


local function is_vector_in_table(t, v)
	for _, q in ipairs(t) do
		if q.x == v.x and q.y == v.y and q.z == v.z then return true end
	end
	return false
end

function MinMaxArea.find_area_in_list(t, v)
	for _, zone in ipairs(t) do
		if MinMaxArea.is_in_zone(zone, v) then return zone end
	end
end


ResourceArea = {}
-- start is a vector
-- area is a MinMaxArea
function ResourceArea.Create(start, area, resource_type)
	return {
		start = start,
		area = area,
		type = resource_type
	}
end



local function update_dropmarker_hud(user, show)
	local zones_hud = datastore.get_or_create_table(user, "zones_hud")
	if not zones_hud.hud then
		zones_hud.hud = Hud.Create()
	end
	local theHud = zones_hud.hud
	local player_store = user:get_meta()
	local hud_ids = datastore.get_or_create_table(user, "dropmarker_hud_ids")
	local areas = minetest.deserialize(player_store:get_string("dropmarker_areas"))
	if show and areas then
		local new_points = {}
		for i, area in ipairs(areas) do
			local area_center = vector.multiply(vector.add(area.min, area.max), 0.5)
			local image = "zones_frame_bg.png^zones_dropsite.png^zones_frame_blue.png^[noalpha"
			table.insert(new_points, HudPoint.Create(area_center, image)) -- name = "dropmarkers_area_" .. tostring(i), 
		end
		Hud.add_hud_points(theHud, user, new_points)
	else
		Hud.remove_all(theHud, user)
	end
end

-- area given by { min, max }
local function add_droparea(user, area)
	local player_store = user:get_meta()
	local areas = minetest.deserialize(player_store:get_string("dropmarker_areas"))
	if not areas then areas = {} end
	table.insert(areas, area)
	player_store:set_string("dropmarker_areas", minetest.serialize(areas))
end

first_drop_marked = nil

local function toggle_dropmarker(_, user, pointed_thing)
	local player_store = user:get_meta()
	local state = player_store:get_string("show_dropmarkers")
	if state == "" or state == "no" then
		player_store:set_string("show_dropmarkers", "yes")
		update_dropmarker_hud(user, true)
	else
		player_store:set_string("show_dropmarkers", "no")
		update_dropmarker_hud(user, false)
	end
end


local function use_dropmarker_tool(_, user, pointed_thing)
	local target_pos = nil

	minetest.debug("create dropmarker")
	if pointed_thing.type == "node" then
		target_pos = pointed_thing.above
		if not first_drop_marked then
			first_drop_marked = target_pos
		else
			local area = MinMaxArea.Create(first_drop_marked, target_pos)
			table.insert(zones.dropsites, area)
			add_droparea(user, area)
			first_drop_marked = nil
		end
	end
end


minetest.register_craftitem("zones:dropmarker", {
	description = "Drop",
	inventory_image = "zones_dropsite.png^zones_frame_blue.png",
	on_use = toggle_dropmarker,
	on_secondary_use = use_dropmarker_tool,
	on_place = use_dropmarker_tool

})


local function create_inventorycube_image(node_name)
	local node = minetest.registered_nodes[node_name]	
	local tile_name_fixed = string.gsub(node.tiles[1], "[\\^]", "&")
	return "[inventorycube{" .. tile_name_fixed .. "{" .. tile_name_fixed .. "{" .. tile_name_fixed
end


local function update_resourceareas_hud(user, show)
	local zones_hud = datastore.get_or_create_table(user, "zones_hud")
	if not zones_hud.hud then
		zones_hud.hud = Hud.Create()
	end
	local theHud = zones_hud.hud
	local player_store = user:get_meta()
	local hud_ids = datastore.get_or_create_table(user, "resourcearea_hud_ids")
	local areas = minetest.deserialize(player_store:get_string("resource_areas"))
	if show and areas then
		local new_points = {}
		for i, area in ipairs(areas) do
			local image = create_inventorycube_image(area.type) .. "^[resize:32x32^zones_frame_yellow.png"
			table.insert(new_points, HudPoint.Create(area.start, image)) -- name = "dropmarkers_area_" .. tostring(i), 
		end
		Hud.add_hud_points(theHud, user, new_points)
	else
		Hud.remove_all(theHud, user)
	end
end


-- area given by { min, max }
local function add_resourcearea(user, area)
	local player_store = user:get_meta()
	local areas = minetest.deserialize(player_store:get_string("resource_areas"))
	if not areas then areas = {} end
	table.insert(areas, area)
	player_store:set_string("resource_areas", minetest.serialize(areas))
end


local function toggle_scan(_, user, pointed_thing)
	local player_store = user:get_meta()
	local state = player_store:get_string("show_resourceareas")
	if state == "" or state == "no" then
		player_store:set_string("show_resourceareas", "yes")
		update_resourceareas_hud(user, true)
	else
		player_store:set_string("show_resourceareas", "no")
		update_resourceareas_hud(user, false)
	end
end


local function get_metadata(toolstack)
	local m = minetest.deserialize(toolstack:get_metadata())
	if not m then m = {} end
	if not m.charge then m.charge = 0 end
	if not m.target then m.target = "" end
	if not m.look_depth then m.look_depth = 7 end
	if not m.look_radius then m.look_radius = 1 end
	return m
end

-- mostly copied from technic:prospector, except the part where the zone is created
local function scan(toolstack, user, pointed_thing)
	if not user or not user:is_player() or user.is_fake_player then return end
	if pointed_thing.type ~= "node" then return end
	local toolmeta = get_metadata(toolstack)
	local look_diameter = toolmeta.look_radius * 2 + 1
	local charge_to_take = toolmeta.look_depth * (toolmeta.look_depth + 1) * look_diameter * look_diameter
	if toolmeta.charge < charge_to_take then return end
	if toolmeta.target == "" then
		minetest.chat_send_player(user:get_player_name(), "Right-click to set target block type")
		return
	end
	if not technic.creative_mode then
		toolmeta.charge = toolmeta.charge - charge_to_take
		toolstack:set_metadata(minetest.serialize(toolmeta))
		technic.set_RE_wear(toolstack, toolmeta.charge, technic.power_tools[toolstack:get_name()])
	end
	-- What in the heaven's name is this evil sorcery ?
	local start_pos = pointed_thing.under
	local forward = minetest.facedir_to_dir(minetest.dir_to_facedir(user:get_look_dir(), true))
	local right = forward.x ~= 0 and { x=0, y=1, z=0 } or (forward.y ~= 0 and { x=0, y=0, z=1 } or { x=1, y=0, z=0 })
	local up = forward.x ~= 0 and { x=0, y=0, z=1 } or (forward.y ~= 0 and { x=1, y=0, z=0 } or { x=0, y=1, z=0 })
	local base_pos = vector.add(start_pos, vector.multiply(vector.add(right, up), - toolmeta.look_radius))
	local found = false
	for f = 0, toolmeta.look_depth-1 do
		for r = 0, look_diameter-1 do
			for u = 0, look_diameter-1 do
				if minetest.get_node(
						vector.add(
							vector.add(
								vector.add(base_pos,
									vector.multiply(forward, f)),
								vector.multiply(right, r)),
							vector.multiply(up, u))
						).name == toolmeta.target then
					found = true
					break
				end
			end
			if found then break end
		end
		if found then break end
	end
	if math.random() < 0.02 then
		found = not found
	end

	minetest.sound_play("technic_prospector_"..(found and "hit" or "miss"), {
		pos = vector.add(user:get_pos(), { x = 0, y = 1, z = 0 }),
		gain = 1.0,
		max_hear_distance = 10
	})
	if found then
		local max = vector.add(
			vector.add(
				vector.add(base_pos,
					vector.multiply(forward, toolmeta.look_depth-1)),
				vector.multiply(right, look_diameter-1)),
			vector.multiply(up, look_diameter-1))
		add_resourcearea(user, ResourceArea.Create(start_pos, MinMaxArea.Create(base_pos, max), toolmeta.target))
	end
end

-- TODO: should use technic:prospector instead here
minetest.register_craftitem("zones:scanner", {
	description = "Mark resource area",
	inventory_image = "default_tool_steelpick.png^zones_frame_yellow.png",
	on_use = toggle_scan,
	on_secondary_use = toggle_scan,
	on_place = scan

})


-- hook into the technic prospector to get the information as zone
if minetest.get_modpath("technic") then
	minetest.override_item("technic:prospector", {
		on_use = scan
	})
end
