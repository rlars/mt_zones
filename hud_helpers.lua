-- HUD stuff and marker entities

-- first_person_offset from API is 0...
local FIRST_PERSON_EYE_OFFSET = vector.new(0, 1.5, 0)

Hud = {}

function Hud:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
	o._registered_points = {}
	o._update_last_player_pos = vector.new(-100000000000, -100000000000, -100000000000)
	o._hovered_point = nil
    return o
end

HudPoint = {}

-- shape must be one of "circle", "square"; default is "circle"
-- events is optional, if not nil must be table containing on_select and on_unselect functions
function HudPoint.new(pos, image, shape, events, data)
	return {
		pos = pos,
		hud_id = nil,
		-- cached distance to player
		cached_distance = nil,
		image = image,
		shape = shape or "circle",
		events = events
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
		local min_similarity = 0.99
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


local function get_default_background_image(shape)
	if shape == "square" then return "zones_frame_bg.png" end
	return "background_unselected.png"
end

local function get_hovered_background_image(shape)
	if shape == "square" then return "zones_frame_bg_selected.png^zones_frame_blue.png" end
	return "background_selected.png"
end


local function add_new_hud_point(player, hud_point)
	local hud_id = player:hud_add {
		hud_elem_type = "image_waypoint",
		scale={x=1,y=1},
		text = get_default_background_image(hud_point.shape) .."^" .. hud_point.image,
		world_pos = hud_point.pos,
		z_index = -300,
	}
	hud_point.hud_id = hud_id
end



-- update one point image
local function update_single_point_image(player, hud_point)
	player:hud_change(hud_point.hud_id, "text", hud_point.image)
end

-- update one point world_pos
local function update_single_point_pos(player, hud_point)
	player:hud_change(hud_point.hud_id, "world_pos", hud_point.pos)
end

-- update one point relative index as z_index
local function update_single_point_relative_index(player, hud_point, new_z)
	player:hud_change(hud_point.hud_id, "z_index", -300 - new_z)
end

-- update one point scale
local function update_single_point_scale(player, hud_point)
	local new_scale = 3 - math.log(hud_point.cached_distance) / 2
	player:hud_change(hud_point.hud_id, "scale", { x = new_scale, y = new_scale })
end

-- hud_points is a list of [HudPoint]s
function Hud:add_hud_points(player, hud_points)
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

-- info must be a table containing pos, text, color or nil to clear
function Hud:show_additional_information(player, info)
	if info then
		local hud_id = player:hud_add {
			hud_elem_type = "text",
			scale={x=10,y=3},
			text = info.text,
			--world_pos = info.pos,
			position = {x=0.5,y=0.65},
			z_index = -150,
			--offset = {x=0,y=0},
			style = 4,
			size = {x=2,y=2},
			number = info.color
		}
		self.additional_info_id = hud_id
	elseif self.additional_info_id then
		player:hud_remove(self.additional_info_id)
		self.additional_info_id = nil
	end
end


-- remove all points
function Hud.remove_all(self, player)
	for _, hud_point in ipairs(self._registered_points) do
		player:hud_remove(hud_point.hud_id)
	end
	self._registered_points = {}
end

-- remove given points
function Hud:remove(player, points)
	if not points then return end
	local hashed_points = {}
	for _, hud_point in ipairs(points) do
		player:hud_remove(hud_point.hud_id)
		hashed_points[hud_point] = hud_point
	end
	local i = 1
	while i <= #self._registered_points do
		if hashed_points[self._registered_points[i]] then
			table.remove(self._registered_points, i)
		else
			i = i + 1
		end
	end
end

function Hud:update_hud(player, force)
	-- nothing to update if player did not move
	if force or vector.distance(self._update_last_player_pos, player:get_pos()) > 1 then
		update_distances(get_player_eye_pos(player), self._registered_points)
		order_positions_by_distance(self._registered_points)
		for i, hud_point in ipairs(self._registered_points) do
			update_single_point_pos(player, hud_point)
			update_single_point_relative_index(player, hud_point, i)
			update_single_point_scale(player, hud_point)
		end
		self._update_last_player_pos = player:get_pos()
	end
	
	local selected_point = trace_player_view(player, self._registered_points)

	if self._selected_point == selected_point then return end

	if self._selected_point then
		player:hud_change(self._selected_point.hud_id, "text", get_default_background_image(self._selected_point.shape) .. "^" .. self._selected_point.image)
		if self._selected_point.events then self._selected_point.events.on_unselect(self._selected_point, player) end
	end
	
	if selected_point then
		player:hud_change(selected_point.hud_id, "text", get_hovered_background_image(selected_point.shape) .. "^" .. selected_point.image)
		if selected_point.events then selected_point.events.on_select(selected_point, player) end
	end
	self._selected_point = selected_point
end

function Hud:get_selected_point()
	return self._selected_point
end
