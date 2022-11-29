-- register a callback triggered for each player
-- keeps references to player ObjectRefs, which is not recommended
-- TODO: create per-player contexts
-- example:


local function check_wielded_item(player, dtime)
	local item = player:get_wielded_item()
    minetest.debug(item:get_name())
end
--GlobalStepCallback.register_globalstep_per_player("check_wielded_item", check_wielded_item)


GlobalStepCallback = {}
GlobalStepCallback.registered_players = {}
GlobalStepCallback.registered_actions = {}

function GlobalStepCallback.on_joinplayer(player, last_login)
    GlobalStepCallback.registered_players[player:get_player_name()] = player
end

function GlobalStepCallback.on_leaveplayer(player, timed_out)
    GlobalStepCallback.registered_players[player:get_player_name()] = nil
end

function GlobalStepCallback.globalstep(dtime)
    for name, action in pairs(GlobalStepCallback.registered_actions) do
        for _, player in pairs(GlobalStepCallback.registered_players) do
            action(player, dtime)
        end
    end
end


-- register a callable table with name property
function GlobalStepCallback.register_globalstep_per_player(action_name, action)
    GlobalStepCallback.registered_actions[action_name] = action
end

-- unregister a callable table with name property
function GlobalStepCallback.unregister_globalstep_per_player(action_name)
    GlobalStepCallback.registered_actions[action_name] = nil
end

minetest.register_on_joinplayer(GlobalStepCallback.on_joinplayer)
minetest.register_on_leaveplayer(GlobalStepCallback.on_leaveplayer)
minetest.register_globalstep(GlobalStepCallback.globalstep)
