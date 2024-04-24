local mod = get_mod("for_the_drip")

local UIProfileSpawner = require("scripts/managers/ui/ui_profile_spawner")
local UIWeaponSpawner = require("scripts/managers/ui/ui_weapon_spawner")
local PlayerUnitVisualLoadoutExtension = require("scripts/extension_systems/visual_loadout/player_unit_visual_loadout_extension")
local FixedFrame = require("scripts/utilities/fixed_frame")
local MasterItems = require("scripts/backend/master_items")
local ItemPackage = require("scripts/foundation/managers/package/utilities/item_package")
local ItemMaterialOverrides = require("scripts/settings/equipment/item_material_overrides/item_material_overrides")
local VisualLoadoutCustomization = require("scripts/extension_systems/visual_loadout/utilities/visual_loadout_customization")


mod:hook(CLASS.PlayerUnitVisualLoadoutExtension, "server_correction_occurred", function(func, self, unit, from_frame)
	self._equipment_component._is_player = true

	local UNEQUIPPED_SLOT = self.UNEQUIPPED_SLOT
	local rewield = false
	local wieldable_slot_components = self._wieldable_slot_components
	local inventory_component = self._inventory_component
	local equipment = self._equipment
	local self_fx_sources = self._fx_sources
	local fx_extension = self._fx_extension
	local mispredicted_frame = from_frame - 1
	local mispredicted_frame_t = mispredicted_frame * self._fixed_time_step
	local from_server_correction_occurred = true
	local slot_configuration = self._slot_configuration

	for slot_name, config in pairs(slot_configuration) do
		local slot = equipment[slot_name]
		local equipped = slot.equipped
		local item_name = equipped and slot.item.name
		local local_item = item_name or UNEQUIPPED_SLOT
		local wieldable_slot_component = wieldable_slot_components[slot_name]
		local server_auth_item = inventory_component[slot_name]

		if server_auth_item ~= local_item then
			local is_locally_wielded_slot = slot_name == self._locally_wielded_slot
			local keep_equipped = false

			if slot_name == "slot_body_torso" and mod:show_body_slot(self) then
				keep_equipped = true
			elseif slot_name == "slot_body_legs" and mod:show_legs_slot(self) then
				keep_equipped = true
			elseif slot_name == "slot_body_arms" and mod:show_arms_slot(self) then
				keep_equipped = true
			end

			if local_item ~= UNEQUIPPED_SLOT and keep_equipped == false then
				if is_locally_wielded_slot then
					self:_unwield_slot(self._locally_wielded_slot)
				end

				local fx_sources = self_fx_sources[slot_name]

				if fx_sources then
					for _, source_name in pairs(fx_sources) do
						fx_extension:stop_looping_wwise_events_for_source_on_mispredict(source_name)
					end
				end

				self:_unequip_item_from_slot(slot_name, from_server_correction_occurred, from_frame, false)
			elseif is_locally_wielded_slot then
				rewield = true
			end

			if server_auth_item ~= UNEQUIPPED_SLOT then
				local profile_item = config.profile_field
				local item = nil

				if profile_item then
					local player = self._player
					local profile = player:profile()
					local visual_loadout = profile.visual_loadout
					item = visual_loadout[slot_name]
				end

				if not item then
					item = self._item_definitions[server_auth_item]
				end

				if slot.item then
					self:_unequip_item_from_slot(slot_name, from_server_correction_occurred, from_frame, false)
				end

				local optional_existing_unit_3p = config.use_existing_unit_3p and wieldable_slot_component.existing_unit_3p

				mod:load_item_packages(item, function()
					self:_equip_item_to_slot(item, slot_name, mispredicted_frame_t, optional_existing_unit_3p, from_server_correction_occurred)
				end)
			end
		end
	end

	local wielded_slot = inventory_component.wielded_slot
	local locally_wielded_slot = self._locally_wielded_slot

	if wielded_slot ~= "none" and (locally_wielded_slot ~= wielded_slot or rewield) then
		if self._locally_wielded_slot then
			self:_unwield_slot(locally_wielded_slot)
		end

		self:_wield_slot(wielded_slot)
	end
end)


mod:hook(CLASS.MispredictPackageHandler, "destroy", function(func, self)
	for fixed_frame, items in pairs(self._pending_unloads) do
		for i = 1, #items do
			local item = items[i]

			if item then
				self:_unload_item_packages(item)
			end
		end
	end

	self._pending_unloads = nil
	self._loaded_packages = nil
end)

mod:hook(CLASS.MispredictPackageHandler, "item_unequipped", function(func, self,  item, fixed_frame)
	if item then
		func(self, item, fixed_frame or FixedFrame.get_latest_fixed_time() or 1)
	end
end)

mod:hook(CLASS.MispredictPackageHandler, "_unload_item_packages", function(func, self, item)
	if not item then
		return
	end

	local mission = self._mission
	local dependencies = ItemPackage.compile_item_instance_dependencies(item, self._item_definitions, nil, mission)

	for package_name, _ in pairs(dependencies) do
		local loaded_packages = self._loaded_packages[package_name]

		if loaded_packages then
			local load_id = table.remove(loaded_packages, #loaded_packages)

			Managers.package:release(load_id)

			if table.is_empty(loaded_packages) then
				self._loaded_packages[package_name] = nil
			end
		end
	end
end)

mod:hook(CLASS.PlayerUnitVisualLoadoutExtension, "_equip_item_to_slot", function (func, self, item, slot_name, t, optional_existing_unit_3p, from_server_correction_occurred)
	-- solo play bots have 2-4 as id
	-- skip changes for them
	if tonumber(self._player:character_id()) then
		func(self, item, slot_name, t, optional_existing_unit_3p, from_server_correction_occurred)
		return
	end

	mod:load_extra_packages_if_needed(item)

	local custom_item = mod:make_custom_item(slot_name, item, "_equip_item_to_slot")

	self._equipment_component._is_player = true

	func(self, custom_item, slot_name, t, optional_existing_unit_3p, from_server_correction_occurred)

	local loadout = self._player:profile().loadout

	if slot_name == "slot_gear_upperbody" then
		if mod:show_arms_slot(self) then
			if not self._equipment["slot_body_arms"].item then
				local body_item = mod:prepare_body_slot_item(loadout, "slot_body_arms")

				mod:load_item_packages(body_item, function()
					func(self, body_item, "slot_body_arms", t, optional_existing_unit_3p, from_server_correction_occurred)
				end)
			end
		end
		if mod:show_body_slot(self) then
			if not self._equipment["slot_body_torso"].item then
				local body_item = mod:prepare_body_slot_item(loadout, "slot_body_torso")

				mod:load_item_packages(body_item, function()
					func(self, body_item, "slot_body_torso", t, optional_existing_unit_3p, from_server_correction_occurred)
				end)
			end
		end
	elseif slot_name == "slot_gear_lowerbody" and mod:show_legs_slot(self) and not self._equipment["slot_body_legs"].item then
		local body_item = mod:prepare_body_slot_item(loadout, "slot_body_legs")

		mod:load_item_packages(body_item, function()
			func(self, body_item, "slot_body_legs", t, optional_existing_unit_3p, from_server_correction_occurred)
		end)
	end
end)

mod:hook_safe(CLASS.PlayerUnitVisualLoadoutExtension, "wield_slot", function (self, slot_name)
	mod:apply_customization_to_back_weapons(self._unit, slot_name)
end)

-- weapon preview miniature
mod:hook_safe(CLASS.UIWeaponSpawner, "_spawn_weapon", function(self, item, link_unit_name, loader, position, rotation, scale, force_highest_mip, ...)
	local type = item.item_type

	if type == "WEAPON_RANGED" then
		mod.apply_custom_material_override(self._weapon_spawn_data.link_unit, mod.current_slots_data.slot_secondary)
	elseif type == "WEAPON_MELEE" then
		mod.apply_custom_material_override(self._weapon_spawn_data.link_unit, mod.current_slots_data.slot_primary)
	end
end)


-- check if it can affect other players ? (when changing loadout)
mod:hook(CLASS.UIProfileSpawner, "_equip_item_for_spawn_character", function (func, self, slot_id, item)
	if item then
		local custom_item = mod:make_custom_item(slot_id, item, "_equip_item_for_spawn_character")

		mod:load_extra_packages_if_needed(custom_item, function()
			if slot_id == "slot_gear_head" then
				mod:persistent_table("data").head_gear_name = custom_item.name
			end

			local character_spawn_data = self._character_spawn_data
			local loading_profile_data = self._loading_profile_data
			local use_loader_version = loading_profile_data ~= nil
			local profile_loader = use_loader_version and loading_profile_data.profile_loader or character_spawn_data.profile_loader
			local profile = use_loader_version and loading_profile_data.profile or character_spawn_data.profile
			local loadout = profile.loadout

			-- update the loadout item otherwise the game will spam re-equip the original item
			loadout[slot_id] = custom_item
			func(self, slot_id, custom_item)

			if slot_id == "slot_primary" or slot_id == "slot_secondary" then
				local player = Managers.player:local_player_safe(1)
				mod:apply_customization_to_back_weapons(self, player.player_unit, slot_id)
			end
		end)
	else -- pass it on in case it's needed somewhere
		func(self, slot_id, item)
	end
end)

mod:hook(CLASS.UICharacterProfilePackageLoader, "load_profile", function (func, self, profile)
	local id = profile.character_id
	local player = Managers.player:local_player_safe(1)

	if id and player and id == player:character_id() then
		-- load new character preset
		if mod:persistent_table("data").character_id ~= id then
			mod:persistent_table("data").character_id = id
			mod:load_current_character_loadout()
		end

		local loadout = profile.loadout

		loadout["slot_gear_head"] = mod:make_custom_item("slot_gear_head", loadout["slot_gear_head"])
		loadout["slot_gear_upperbody"] = mod:make_custom_item("slot_gear_upperbody", loadout["slot_gear_upperbody"])
		loadout["slot_gear_lowerbody"] = mod:make_custom_item("slot_gear_lowerbody", loadout["slot_gear_lowerbody"])
		loadout["slot_gear_extra_cosmetic"] = mod:make_custom_item("slot_gear_head", loadout["slot_gear_extra_cosmetic"])
		loadout["slot_primary"] = mod:make_custom_item("slot_primary", loadout["slot_primary"])
		loadout["slot_secondary"] = mod:make_custom_item("slot_secondary", loadout["slot_secondary"])

		local archetype = profile.archetype
		local archetype_name = archetype and archetype.name
		local breed_name = archetype and archetype.breed or profile.breed

		mod:persistent_table("data").breed = breed_name
		mod:persistent_table("data").gender = profile.gender
	end

	return func(self, profile)
end)


mod:hook(CLASS.UIProfileSpawner, "_spawn_character_profile", function(func, self, profile, profile_loader, position, rotation, scale, state_machine, animation_event, face_state_machine_key, face_animation_event, force_highest_mip, disable_hair_state_machine, optional_unit_3p, optional_ignore_state_machine)
	local id = profile.character_id

	func(self, profile, profile_loader, position, rotation, scale, state_machine, animation_event, face_state_machine_key, face_animation_event, force_highest_mip, disable_hair_state_machine, optional_unit_3p, optional_ignore_state_machine)

	if id then
		local player = Managers.player:local_player_safe(1)

		if player and id == player:character_id() then
			mod:persistent_table("data").character_id = id

			-- show customization on weapons
			mod:apply_customization_to_back_weapons(self, player.player_unit, "slot_primary")
			mod:apply_customization_to_back_weapons(self, player.player_unit, "slot_secondary")
		end
	end
end)

mod:hook_safe(CLASS.LevelLoader, "_level_load_done_callback", function(self, item_definitions, ...)
	if self._level_name then
		mod:persistent_table("data").level_name = self._level_name
	end
end)

mod.on_game_state_changed = function(status, state_name)
	if state_name == "StateMainMenu" then
		if status == "enter" then
			mod:persistent_table("data").outside_main_screen = false
		else
			mod:persistent_table("data").outside_main_screen = true
		end
	end
end


mod:hook_safe(CLASS.CosmeticsVendorView, "on_enter", function(self)
	-- todo: allow preview when equipped on character
	mod:hook_disable(CLASS.UIWeaponSpawner, "_spawn_weapon")
	mod:hook_disable(CLASS.UIProfileSpawner, "_equip_item_for_spawn_character")

	mod:hook_disable(CLASS.UIProfileSpawner, "_spawn_character_profile")
end)

mod:hook_safe(CLASS.CosmeticsVendorView, "on_exit", function(self)
	mod:hook_enable(CLASS.UIWeaponSpawner, "_spawn_weapon")
	mod:hook_enable(CLASS.UIProfileSpawner, "_equip_item_for_spawn_character")

	mod:hook_enable(CLASS.UIProfileSpawner, "_spawn_character_profile")
end)

mod:hook_safe(CLASS.StoreItemDetailView, "on_enter", function(self)
	-- todo: allow preview when equipped on character
	mod:hook_disable(CLASS.UIWeaponSpawner, "_spawn_weapon")
	mod:hook_disable(CLASS.UIProfileSpawner, "_equip_item_for_spawn_character")

	mod:hook_disable(CLASS.UIProfileSpawner, "_spawn_character_profile")
end)

mod:hook_safe(CLASS.StoreItemDetailView, "on_exit", function(self)
	mod:hook_enable(CLASS.UIWeaponSpawner, "_spawn_weapon")
	mod:hook_enable(CLASS.UIProfileSpawner, "_equip_item_for_spawn_character")

	mod:hook_enable(CLASS.UIProfileSpawner, "_spawn_character_profile")
end)

mod:hook_safe(CLASS.StoreView, "on_enter", function(self)
	-- todo: allow preview when equipped on character
	mod:hook_disable(CLASS.UIWeaponSpawner, "_spawn_weapon")
	mod:hook_disable(CLASS.UIProfileSpawner, "_equip_item_for_spawn_character")

	mod:hook_disable(CLASS.UIProfileSpawner, "_spawn_character_profile")
end)

mod:hook_safe(CLASS.StoreView, "on_exit", function(self)
	mod:hook_enable(CLASS.UIWeaponSpawner, "_spawn_weapon")
	mod:hook_enable(CLASS.UIProfileSpawner, "_equip_item_for_spawn_character")

	mod:hook_enable(CLASS.UIProfileSpawner, "_spawn_character_profile")
end)

local ItemSlotSettings = require("scripts/settings/item/item_slot_settings")

mod:hook_require("scripts/settings/item/item_slot_settings", function(instance)
	instance.slot_body_face.slot_dependencies =
	{
		"slot_body_face_tattoo",
		"slot_body_face_scar",
		"slot_body_face_hair",
		"slot_body_face_implant",
		"slot_body_eye_color",
		"slot_body_skin_color",
		"slot_body_hair_color",
		"slot_body_hair"
	}
end)

mod:hook_require("scripts/settings/player_character/player_character_constants", function(instance)
	instance.slot_configuration.slot_body_face.slot_dependencies =
	{
		"slot_body_face_tattoo",
		"slot_body_face_scar",
		"slot_body_face_hair",
		"slot_body_eye_color",
		"slot_body_skin_color",
		"slot_body_hair_color",
		"slot_body_hair"
	}
end)
