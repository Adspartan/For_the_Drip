local mod = get_mod("for_the_drip")

local UIProfileSpawner = require("scripts/managers/ui/ui_profile_spawner")
local UIWeaponSpawner = require("scripts/managers/ui/ui_weapon_spawner")
local PlayerUnitVisualLoadoutExtension = require("scripts/extension_systems/visual_loadout/player_unit_visual_loadout_extension")
local FixedFrame = require("scripts/utilities/fixed_frame")
local MasterItems = require("scripts/backend/master_items")
local ItemPackage = require("scripts/foundation/managers/package/utilities/item_package")
local ItemMaterialOverrides = require("scripts/settings/equipment/item_material_overrides/item_material_overrides")
local VisualLoadoutCustomization = require("scripts/extension_systems/visual_loadout/utilities/visual_loadout_customization")
local ProfileUtils = require("scripts/utilities/profile_utils")
local Breeds = require("scripts/settings/breed/breeds")
local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")
local ItemSlotSettings = require("scripts/settings/item/item_slot_settings")

mod:hook_require("scripts/settings/ui/ui_settings", function(settings)
  if settings.item_preview_hide_slots_per_slot then
    for _, hidden_slots in pairs(settings.item_preview_hide_slots_per_slot) do
      if type(hidden_slots) == "table" then
        for i = #hidden_slots, 1, -1 do
          if string.find(hidden_slots[i], "^slot_body_") then
            table.remove(hidden_slots, i)
          end
        end
      end
    end
  end
end)

local available_companions = {
	companion_dog = "slot_companion_gear_full",
}
local COMPANION_SLOTS_BY_BREED = {}
local COMPANION_BREED_BY_SLOT = {}
local COMPANION_SLOTS = {}

for breed, main_slot in pairs(available_companions) do
	local slot_depedencies = PlayerCharacterConstants.slot_configuration[main_slot].slot_dependencies

	COMPANION_SLOTS_BY_BREED[breed] = {
		[main_slot] = true,
	}
	COMPANION_BREED_BY_SLOT[main_slot] = breed
	COMPANION_SLOTS[main_slot] = true

	if slot_depedencies then
		for i = 1, #slot_depedencies do
			local slot_depedency = slot_depedencies[i]

			COMPANION_SLOTS_BY_BREED[breed][slot_depedency] = true
			COMPANION_BREED_BY_SLOT[slot_depedency] = breed
			COMPANION_SLOTS[slot_depedency] = true
		end
	end
end


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

        self:_equip_item_to_slot(item, slot_name, mispredicted_frame_t, optional_existing_unit_3p, from_server_correction_occurred)
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

  local custom_item = mod:make_custom_item(slot_name, item, "_equip_item_to_slot")

  mod:load_extra_packages_if_needed(custom_item)

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


mod:hook(CLASS.UIProfileSpawner, "_change_slot_item", function (func, self, slot_id, item, loadout, visual_loadout)
  local character_spawn_data = self._character_spawn_data
  local loading_profile_data = self._loading_profile_data
  local use_loader_version = loading_profile_data ~= nil

  local was_patched = false
  if not use_loader_version and not self._single_item_profile_loader then
    if character_spawn_data and character_spawn_data.profile_loader then
      self._single_item_profile_loader = character_spawn_data.profile_loader
      was_patched = true
    end
  end

  local profile = use_loader_version and loading_profile_data.profile or character_spawn_data.profile

  if profile and profile.character_id == mod:persistent_table("data").character_id
								   and string.contains_any( slot_id
														  , "slot_gear_head", "slot_gear_upperbody", "slot_gear_lowerbody", "slot_gear_extra_cosmetic"
														  , "slot_primary", "slot_secondary", "slot_body_hair_color"
														  , "slot_body_eye_color"  
														  , "slot_body_face_tattoo", "slot_body_torso_tattoo"
														  , "slot_body_arms_tattoo", "slot_body_legs_tattoo") then
																
    local custom_item = mod:make_custom_item(slot_id, item)

    if visual_loadout then
      visual_loadout[slot_id] = custom_item
    end

    loadout[slot_id] = custom_item

    func(self, slot_id, custom_item, loadout, visual_loadout)

    local function _force_show_slot(force_slot)
      local force_item = loadout[force_slot]
      if force_item then
        func(self, force_slot, force_item, loadout, visual_loadout)
      end
    end

    if slot_id == "slot_gear_upperbody" and custom_item then
      local data = mod.current_slots_data.gear_customization_data[custom_item.name]

      if data then
        if data.hide_body == false then
          _force_show_slot("slot_body_torso")
        end

        if data.hide_arms == false then
          _force_show_slot("slot_body_arms")
        end
      end
    elseif slot_id == "slot_gear_lowerbody" and custom_item then
      local data = mod.current_slots_data.gear_customization_data[custom_item.name]

      if data and data.hide_legs == false then
        _force_show_slot("slot_body_legs")
      end
    end
  else
    func(self, slot_id, item, loadout, visual_loadout)
  end

  if was_patched then
    self._single_item_profile_loader = nil
  end
end)

mod:hook_safe(CLASS.PlayerManager, "add_player", function (self, player_class, channel_id, peer_id, local_player_id, profile, slot, account_id, ...)
  local player = Managers.player:local_player_safe(1)

  if player:character_id() ~= mod:persistent_table("data").character_id then
    mod:persistent_table("data").character_id = player:character_id()
    mod:load_current_character_loadout()
  end
end)

mod:hook_safe(CLASS.StateMainMenu, "event_request_select_new_profile", function (self, profile)
  if profile.character_id then
    mod:persistent_table("data").character_id = profile.character_id
    mod:load_character_loadout(profile.character_id, true)
  end
end)

mod:hook(CLASS.UIProfileSpawner, "_spawn_character_profile", function(func, self, profile, profile_loader, position, rotation, scale, state_machine, animation_event, face_state_machine_key, face_animation_event, force_highest_mip, disable_hair_state_machine, optional_unit_3p, optional_ignore_state_machine, companion_data)
	local id = profile.character_id
	if id and id == mod:persistent_table("data").character_id then
		local loadout = profile.loadout

		mod:persistent_table("data").breed = profile.archetype.breed
		mod:persistent_table("data").gender = profile.gender

		loadout["slot_body_torso"] = mod:prepare_body_slot_item(loadout, "slot_body_torso")
		loadout["slot_body_arms"] = mod:prepare_body_slot_item(loadout, "slot_body_arms")
		loadout["slot_body_legs"] = mod:prepare_body_slot_item(loadout, "slot_body_legs")
		loadout["slot_gear_head"] = mod:make_custom_item("slot_gear_head", loadout["slot_gear_head"])

		loadout["slot_body_hair_color"] = mod:make_custom_item("slot_body_hair_color", loadout["slot_body_hair_color"])
		loadout["slot_body_eye_color"] = mod:make_custom_item("slot_body_eye_color", loadout["slot_body_eye_color"])
		local face_item = loadout["slot_body_face"]
		if face_item then
			local head_gear_item = loadout["slot_gear_head"]
			if head_gear_item then
				if not face_item.attachments then
					rawset(face_item, "attachments", {})
				end
				if not face_item.attachments.slot_gear_head then
					rawset(face_item.attachments, "slot_gear_head", {})
				end
				rawset(face_item.attachments.slot_gear_head, "item", head_gear_item)
			end
		end
		loadout["slot_body_face"] = mod:make_custom_item("slot_body_face", face_item)

		loadout["slot_body_face_tattoo"] = mod:make_custom_item("slot_body_face_tattoo", loadout["slot_body_face_tattoo"])
		loadout["slot_body_torso_tattoo"] = mod:make_custom_item("slot_body_torso_tattoo", loadout["slot_body_torso_tattoo"])
		loadout["slot_body_arms_tattoo"]  = mod:make_custom_item("slot_body_arms_tattoo",  loadout["slot_body_arms_tattoo"])
		loadout["slot_body_legs_tattoo"]  = mod:make_custom_item("slot_body_legs_tattoo",  loadout["slot_body_legs_tattoo"])

		loadout["slot_gear_upperbody"] = mod:make_custom_item("slot_gear_upperbody", loadout["slot_gear_upperbody"])
		loadout["slot_gear_lowerbody"] = mod:make_custom_item("slot_gear_lowerbody", loadout["slot_gear_lowerbody"])
		loadout["slot_gear_extra_cosmetic"] = mod:make_custom_item("slot_gear_extra_cosmetic", loadout["slot_gear_extra_cosmetic"])
		loadout["slot_primary"] = mod:make_custom_item("slot_primary", loadout["slot_primary"])
		loadout["slot_secondary"] = mod:make_custom_item("slot_secondary", loadout["slot_secondary"])
	end

	local loadout = profile.loadout

	local visual_loadout = ProfileUtils.generate_visual_loadout(profile.loadout)

	local gear_data = mod.current_slots_data and mod.current_slots_data.gear_customization_data or {}
	local required_body_slots = {
	  slot_body_torso = function()
	    local upper = profile.loadout["slot_gear_upperbody"]
	    if upper and gear_data then
	      local d = gear_data[upper.name]
	      return not (d and d.hide_body)
	    end
	    return true
	  end,
	  slot_body_arms = function()
	    local upper = profile.loadout["slot_gear_upperbody"]
	    if upper and gear_data then
	      local d = gear_data[upper.name]
	      return not (d and d.hide_arms)
	    end
	    return true
	  end,
	  slot_body_legs = function()
	    local lower = profile.loadout["slot_gear_lowerbody"]
	    if lower and gear_data then
	      local d = gear_data[lower.name]
	      return not (d and d.hide_legs)
	    end
	    return true
	  end,
	}

	for slot_name, should_show_fn in pairs(required_body_slots) do
        if should_show_fn() and not visual_loadout[slot_name] then
            visual_loadout[slot_name] = profile.loadout[slot_name]
        end
    end

    if not visual_loadout["slot_body_eye_color"] then
        visual_loadout["slot_body_eye_color"] =
            profile.loadout["slot_body_eye_color"]
    end


	if id and id == mod:persistent_table("data").character_id then
		for slot_id, item in pairs(loadout) do
			if visual_loadout[slot_id] then
				visual_loadout[slot_id] = item
			end
		end
	end

	local archetype = profile.archetype
	local archetype_name = archetype.name
	local breed_name = archetype.breed
	local breed_settings = Breeds[breed_name]
	local base_unit = breed_settings.base_unit
	local companion_unit_3p, companion_position, companion_ignore, companion_state_machine, companion_animation_event, companion_optional_ignore_state_machine, companion_optional_unit_3p
	local companion_attach_to_character = true

	if companion_data then
		companion_optional_unit_3p = companion_data.optional_unit_3p
		companion_unit_3p = companion_data.optional_unit_3p
		companion_position = companion_data.position
		companion_state_machine = companion_data.state_machine
		companion_animation_event = companion_data.animation_event
		companion_optional_ignore_state_machine = companion_data.ignore_state_machine
		companion_ignore = companion_data.ignore

		if companion_data.attach_to_character ~= nil then
			companion_attach_to_character = companion_data.attach_to_character
		end
	end

	position = position or Vector3.zero()
	rotation = rotation or Quaternion.identity()

	local spawn_rotation = rotation

	if self._rotation_angle and self._rotation_angle ~= 0 then
		local character_rotation_angle = Quaternion.axis_angle(Vector3(0, 0, 1), -self._rotation_angle)

		spawn_rotation = Quaternion.multiply(character_rotation_angle, spawn_rotation)
	end

	local unit_3p = optional_unit_3p

	if not unit_3p then
		if scale then
			local pose = Matrix4x4.from_quaternion_position(rotation, position)

			Matrix4x4.set_scale(pose, scale)

			unit_3p = World.spawn_unit_ex(self._world, base_unit, nil, pose)
		else
			unit_3p = World.spawn_unit_ex(self._world, base_unit, nil, position, spawn_rotation)
		end

		if self._character_toggle_state == nil then
			self._character_toggle_state = true
		end
	end

	local equipment_component = EquipmentComponent:new(self._world, self._item_definitions, self._unit_spawner, unit_3p, nil, nil, self._force_highest_lod_step, true)
	local slot_configuration = PlayerCharacterConstants.slot_configuration
	local gear_slots = {}
	local ignored_slots = self._ignored_slots

	for slot_id, config in pairs(slot_configuration) do
		local settings = ItemSlotSettings[slot_id]

		if not ignored_slots[slot_id] and not settings.ignore_character_spawning then
			gear_slots[slot_id] = config
		end
	end

	local slot_options = {
		slot_primary = {
			skip_link_children = false,
		},
		slot_secondary = {
			skip_link_children = true,
		},
	}
	local slots = equipment_component.initialize_equipment(gear_slots, breed_settings, slot_options)
	local slot_equip_order = PlayerCharacterConstants.slot_equip_order
	local equipped_items = {}

	for ii = 1, #slot_equip_order do
		local skip_slot
		local slot_id = slot_equip_order[ii]
		local slot = slots[slot_id]
		local item = loadout[slot_id]
		local visual_item = visual_loadout[slot_id]

		if item then
			equipped_items[slot_id] = item
		end

		local display_item = visual_item

		if slot and display_item then
			if COMPANION_SLOTS[slot.name] then
				if companion_ignore then
					skip_slot = true
				elseif not companion_unit_3p then
					companion_position = companion_position or position

					local breed_name = COMPANION_BREED_BY_SLOT[slot.name]

					companion_unit_3p = self:_spawn_companion(unit_3p, breed_name, companion_position, spawn_rotation, companion_attach_to_character)

					local companion_global_position = self._only_companion and Unit.local_position(unit_3p, 1) or companion_position

					if companion_attach_to_character then
						local companion_attach_index = unit_3p and Unit.has_node(unit_3p, "ap_companion") and Unit.node(unit_3p, "ap_companion")

						if companion_attach_index then
							local companion_global_position = self._only_companion and Unit.local_position(unit_3p, 1) or companion_position
							local companion_local_position = Unit.local_position(unit_3p, 1) - companion_global_position

							Unit.set_local_position(unit_3p, companion_attach_index, companion_local_position)
						end
					else
						Unit.set_local_position(companion_unit_3p, 1, companion_global_position)
					end
				end
			end

			if not skip_slot then
				local gender = profile.gender
				local deform_overrides = {}

				if gender == "female" then
					deform_overrides[#deform_overrides + 1] = "wrap_deform_human_body_female"
				end

				local parent_unit_3p = unit_3p
				local parent_slot_names = display_item.parent_slot_names or {}

				for _, parent_slot_name in pairs(parent_slot_names) do
					local slot = slots[parent_slot_name]
					local parent_slot_unit_3p = slot and slot.unit_3p
					local parent_item = slot and slot.item
					local parent_item_deform_overrides = parent_item and parent_item.deform_overrides or {}

					for _, parent_item_deform_override in pairs(parent_item_deform_overrides) do
						deform_overrides[#deform_overrides + 1] = parent_item_deform_override
					end

					if parent_slot_unit_3p then
						parent_unit_3p = parent_slot_unit_3p

						local apply_to_parent = item.material_override_apply_to_parent

						if apply_to_parent then
							local material_overrides = item.material_overrides

							for _, material_override in ipairs(material_overrides) do
								VisualLoadoutCustomization.apply_material_override(parent_unit_3p, nil, false, material_override, false)
							end
						end
					else
						Log.warning("UIProfileSpawner", "Item %s cannot attach to unit in slot %s as it is spawned in the wrong order. Fix the slot priority configuration", item.name, parent_slot_name)
					end
				end

				local item_deform_overrides = display_item.deform_overrides or {}

				for _, deform_override in pairs(item_deform_overrides) do
					deform_overrides[#deform_overrides + 1] = deform_override
				end

				equipment_component:equip_item(parent_unit_3p, nil, slot, display_item, nil, deform_overrides, breed_name, nil, nil, companion_unit_3p)
			end
		end

		if unit_3p and not self._visible then
			Unit.set_unit_visibility(unit_3p, false, true)
		end
	end

	if state_machine and not optional_ignore_state_machine then
		Unit.set_animation_state_machine(unit_3p, state_machine)
	end

	if animation_event then
		Unit.animation_event(unit_3p, animation_event)
	end

	if companion_unit_3p then
		if companion_state_machine and not companion_optional_ignore_state_machine then
			Unit.set_animation_state_machine(companion_unit_3p, companion_state_machine)
		end

		if companion_animation_event then
			Unit.animation_event(companion_unit_3p, companion_animation_event)
		end
	end

	if face_state_machine_key then
		self:_assign_face_state_machine(loadout, slots, face_state_machine_key)
	end

	local face_unit = table.nested_get(slots, "slot_body_face", "unit_3p")
	local has_animation_state_machine = face_unit ~= nil and Unit.has_animation_state_machine(face_unit)

	if face_animation_event and has_animation_state_machine then
		if Unit.has_animation_event(face_unit, "no_anim") then
			Unit.animation_event(face_unit, "no_anim")
		end

		if Unit.has_animation_event(face_unit, face_animation_event) then
			Unit.animation_event(face_unit, face_animation_event)
		end
	end

	local character_spawn_data = {
		streaming_complete = false,
		slots = slots,
		archetype_name = archetype_name,
		breed_name = breed_name,
		equipment_component = equipment_component,
		equipped_items = equipped_items,
		profile_loader = profile_loader,
		rotation = rotation and QuaternionBox(rotation),
		loading_items = {},
		profile = profile,
		unit_3p = unit_3p,
		disable_hair_state_machine = disable_hair_state_machine,
		has_external_unit_3p = optional_unit_3p ~= nil,
		force_highest_mip = force_highest_mip,
		companion_unit_3p = companion_unit_3p,
		has_external_companion_unit_3p = companion_optional_unit_3p ~= nil,
		companion_position = self._loading_profile_data.companion_data.original_position,
		companion_rotation = self._loading_profile_data.companion_data.original_rotation,
		companion_ignore = companion_ignore,
		companion_attach_to_character = companion_attach_to_character,
	}

	self._character_spawn_data = character_spawn_data

	local wield_slot_id = self._request_wield_slot_id

	if not wield_slot_id or self._ignored_slots[wield_slot_id] then
		wield_slot_id = "slot_unarmed"
	end

	self:wield_slot(wield_slot_id)

	local on_complete_callback = callback(self, "cb_on_unit_3p_streaming_complete", unit_3p)

	if force_highest_mip then
		Unit.force_stream_meshes(unit_3p, on_complete_callback, true, GameParameters.force_stream_mesh_timeout)
	else
		on_complete_callback()
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
  mod:hook_disable(CLASS.UIProfileSpawner, "_change_slot_item")

  --mod:hook_disable(CLASS.UIProfileSpawner, "spawn_profile")
end)

mod:hook_safe(CLASS.CosmeticsVendorView, "on_exit", function(self)
  mod:hook_enable(CLASS.UIWeaponSpawner, "_spawn_weapon")
  mod:hook_enable(CLASS.UIProfileSpawner, "_change_slot_item")

  --mod:hook_enable(CLASS.UIProfileSpawner, "spawn_profile")
end)

mod:hook_safe(CLASS.StoreItemDetailView, "on_enter", function(self)
  -- todo: allow preview when equipped on character
  mod:hook_disable(CLASS.UIWeaponSpawner, "_spawn_weapon")
  mod:hook_disable(CLASS.UIProfileSpawner, "_change_slot_item")

  --mod:hook_disable(CLASS.UIProfileSpawner, "spawn_profile")
end)

mod:hook_safe(CLASS.StoreItemDetailView, "on_exit", function(self)
  mod:hook_enable(CLASS.UIWeaponSpawner, "_spawn_weapon")
  mod:hook_enable(CLASS.UIProfileSpawner, "_change_slot_item")

  --mod:hook_enable(CLASS.UIProfileSpawner, "spawn_profile")
end)

mod:hook_safe(CLASS.StoreView, "on_enter", function(self)
  -- todo: allow preview when equipped on character
  mod:hook_disable(CLASS.UIWeaponSpawner, "_spawn_weapon")
  mod:hook_disable(CLASS.UIProfileSpawner, "_change_slot_item")

  --mod:hook_disable(CLASS.UIProfileSpawner, "spawn_profile")
end)

mod:hook_safe(CLASS.StoreView, "on_exit", function(self)
  mod:hook_enable(CLASS.UIWeaponSpawner, "_spawn_weapon")
  mod:hook_enable(CLASS.UIProfileSpawner, "_change_slot_item")

  --mod:hook_enable(CLASS.UIProfileSpawner, "spawn_profile")
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

  if instance.slot_body_torso then
    instance.slot_body_torso.slot_dependencies = instance.slot_body_torso.slot_dependencies or {}
    table.insert(instance.slot_body_torso.slot_dependencies, "slot_body_torso_tattoo")
  end

  if instance.slot_body_arms then
    instance.slot_body_arms.slot_dependencies = instance.slot_body_arms.slot_dependencies or {}
    table.insert(instance.slot_body_arms.slot_dependencies, "slot_body_arms_tattoo")
  end

  if instance.slot_body_legs then
    instance.slot_body_legs.slot_dependencies = instance.slot_body_legs.slot_dependencies or {}
    table.insert(instance.slot_body_legs.slot_dependencies, "slot_body_legs_tattoo")
  end
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

  if instance.slot_configuration.slot_body_torso then
    instance.slot_configuration.slot_body_torso.slot_dependencies = instance.slot_configuration.slot_body_torso.slot_dependencies or {}
    table.insert(instance.slot_configuration.slot_body_torso.slot_dependencies, "slot_body_torso_tattoo")
  end

  if instance.slot_configuration.slot_body_arms then
    instance.slot_configuration.slot_body_arms.slot_dependencies = instance.slot_configuration.slot_body_arms.slot_dependencies or {}
    table.insert(instance.slot_configuration.slot_body_arms.slot_dependencies, "slot_body_arms_tattoo")
  end

  if instance.slot_configuration.slot_body_legs then
    instance.slot_configuration.slot_body_legs.slot_dependencies = instance.slot_configuration.slot_body_legs.slot_dependencies or {}
    table.insert(instance.slot_configuration.slot_body_legs.slot_dependencies, "slot_body_legs_tattoo")
  end
end)
