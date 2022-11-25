
zones_path = minetest.get_modpath("zones")

dofile(zones_path.."/datastore.lua");

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
	local player_store = user:get_meta()
	local hud_ids = datastore.get_or_create_table(user, "dropmarker_hud_ids")
	local areas = minetest.deserialize(player_store:get_string("dropmarker_areas"))
	if show and areas then
		for i, area in ipairs(areas) do
			-- TODO: eventually reuse hud
			if i <= #hud_ids then
				user:hud_remove(hud_ids[i])
			end
			hud_ids[i] = user:hud_add{
				hud_elem_type = "image_waypoint",
				scale={x=2,y=2},
				name = "dropmarkers_area_" .. tostring(i),
				text = "zones_frame_bg.png^zones_dropsite.png^zones_frame_blue.png^[noalpha",
				world_pos = vector.multiply(vector.add(area.min, area.max), 0.5),
				z_index = -300,
			}
		end
	else
		for _, hud_id in ipairs(hud_ids) do
			user:hud_remove(hud_id)
		end
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


local function update_resourceareas_hud(user, show)
	local player_store = user:get_meta()
	local hud_ids = datastore.get_or_create_table(user, "resourcearea_hud_ids")
	local areas = minetest.deserialize(player_store:get_string("resource_areas"))
	if show and areas then
		for i, area in ipairs(areas) do
			-- TODO: eventually reuse hud
			if i <= #hud_ids then
				user:hud_remove(hud_ids[i])
			end
			local node = minetest.registered_nodes[area.type]
			
			local fixed_name = string.gsub(node.tiles[1], "[\\^]", "&")
			
			hud_ids[i] = user:hud_add{
				hud_elem_type = "image_waypoint",
				scale={x=2,y=2},
				name = "resource_area_" .. tostring(i),
				text = "[inventorycube{" .. fixed_name .. "{" .. fixed_name .. "{" .. fixed_name .. "^[resize:32x32^zones_frame_yellow.png",
				world_pos = area.start,
				z_index = -300,
			}
		end
	else
		for _, hud_id in ipairs(hud_ids) do
			user:hud_remove(hud_id)
		end
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

-- TODO: mostly copied from technic:prospector
local function scan(_, user, pointed_thing)
	local start_pos = pointed_thing.under
	local forward = minetest.facedir_to_dir(minetest.dir_to_facedir(user:get_look_dir(), true))
	local right = forward.x ~= 0 and { x=0, y=1, z=0 } or (forward.y ~= 0 and { x=0, y=0, z=1 } or { x=1, y=0, z=0 })
	local up = forward.x ~= 0 and { x=0, y=0, z=1 } or (forward.y ~= 0 and { x=1, y=0, z=0 } or { x=0, y=1, z=0 })
	local found = false
	local look_depth = 21
	local look_radius = 2
	local look_diameter = 5
	local base_pos = vector.add(start_pos, vector.multiply(vector.add(right, up), - look_radius))
	for f = 0, look_depth-1 do
		for r = 0, look_diameter-1 do
			for u = 0, look_diameter-1 do
				local node_name = minetest.get_node(
						vector.add(
							vector.add(
								vector.add(base_pos,
									vector.multiply(forward, f)),
								vector.multiply(right, r)),
							vector.multiply(up, u))
						).name
					if node_name == "moonrealm:ironore" then
						found = true
					break
				end
			end
			if found then break end
		end
		if found then break end
	end
	if found then
		local max = vector.add(
			vector.add(
				vector.add(base_pos,
					vector.multiply(forward, look_depth-1)),
				vector.multiply(right, look_diameter-1)),
			vector.multiply(up, look_diameter-1))
		add_resourcearea(user, ResourceArea.Create(start_pos, MinMaxArea.Create(base_pos, max), "moonrealm:ironore"))
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
