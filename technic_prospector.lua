-- mostly copied from technic:prospector, except the part where the zone is created

local function get_metadata(toolstack)
	local m = minetest.deserialize(toolstack:get_metadata())
	if not m then m = {} end
	if not m.charge then m.charge = 0 end
	if not m.target then m.target = "" end
	if not m.look_depth then m.look_depth = 7 end
	if not m.look_radius then m.look_radius = 1 end
	return m
end

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


minetest.override_item("technic:prospector", {
    on_use = scan
})
