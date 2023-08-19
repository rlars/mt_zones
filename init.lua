
zones_path = minetest.get_modpath("zones")

dofile(zones_path.."/hud_helpers.lua");
dofile(zones_path.."/global_step_callback.lua");
dofile(zones_path.."/datastore.lua");

GlobalStepCallback.register_globalstep_per_player("update_hud", function (player, dtime)
	local hud = datastore.get_table(player, "hud")
	if hud then
		hud:update_hud(player)
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


local function on_select_droparea(hud_point, player)
	hud_point.drawn_shape = vizlib.draw_area(vector.add(hud_point.area.min, vector.new(-.6, -.6, -.6)),
											 vector.add(hud_point.area.max, vector.new(.6, .6, .6)),
											 {player = player, color = "#0000ff", infinite = true})
	local hud = datastore.get_table(player, "hud")
	hud:show_additional_information(player, {pos = vector.multiply(vector.add(hud_point.area.min, hud_point.area.max), 0.5), text = hud_point.area.name, color = "0x0000ff"})
end
local function on_unselect_droparea(hud_point, player)
	vizlib.erase_shape(hud_point.drawn_shape)
	hud_point.drawn_shape = nil
	local hud = datastore.get_table(player, "hud")
	hud:show_additional_information(player, nil)
end

local function update_dropmarker_hud(user, show)
	local hud = datastore.get_table(user, "hud")
	local player_store = user:get_meta()
	local hud_ids = datastore.get_or_create_table(user, "dropmarker_hud_ids")
	local areas = minetest.deserialize(player_store:get_string("dropmarker_areas"))
	if show and areas then
		local new_points = {}
		for i, area in ipairs(areas) do
			local area_center = vector.multiply(vector.add(area.min, area.max), 0.5)
			local image = "zones_dropsite.png"
			local new_point = HudPoint.new(area_center, image, "square", {on_select = on_select_droparea, on_unselect = on_unselect_droparea})
			new_point.area = area
			table.insert(new_points, new_point)
		end
		hud:add_hud_points(user, new_points)
		hud.dropmarker_areas = new_points
	else
		hud:remove(user, hud.dropmarker_areas)
		hud.dropmarker_areas = {}
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
local function find_droparea(user, name)
	local player_store = user:get_meta()
	local areas = minetest.deserialize(player_store:get_string("dropmarker_areas"))
	for index, area in ipairs(areas) do
		if area.name == name then return index end
		if (area.name == nil or area.name == "") and (name == nil or name == "") then return index end
	end
end
local function delete_droparea(user, index)
	local player_store = user:get_meta()
	local areas = minetest.deserialize(player_store:get_string("dropmarker_areas"))
	if not areas then areas = {} end
	table.remove(areas, index)
	player_store:set_string("dropmarker_areas", minetest.serialize(areas))
end

local function on_zone_formspec_received(player, formname, fields)
	minetest.debug(dump(formname))
	minetest.debug(dump(fields))
	if string.find(formname, "zones:edit_zone_") then
		local zone_name = string.sub(formname, string.len("zones:edit_zone_") + 1)
		if fields.delete then
			local zone_index = find_droparea(player, zone_name)
			while zone_index do
				delete_droparea(player, zone_index)
				zone_index = find_droparea(player, zone_name)
			end
		end
	end
end

minetest.register_on_player_receive_fields(on_zone_formspec_received)

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

local function is_name_in_list(list, name)
	for _, entry in ipairs(list) do
		if entry.name == name then return true end
	end
	return false
end

local function get_next_free_name(list, prefix)
	i = 0
	while i < 16384 do
		local name = prefix .. string.format("%X", i)
		if not is_name_in_list(list, name) then
			return name
		end
		i = i + 1
	end
	return get_next_free_name(list, prefix .. "X")
end

local function use_dropmarker_tool(_, user, pointed_thing)
	local hud = datastore.get_table(user, "hud")
	local selected_dropsite = hud:get_selected_point()
	if selected_dropsite then
		minetest.show_formspec(user:get_player_name(), "zones:edit_zone_" .. (selected_dropsite.area.name or ""), "formspec_version[2]size[14,8]" ..
			"button_exit[10,6.5;2,1;delete;delete]")
	elseif pointed_thing.type == "node" then
		local target_pos = pointed_thing.above
		local player_store = user:get_meta()
		local dropmarker_start_pos = minetest.deserialize(player_store:get_string("dropmarker_start_pos"))
		if not dropmarker_start_pos then
			player_store:set_string("dropmarker_start_pos", minetest.serialize(target_pos))
			hud.dropmarker_shape = vizlib.draw_square(vector.add(target_pos, vector.new(0, -0.4, 0)), 0.5, "y", {color="#0000ff", infinite=true})
		else
			local area = MinMaxArea.Create(dropmarker_start_pos, target_pos)
			local player_store = user:get_meta()
			area.name = get_next_free_name(minetest.deserialize(player_store:get_string("dropmarker_areas")), "D_")
			add_droparea(user, area)
			player_store:set_string("dropmarker_start_pos", nil)
			vizlib.erase_shape(hud.dropmarker_shape)
			hud.dropmarker_shape = nil
		end
	end
end


minetest.register_craftitem("zones:dropmarker", {
	description = "Drop",
	inventory_image = "zones_frame_bg.png^zones_frame_blue.png^zones_dropsite.png^[noalpha",
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
	local hud = datastore.get_table(user, "hud")
	local player_store = user:get_meta()
	local hud_ids = datastore.get_or_create_table(user, "resourcearea_hud_ids")
	local areas = minetest.deserialize(player_store:get_string("resource_areas"))
	if show and areas then
		local new_points = {}
		for i, area in ipairs(areas) do
			local image = create_inventorycube_image(area.type) .. "^[resize:32x32^zones_frame_yellow.png"
			table.insert(new_points, HudPoint.new(area.start, image)) -- name = "dropmarkers_area_" .. tostring(i), 
		end
		hud:add_hud_points(user, new_points)
		hud.resource_areas = new_points
	else
		hud:remove(user, hud.resource_areas)
		hud.resource_areas = nil
	end
end


local function show_resourceareas_hud(user, do_show)
	local player_store = user:get_meta()
	local state = player_store:get_string("show_resourceareas")
	if do_show then --state == "" or state == "no" then
		player_store:set_string("show_resourceareas", "yes")
		update_resourceareas_hud(user, true)
	else
		player_store:set_string("show_resourceareas", "no")
		update_resourceareas_hud(user, false)
	end
end


-- area given by { min, max }
function add_resourcearea(user, area)
	local player_store = user:get_meta()
	local areas = minetest.deserialize(player_store:get_string("resource_areas"))
	if not areas then areas = {} end
	table.insert(areas, area)
	player_store:set_string("resource_areas", minetest.serialize(areas))
end


-- hook into the technic prospector to get the information as zone
if minetest.get_modpath("technic") then
	dofile(zones_path.."/technic_prospector.lua");
end


minetest.register_on_joinplayer(function(player)
	datastore.set_table(player, "hud", Hud:new())
end
)

local function is_holding_prospector(player, dtime)
	local item = player:get_wielded_item()

	local player_store = player:get_meta()
	local state = player_store:get_string("show_resourceareas")

    if item:get_name() == "technic:prospector" then
		if state == "" or state == "no" then
			show_resourceareas_hud(player, true)
		end
	else
		if state == "yes" then
			show_resourceareas_hud(player, false)
		end
	end
end
GlobalStepCallback.register_globalstep_per_player("is_holding_prospector", is_holding_prospector)
