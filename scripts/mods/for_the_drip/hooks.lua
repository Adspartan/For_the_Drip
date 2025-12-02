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

mod:hook(CLASS.UIProfileSpawner, "_change_slot_items", function (func, self, changed_items, loadout, visual_loadout, equipped_items_or_nil)
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

  if profile and profile.character_id == mod:persistent_table("data").character_id then
    for slot_id, item in pairs(changed_items) do
      local custom_item = mod:make_custom_item(slot_id, item)

      changed_items[slot_id] = custom_item
      visual_loadout[slot_id] = custom_item

      if slot_id == "slot_gear_upperbody" and custom_item then
        local data = mod.current_slots_data.gear_customization_data[custom_item.name]

        if data then
          if data.hide_body == false then
            changed_items["slot_body_torso"] = loadout["slot_body_torso"]
            visual_loadout["slot_body_torso"] = loadout["slot_body_torso"]
          end

          if data.hide_arms == false then
            changed_items["slot_body_arms"] = loadout["slot_body_arms"]
            visual_loadout["slot_body_arms"] = loadout["slot_body_arms"]
          end
        end
      elseif slot_id == "slot_gear_lowerbody" and custom_item then
        local data = mod.current_slots_data.gear_customization_data[custom_item.name]

        if data and data.hide_legs == false then
          changed_items["slot_body_legs"] = loadout["slot_body_legs"]
          visual_loadout["slot_body_legs"] = loadout["slot_body_legs"]
        end
      end
    end
  end

  func(self, changed_items, loadout, visual_loadout, equipped_items_or_nil)

  if was_patched then
    self._single_item_profile_loader = nil
  end
end)

mod:hook_require("scripts/utilities/profile_utils", function(instance)

  mod:hook(instance, "generate_visual_loadout", function(func, loadout)
    local is_for_current_player = false

    for slot, item in pairs(loadout) do
      if item.customize_item_ftd then
        is_for_current_player = true
        break
      end
    end

    local visual_loadout = func(loadout)

    if is_for_current_player then
      for slot, _ in pairs(visual_loadout) do
        visual_loadout[slot] = loadout[slot]
      end

      local gear_data = mod.current_slots_data and mod.current_slots_data.gear_customization_data or {}
      local body_data = mod.current_slots_data and mod.current_slots_data.body_customization_data or {}

      local required_body_slots = {
        slot_body_torso = function()
          if body_data["shirtless"] then
            return true
          end
          local upper = loadout["slot_gear_upperbody"]
          if upper and gear_data then
            local d = gear_data[upper.name]
            return not (d and d.hide_body)
          end
          return true
        end,
        slot_body_arms = function()
          if body_data["shirtless"] then
            return true
          end
          local upper = loadout["slot_gear_upperbody"]
          if upper and gear_data then
            local d = gear_data[upper.name]
            return not (d and d.hide_arms)
          end
          return true
        end,
        slot_body_legs = function()
          if body_data["pantless"] then
            return true
          end
          local lower = loadout["slot_gear_lowerbody"]
          if lower and gear_data then
            local d = gear_data[lower.name]
            return not (d and d.hide_legs)
          end
          return true
        end,
      }

      for slot_name, should_show_fn in pairs(required_body_slots) do
        if should_show_fn() and not visual_loadout[slot_name] then
          visual_loadout[slot_name] = loadout[slot_name]
        end
      end

      if not visual_loadout["slot_body_eye_color"] then
        visual_loadout["slot_body_eye_color"] = loadout["slot_body_eye_color"]
      end
    end

    return visual_loadout
  end)
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

    for slot, item in pairs(loadout) do
      rawset(item, "customize_item_ftd", true)
    end
	end

	func(self, profile, profile_loader, position, rotation, scale, state_machine, animation_event, face_state_machine_key, face_animation_event, force_highest_mip, disable_hair_state_machine, optional_unit_3p, optional_ignore_state_machine, companion_data)
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
  mod:hook_disable(CLASS.UIProfileSpawner, "_change_slot_items")

  mod:hook_disable(CLASS.UIProfileSpawner, "_spawn_character_profile")
end)

mod:hook_safe(CLASS.CosmeticsVendorView, "on_exit", function(self)
  mod:hook_enable(CLASS.UIWeaponSpawner, "_spawn_weapon")
  mod:hook_enable(CLASS.UIProfileSpawner, "_change_slot_items")

  mod:hook_enable(CLASS.UIProfileSpawner, "_spawn_character_profile")
end)

mod:hook_safe(CLASS.StoreItemDetailView, "on_enter", function(self)
  -- todo: allow preview when equipped on character
  mod:hook_disable(CLASS.UIWeaponSpawner, "_spawn_weapon")
  mod:hook_disable(CLASS.UIProfileSpawner, "_change_slot_items")

  mod:hook_disable(CLASS.UIProfileSpawner, "_spawn_character_profile")
end)

mod:hook_safe(CLASS.StoreItemDetailView, "on_exit", function(self)
  mod:hook_enable(CLASS.UIWeaponSpawner, "_spawn_weapon")
  mod:hook_enable(CLASS.UIProfileSpawner, "_change_slot_items")

  mod:hook_enable(CLASS.UIProfileSpawner, "_spawn_character_profile")
end)

mod:hook_safe(CLASS.StoreView, "on_enter", function(self)
  -- todo: allow preview when equipped on character
  mod:hook_disable(CLASS.UIWeaponSpawner, "_spawn_weapon")
  mod:hook_disable(CLASS.UIProfileSpawner, "_change_slot_items")

  mod:hook_disable(CLASS.UIProfileSpawner, "_spawn_character_profile")
end)

mod:hook_safe(CLASS.StoreView, "on_exit", function(self)
  mod:hook_enable(CLASS.UIWeaponSpawner, "_spawn_weapon")
  mod:hook_enable(CLASS.UIProfileSpawner, "_change_slot_items")

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
