return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`for_the_drip` encountered an error loading the Darktide Mod Framework.")

		new_mod("for_the_drip", {
			mod_script       = "for_the_drip/scripts/mods/for_the_drip/for_the_drip",
			mod_data         = "for_the_drip/scripts/mods/for_the_drip/for_the_drip_data",
			mod_localization = "for_the_drip/scripts/mods/for_the_drip/for_the_drip_localization",
		})
	end,
	load_after = {
		"weapon_customization",
	},
	load_before = {
		"for_the_drip_extra",
	},
	packages = {},
}
