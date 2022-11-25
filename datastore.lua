-- stores volatile data for each connected player (data that is not written to PlayerMetaRef)

datastore = {
	_data = {}
}

function datastore.get_players()
	local players = {}
	for player, _ in pairs(datastore._data) do
		table.insert(players, player)
	end
	return players
end

-- returns write-accessible data for specified player
-- if there is none, it will be created
function datastore.get_data(player)
	if not datastore._data[player] then
		datastore._data[player] =
		{
		}
	end
	return datastore._data[player]
end

function datastore.get_or_create_table(player, tablename)
    local player_data = datastore.get_data(player)
	if not player_data[tablename] then
        player_data[tablename] = {}
    end
    return player_data[tablename]
end

function datastore.remove_player(player)
	datastore._data[player] = nil
end

minetest.register_on_leaveplayer(
    function (player, timed_out)
        datastore.remove_player(player)
    end
)

