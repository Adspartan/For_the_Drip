local mod = get_mod("for_the_drip")

local ItemMaterialOverrides = require("scripts/settings/equipment/item_material_overrides/item_material_overrides")
local PlayerUnitVisualLoadoutExtension = require("scripts/extension_systems/visual_loadout/player_unit_visual_loadout_extension")
local FixedFrame = require("scripts/utilities/fixed_frame")
local Promise = require("scripts/foundation/utilities/promise")
local MasterItems = require("scripts/backend/master_items")
local ItemPackage = require("scripts/foundation/managers/package/utilities/item_package")
local PlayerCharacterConstants = require("scripts/settings/player_character/player_character_constants")

mod.current_slots_data = {}
mod.character_presets = {}
mod.presets = {}
mod.presets_info =
{
  max_preset_id = 0,
  presets = {},
  character_presets = {}
}

mod.reset_visual_loadout = function()
  mod:reset_editor_nav_combos()

  mod.selected_unit_slot = "none"
  mod.selected_preset = "none"
  mod.selected_preset_name = ""
  mod.new_preset_name = ""
  mod.current_slots_data = mod:default_slot_data()
  mod:save_current_loadout()

  mod:reset_all_gear_slots()

  mod:hook_enable(CLASS.PlayerUnitVisualLoadoutExtension, "_equip_item_to_slot")
end


mod.apply_custom_material_override = function(unit, material)
  if (not unit) or (not Unit.alive(unit)) or (not Unit.is_valid(unit)) or (not material) then
    return
  end

  if material["number"] then
    for property_name, data in pairs(material["number"]) do
      Unit.set_scalar_for_materials(unit, property_name, data, true)
    end
  end
  if material["scalar"] then
    for property_name, data in pairs(material["scalar"]) do
      Unit.set_scalar_for_materials(unit, property_name, data[1], true)
    end
  end
  if material["scalar2"] then
    for property_name, data in pairs(material["scalar2"]) do
      Unit.set_vector2_for_materials(unit, property_name, Vector2(data[1], data[2]), true)
    end
  end
  if material["scalar3"] then
    for property_name, data in pairs(material["scalar3"]) do
      Unit.set_vector3_for_materials(unit, property_name, Vector3(data[1], data[2], data[3]), true)
    end
  end
  if material["scalar4"] then
    for property_name, data in pairs(material["scalar4"]) do
      Unit.set_color_for_materials(unit, property_name, Color(data[1], data[2], data[3], data[4]), true)
    end
  end
  if material["textures"] then
    for texture_slot, texture in pairs(material["textures"]) do
      Unit.set_texture_for_materials(unit, texture_slot, texture, true)
    end
  end
end


mod.refresh_drip = function()
  mod:load_current_character_loadout()
  mod:refresh_all_gear_slots()
end

mod.get_slot_item = function(self, slot_name)
  local visual_loadout_extension = mod:get_visual_loadout_extension()

  if visual_loadout_extension then
    local item = visual_loadout_extension._equipment[slot_name].item

    if slot_name == "slot_gear_head" then
      local face_item = visual_loadout_extension._equipment["slot_body_face"].item

      if face_item then
        local gear_name = face_item.attachments and face_item.attachments.slot_gear_head and face_item.attachments.slot_gear_head.item and face_item.attachments.slot_gear_head.item.name

        if gear_name then
          item = face_item.attachments.slot_gear_head.item
        end
      end
    end

    return item
  end
end

mod.save_material_override_to_selected_slot = function(self, material_name)
  local item = mod:get_slot_item(mod.selected_unit_slot)

  if item then
    local data = mod.current_slots_data.gear_customization_data[item.name]

    if data then
      if data.custom_attachment_mats then
        for item, attach_data in pairs(data.attachments) do
          if attach_data.is_visible and attach_data.customize then
            if not attach_data.material_overrides then
              attach_data.material_overrides = {material_name}
            else
              table.insert(attach_data.material_overrides, material_name)
            end
          end
        end
      else
        mod.save_material_override_to_slot(mod.selected_unit_slot, ItemMaterialOverrides[material_name])
      end

      mod:apply_slot_customization(mod.selected_unit_slot)
    end
  end
end

mod.apply_mat_to_slot = function(slot_name, material_name)
  if slot_name == mod.selected_unit_slot then
    mod:save_material_override_to_selected_slot(material_name)
  else
    local visual_loadout_extension = mod:get_visual_loadout_extension()
    local material = ItemMaterialOverrides[material_name]

    if material then
      mod.save_material_override_to_slot(slot_name, material)

      if not visual_loadout_extension then
        return
      end

      -- head gear is a face attachment
      if slot_name == "slot_gear_head" then
        slot_name = "slot_body_face"
      end


      local unit_1p, unit_3p = visual_loadout_extension:unit_and_attachments_from_slot(slot_name)
      -- dummy are from the weapon customization mod, to display the weapons on the back of players
      local dummy_unit = nil
      local dummy_unit_1 = nil
      local dummy_unit_2 = nil

      if slot_name == "slot_primary" or slot_name == "slot_secondary" then
        for name,slot in pairs(visual_loadout_extension._equipment) do
          if slot.name == slot_name and slot.dummy then
            dummy_unit = slot.dummy

            if slot.dummy1 then
              dummy_unit_1 = slot.dummy1
            end

            if slot.dummy2 then
              dummy_unit_2 = slot.dummy2
            end
          end
        end
      end

      if unit_1p or unit_3p then
        mod.apply_material_override(unit_1p, material)
        mod.apply_material_override(unit_3p, material)
        mod.apply_material_override(dummy_unit, material)
        mod.apply_material_override(dummy_unit_1, material)
        mod.apply_material_override(dummy_unit_2, material)
      end
    end
  end
end

mod.apply_material_override = function(unit, material_override_data)
  if (not unit) or (not Unit.alive(unit)) or (not Unit.is_valid(unit)) or (not material_override_data) then
    return
  end

  if material_override_data.property_overrides ~= nil then
    for property_name, property_override_data in pairs(material_override_data.property_overrides) do
      if type(property_override_data) == "number" then
        Unit.set_scalar_for_materials(unit, property_name, property_override_data, true)
      else
        local property_override_data_num = #property_override_data

        if property_override_data_num == 1 then
          Unit.set_scalar_for_materials(unit, property_name, property_override_data[1], true)
        elseif property_override_data_num == 2 then
          Unit.set_vector2_for_materials(unit, property_name, Vector2(property_override_data[1], property_override_data[2]), true)
        elseif property_override_data_num == 3 then
          Unit.set_vector3_for_materials(unit, property_name, Vector3(property_override_data[1], property_override_data[2], property_override_data[3]), true)
        elseif property_override_data_num == 4 then
          Unit.set_vector4_for_materials(unit, property_name, Color(property_override_data[1], property_override_data[2], property_override_data[3], property_override_data[4]), true)
        end
      end
    end
  end

  if material_override_data.texture_overrides ~= nil then
    for texture_slot, texture_override_data in pairs(material_override_data.texture_overrides) do
      Unit.set_texture_for_materials(unit, texture_slot, texture_override_data.resource, true)
    end
  end
end

mod.apply_customization_to_back_weapons = function(self, unit, slot_name)
  if unit and ScriptUnit.has_extension(unit, "visible_equipment_system") then
    local visible_equipment_extension = ScriptUnit.extension(unit, "visible_equipment_system")

    if visible_equipment_extension.equipment then
      local slot = visible_equipment_extension.equipment[slot_name]

      if slot and visible_equipment_extension.dummy_units[slot] then
        local dummies = visible_equipment_extension.dummy_units[slot]

        
        if dummies.base then
          mod.apply_custom_material_override(dummies.base, mod.current_slots_data[slot_name])
        end

        
        if dummies.dummy1 then
          mod.apply_custom_material_override(dummies.dummy1, mod.current_slots_data[slot_name])
        end

        if dummies.dummy2 then
          mod.apply_custom_material_override(dummies.dummy2, mod.current_slots_data[slot_name])
        end

        return true
      end
    end
  end

  return false
end

mod.prepare_body_slot_item = function(self, loadout, slot_name)
  local item = table.clone_instance(loadout[slot_name])

  local attachments = item.attachments or {}

  -- todo: handle children too (used for the face hair colour for ex)
  for k, slot_dep_name in pairs(PlayerCharacterConstants.slot_configuration[slot_name].slot_dependencies) do
    if not attachments[slot_dep_name] then
      local dependency_item = loadout[slot_dep_name]
      if dependency_item then
        local attachment = table.clone_instance(dependency_item)

        attachments[slot_dep_name] = { item = attachment }
      end
    end
  end

  rawset(item, "attachments", attachments)

  return item
end

mod.add_required_body_attachments = function(self, item, loadout, slot_name)
  local attachments = item.attachments or {}

  for k, slot_dep_name in pairs(PlayerCharacterConstants.slot_configuration[slot_name].slot_dependencies) do
    local attachment = table.clone_instance(loadout[slot_dep_name])

    if not attachments[slot_dep_name] then
      attachments[slot_dep_name] = { item = attachment }
    end
  end

  rawset(item, "attachments", attachments)

  return item
end

mod.refresh_slot = function(self, slot_name)
  local visual_loadout_extension = mod:get_visual_loadout_extension()

  if visual_loadout_extension then
    local slot = visual_loadout_extension._equipment[slot_name]

    if slot.item then
      local item = (string.find(slot_name, "_body_")) and table.clone_instance(slot.item) or table.clone(MasterItems.get_item(slot.item.name))

      if item then
        mod:load_item_packages(item, function()
          local t = FixedFrame.get_latest_fixed_time() or 1
          visual_loadout_extension:unequip_item_from_slot(slot_name, t)
          visual_loadout_extension:equip_item_to_slot(item, slot_name, nil, t)
        end)
      end
    end
  end
end

mod.refresh_all_gear_slots = function()
  mod:refresh_slot("slot_gear_head")
  mod:refresh_slot("slot_body_face")
  mod:refresh_slot("slot_gear_upperbody")
  mod:refresh_slot("slot_gear_lowerbody")
  mod:refresh_slot("slot_gear_extra_cosmetic")

  local player = Managers.player:local_player_safe(1)

  if player then
    mod:apply_customization_to_back_weapons(player.player_unit, "slot_primary")
    mod:apply_customization_to_back_weapons(player.player_unit, "slot_secondary")
  end
end

mod.reset_slot = function(self, slot_name)
  mod:reset_editor_nav_combos()

  mod.current_slots_data[slot_name] = {}

  local items_to_reset = {}

  if mod.current_slots_data and mod.current_slots_data.gear_customization_data then
    for item, custom_data in pairs(mod.current_slots_data.gear_customization_data) do
      if custom_data.slot == slot_name then
        table.insert(items_to_reset, item)
      end
    end
  end

  for k, item in pairs(items_to_reset) do
    mod.current_slots_data.gear_customization_data[item] = nil
  end

  local visual_loadout_extension = mod:get_visual_loadout_extension()
  local player = Managers.player:local_player_safe(1)

  -- temp fix: refreshing the melee weapon with weapon customization can cause a crash
  local skip_primary = mod.weapon_customization and slot_name == "slot_primary"

  if visual_loadout_extension and (not skip_primary) then
    -- helmet is attached to the face
    if slot_name == "slot_gear_head" then
      local slot = visual_loadout_extension._equipment["slot_body_face"]
      local ext_face = table.clone_instance(slot.item or {})

      if ext_face.attachments and ext_face.attachments["slot_gear_head"] then
        ext_face.attachments["slot_gear_head"].item = table.clone(MasterItems.get_item(ext_face.attachments["slot_gear_head"].item.name))
      end

      local t = FixedFrame.get_latest_fixed_time() or 1
      visual_loadout_extension:unequip_item_from_slot("slot_body_face", t)
      visual_loadout_extension:equip_item_to_slot(ext_face, "slot_body_face", nil, t)
    else
      local slot = visual_loadout_extension._equipment[slot_name]

      if slot.item then
        local item = table.clone(MasterItems.get_item(slot.item.name))

        if item then
          mod:load_item_packages(item, function()
            local t = FixedFrame.get_latest_fixed_time() or 1
            visual_loadout_extension:unequip_item_from_slot(slot_name, t)
            visual_loadout_extension:equip_item_to_slot(item, slot_name, nil, t)
          end)
        end
      end
    end
  end

  mod:save_current_loadout()
end

mod.reset_all_gear_slots = function()
  mod:reset_slot("slot_primary")
  mod:reset_slot("slot_secondary")
  mod:reset_slot("slot_gear_head")
  mod:reset_slot("slot_gear_upperbody")
  mod:reset_slot("slot_gear_lowerbody")
  mod:reset_slot("slot_gear_extra_cosmetic")
end

mod:command("save_drip", "Save the current gear customization preset", function()
  mod:save_current_look()
end)

mod:command("refresh_drip", "Re-apply the current preset to your gear", function()
  mod:refresh_drip()
end)

mod:command("reset_drip", "Remove all customization from your gear", function()
  mod:reset_visual_loadout()
end)

mod.weapon_customization = nil

mod.on_all_mods_loaded = function()
  mod:setup_output_folder()

  if not mod:persistent_table("data").head_gear_name then
    mod:persistent_table("data").head_gear_name = ""
  end

  mod.weapon_customization = get_mod("weapon_customization")

  Managers.backend.interfaces.characters:fetch():next(function(characters)
    if characters then
      Promise.until_true(MasterItems.has_data):next(function()
        mod:load_presets_v2()

        for k, character in pairs(characters) do
          mod:load_character_loadout(character.id, false)
        end

        mod:refresh_drip()
      end)
    end
  end)

  if mod:get("preview_attachments") == nil then
    mod:set("preview_attachments", true)
  end

  if mod:get("apply_masks_on_change") == nil then
    mod:set("apply_masks_on_change", true)
  end

  mod:reset_editor_nav_combos()
  mod:run_update_check()
  mod:parse_changelogs()
  mod.current_version = mod:get_current_version() or ""
end

mod.load_extra_packages_if_needed = function(self, item)
  if item then
    if item.attachments then
      local promises = {}
      local has_extra = false

      for id, att_data in pairs(item.attachments) do
        if att_data.is_extra == true then
          promises[#promises + 1] = mod:load_item_packages(type(att_data.item) == "table" and att_data.item.name and att_data.item or MasterItems.get_item(att_data.item))
        end
      end

      return Promise.all(unpack(promises))
    end
  end

  return Promise.delay(0)
end

mod._loaded_packages = {}

mod.load_item_packages = function(self, item, callback)
  if not item then
    return
  end

  local dependencies = ItemPackage.compile_item_instance_dependencies(item, MasterItems.get_cached(), nil, nil)
  local loading_finished = {}
  for package_name, _ in pairs(dependencies) do
    dependencies[package_name] = true

    loading_finished[package_name] = false
    local load_id = Managers.package:load(package_name, "for_the_drip", function()  loading_finished[package_name] = true end, true)
    mod._loaded_packages[package_name] = mod._loaded_packages[package_name] or {}
    table.insert(mod._loaded_packages[package_name], load_id)
  end

  rawset(item, "resource_dependencies", dependencies)

  local promise = Promise.until_value_is_true(function()
      for package, is_loaded in pairs(loading_finished) do
        if is_loaded ~= true then
          return false
        end
      end

      return true
    end)

  if callback then
    return promise:next(callback)
  else
    return promise
  end
end

mod.attachment_per_slot_per_breed = nil
mod.attachments_per_breed = nil
mod.is_fetching_attachments = false

-- only owned gear
mod.fetch_all_gear = function()
  return Managers.data_service.gear:fetch_gear():next(function (gear_list)
    local items = {}

    for gear_id, gear in pairs(gear_list) do
      items[#items+1] = MasterItems.get_item_instance(gear, gear_id)
    end

    return items
  end)
end

mod.fetch_avaiable_attachment_per_slot_per_breed = function()
  mod.is_fetching_attachments = true

  mod:fetch_all_gear():next(function(items)
    local data = {}
    local already_checked = {}
    local already_added = {}

    for k, item in pairs(items) do
      local name = item.name

      if not already_checked[name] then
        already_checked[name] = true

        for i, breed in pairs(item.breeds or {}) do
          if not data[breed] then
            data[breed] = {}
            already_added[breed] = {}
          end

          for j, slot in pairs(item.slots or {}) do
            local actual_slot = slot

            if slot == "slot_body_face" then
              actual_slot = "slot_gear_head"
            end
            if slot == "slot_gear_arms" or slot == "slot_gear_gloves" or slot == "slot_body_torso" or slot == "slot_body_arms" or slot == "slot_gear_torso" then
              actual_slot = "slot_gear_upperbody"
            end
            if slot == "slot_gear_legs" or slot == "slot_gear_shoes" then
              actual_slot = "slot_gear_lowerbody"
            end

            if not data[breed][actual_slot] then
              data[breed][actual_slot] = {}
              already_added[breed][actual_slot] = {}
            end

            local t = data[breed][actual_slot]
            local t_add = already_added[breed][actual_slot]

            local no_item_attachments = true

            if item.attachments and table.size(item.attachments) > 0 then
              for n, attachment in pairs(item.attachments or {}) do
                local att_name = ""

                if attachment.item and type(attachment.item) == "string" then
                  att_name = attachment.item
                elseif attachment.item and attachment.item.name then
                  att_name = attachment.item.name
                end

                if att_name and att_name ~= "" then
                  no_item_attachments = false

                  if not t_add[att_name] then
                    t[#t + 1] = att_name
                    t_add[att_name] = true
                  end
                end
              end
            end

            -- full items causes issues as they can't be used as attachments
            if (not t_add[item.name]) and no_item_attachments then
              -- those don't have any sub attachments but are still causing issues
              if (not string.contains_any(item.name, "empty_", "preview_")) then
                t[#t + 1] = item.name
                t_add[item.name] = true
              end
            end
          end
        end
      end
    end

    for breed, breed_data in pairs(data) do
      for slot, slot_data in pairs(breed_data) do
        table.sort(data[breed][slot], function(a, b) return a:lower() < b:lower() end)
      end
    end

    mod.attachment_per_slot_per_breed = table.clone(data)
    mod.is_fetching_attachments = false
  end)
end



mod:io_dofile("for_the_drip/scripts/mods/for_the_drip/file_io")
mod:io_dofile("for_the_drip/scripts/mods/for_the_drip/utils")
mod:io_dofile("for_the_drip/scripts/mods/for_the_drip/hooks")
mod:io_dofile("for_the_drip/scripts/mods/for_the_drip/data")
mod:io_dofile("for_the_drip/scripts/mods/for_the_drip/drip_editor")
mod:io_dofile("for_the_drip/scripts/mods/for_the_drip/drip_editor_utils")
mod:io_dofile("for_the_drip/scripts/mods/for_the_drip/gear_customization")
mod:io_dofile("for_the_drip/scripts/mods/for_the_drip/presets")
mod:io_dofile("for_the_drip/scripts/mods/for_the_drip/updater/updater")
mod:io_dofile("for_the_drip/scripts/mods/for_the_drip/updater/changelogs_ui")
