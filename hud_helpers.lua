-- HUD stuff and marker entities

-- first_person_offset from API is 0...
local FIRST_PERSON_EYE_OFFSET = vector.new(0, 1.5, 0)

Hud = {}
function Hud.Create()
	return {
		_registered_points = {},
		_update_last_player_pos = vector.new(-100000000000, -100000000000, -100000000000),
		_hovered_point = nil,
	}
end

HudPoint = {}
function HudPoint.Create(pos, image)
	return {
		pos = pos,
		hud_id = nil,
		-- cached distance to player
		cached_distance = nil,
		image = image
	}
end


local function get_player_eye_pos(player)
	local first_person_eye_offset = FIRST_PERSON_EYE_OFFSET
	return vector.add(player:get_pos(), first_person_eye_offset)
end


local function update_distances(center, hud_points)
	for _, hud_point in ipairs(hud_points) do
		hud_point.cached_distance = vector.distance(center, hud_point.pos)
	end
end


-- orders points by their current cached distance
local function order_positions_by_distance(positions)
	table.sort(positions, function(a, b) return a.cached_distance < b.cached_distance end)
end


-- for vectors p, q, v, w find scalars r, s so that p + r*v - (q + s*w) takes the smallest value possible
local function min_distance_lines(p, v, q, w)
	local a = vector.dot(v, v)
	local b = vector.dot(v, w)
	local c = vector.dot(v, vector.subtract(q, p))
	local d = vector.dot(v, w)
	local e = vector.dot(w, w)
	local f = vector.dot(w, vector.subtract(q, p))
	return (b*f-c*e)/(b*d-a*e),(a*f-c*d)/(b*d-a*e)
end

-- for vectors p, q, v, w find scalars r, s so that p + r*v - (q + s*w) takes the smallest value possible
-- return p + r*v, q + s*w
local function closest_points_on_lines(p, v, q, w)
	local r, s = min_distance_lines(p, v, q, w)
	return vector.add( p, vector.multiply(v, r) ), vector.add( q, vector.multiply(w, s) )
end


-- check which position the player could look at currently
local function trace_player_view(player, hud_points)
	if hud_points then
		local selected_point = nil
		local first_person_eye_offset, third_person_offset = player:get_eye_offset()
		first_person_eye_offset = FIRST_PERSON_EYE_OFFSET
		local eye_pos = vector.add(player:get_pos(), first_person_eye_offset)
		local look_dir = player:get_look_dir()
		local min_similarity = 0.98
		for _, hud_point in ipairs(hud_points) do
			local point_dir = vector.normalize(vector.subtract(hud_point.pos, eye_pos))
			local similarity = vector.dot(look_dir, point_dir)
			if similarity > min_similarity then
				selected_point = hud_point
				min_similarity = similarity
			end
		end
		return selected_point
	end
end

local function length_2d(v)
	return math.sqrt(v.x * v.x + v.z * v.z)
end



local function add_new_hud_point(player, hud_point)
	local hud_id = player:hud_add {
		hud_elem_type = "image_waypoint",
		scale={x=1,y=1},
		text = hud_point.image,
		world_pos = hud_point.pos,
		z_index = -300,
	}
	hud_point.hud_id = hud_id
end



-- update one point image
local function update_single_point_image(player, hud_point)
	player:hud_change(hud_point.hud_id, "text", hud_point.image)
end

-- update one point relative index as z_index
local function update_single_point_relative_index(player, hud_point, new_z)
	player:hud_change(hud_point.hud_id, "z_index", -300 - new_z)
end

-- update one point z_index
local function update_single_point_scale(player, hud_point)
	local new_scale = 3 - math.log(hud_point.cached_distance) / 2
	player:hud_change(hud_point.hud_id, "scale", { x = new_scale, y = new_scale })
end

-- hud_points is a table with values { pos = vector, image = "image" }
function Hud.add_hud_points(self, player, hud_points)
	for _, hud_point in ipairs(hud_points) do
		table.insert(self._registered_points, hud_point)
	end
	update_distances(get_player_eye_pos(player), self._registered_points)
	order_positions_by_distance(self._registered_points)
	for i, hud_point in ipairs(self._registered_points) do
		if not hud_point.hud_id then
			add_new_hud_point(player, hud_point)
		end
		update_single_point_relative_index(player, hud_point, i)
		update_single_point_scale(player, hud_point)
	end
end


function Hud.remove_all(self, player)
	for _, hud_point in ipairs(self._registered_points) do
		player:hud_remove(hud_point.hud_id)
	end
	self._registered_points = {}
end


function Hud.update_hud(self, player, force)
	-- nothing to update if player did not move
	if force or vector.distance(self._update_last_player_pos, player:get_pos()) > 1 then
		update_distances(get_player_eye_pos(player), self._registered_points)
		order_positions_by_distance(self._registered_points)
		for i, hud_point in ipairs(self._registered_points) do
			update_single_point_relative_index(player, hud_point, i)
			update_single_point_scale(player, hud_point)
		end
		self._update_last_player_pos = player:get_pos()
	end
	
	local selected_point = trace_player_view(player, self._registered_points)

	if self._selected_point then
		self._selected_point.image = self._selected_point.old_image
		player:hud_change(self._selected_point.hud_id, "text", self._selected_point.image)
	end
	
	if selected_point then
		selected_point.old_image = selected_point.image
		player:hud_change(selected_point.hud_id, "text", selected_point.image .. "^[brighten")
	end
	self._selected_point = selected_point
end

local function remove_hud_points(player, hud_points)
	for _, hud_point in ipairs(hud_points) do
		player:hud_remove(hud_point.hud_id)
	end
end
