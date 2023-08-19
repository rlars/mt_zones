-- stores volatile data for each connected player (data that is not written to PlayerMetaRef)

datastore = {
	_data = {}
}

function datastore.get_playernames()
	local player_names = {}
	for player_name, _ in pairs(datastore._data) do
		table.insert(player_names, player_name)
	end
	return player_names
end

-- returns write-accessible data for specified player
-- if there is none, it will be created
function datastore.get_data(player)
	local player_name = player:get_player_name()
	if not datastore._data[player_name] then
		datastore._data[player_name] =
		{
		}
	end
	return datastore._data[player_name]
end

function datastore.get_table(player, tablename)
    local player_data = datastore.get_data(player)
	if not player_data[tablename] then
		minetest.log("error", "[datastore] Table " .. tostring(tablename) .. " does not exist for player " .. player:get_player_name())
        return {}
    end
    return player_data[tablename]
end

function datastore.get_or_create_table(player, tablename)
    local player_data = datastore.get_data(player)
	if not player_data[tablename] then
        player_data[tablename] = {}
    end
    return player_data[tablename]
end

function datastore.set_table(player, tablename, table)
    local player_data = datastore.get_data(player)
	player_data[tablename] = table
end

function datastore.remove_player(player)
	datastore._data[player:get_player_name()] = nil
end

minetest.register_on_leaveplayer(
    function (player, timed_out)
        datastore.remove_player(player:get_player_name())
    end
)

