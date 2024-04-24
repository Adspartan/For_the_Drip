local mod = get_mod("for_the_drip")

mod.split_str = function(self, str, sep)
	if sep == '' then return {str} end

  local res, from = {}, 1

  repeat
    local pos = str:find(sep, from)
    res[#res + 1] = str:sub(from, pos and pos - 1)
    from = pos and pos + #sep
  until not from

  return res
end

mod.shorten_item_name = function(self, name)
	if not name then
		return "<nil>"
	end

	if name == "" then
		return name
	end

	local t = string.split(name, "/")

	return t[#t]
end


mod.get_visual_loadout_extension = function()
	local player = Managers.player:local_player_safe(1)

	if player then
		return ScriptUnit.extension(player.player_unit, "visual_loadout_system")
	end

	return nil
end
