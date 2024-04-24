local mod = get_mod("for_the_drip")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets =
		{
			{
				setting_id = "toggle_editor",
				type = "keybind",
				default_value = {},
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "toggle_ui",
			},
			{
				setting_id    = "apply_mat_on_index_change",
				type          = "checkbox",
				default_value = false,
			},
			{
				setting_id = "save_current_preset",
				type = "keybind",
				default_value = {},
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "save_current_look",
			},
			{
				setting_id = "reset_window_position",
				type = "keybind",
				default_value = {},
				keybind_trigger = "pressed",
				keybind_type = "function_call",
				function_name = "reset_window_pos",
			},
		},
	},
}
