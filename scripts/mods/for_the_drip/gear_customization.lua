local mod = get_mod("for_the_drip")

local ItemMaterialOverrides = require("scripts/settings/equipment/item_material_overrides/item_material_overrides")
local FixedFrame = require("scripts/utilities/fixed_frame")
local MasterItems = require("scripts/backend/master_items")
local Promise = require("scripts/foundation/utilities/promise")
local VisualLoadoutCustomization = require("scripts/extension_systems/visual_loadout/utilities/visual_loadout_customization")
local PlayerUnitVisualLoadoutExtension = require("scripts/extension_systems/visual_loadout/player_unit_visual_loadout_extension")

mod.apply_slot_customization = function(self, slot_name)
  local visual_loadout_extension = mod:get_visual_loadout_extension()

  if not visual_loadout_extension then
    return
  end

  -- head gear is a face attachment
  if slot_name == "slot_gear_head" then
    slot_name = "slot_body_face"
  end

  local item = table.clone_instance(visual_loadout_extension._equipment[slot_name].item)

  if item then
    local t = FixedFrame.get_latest_fixed_time() or 1

    visual_loadout_extension:unequip_item_from_slot(slot_name, t)

    mod:load_item_packages(item, function()
      visual_loadout_extension:equip_item_to_slot(item, slot_name, nil, t)
    end)
  end
end

mod.remove_custom_attachment = function(self, item_name, attachment_name, attach_item_name)
  local item_customization = mod.current_slots_data.gear_customization_data[item_name]

  if item_customization and item_customization.attachments and item_customization.attachments[attach_item_name] then
    local id = tonumber(string.split(attachment_name, "_")[2])
    local attachments = {}

    for item, data in pairs(item_customization.attachments) do
      local i = tonumber(string.split(data.name, "_")[2])

      if i > id then
        data.name = "attachment_"..(i-1)
      end

      if i ~= id then
        attachments[item] = table.clone(data)
      end
    end

    item_customization.attachments = attachments


    return true
  end

  return false
end

mod.make_custom_item = function(self, slot_name, base_item, source)
  if not base_item then
    return nil
  end

  if slot_name == "slot_body_face" then
    local item = table.clone_instance(base_item)

    local gear_head_item = base_item.attachments and base_item.attachments["slot_gear_head"] and base_item.attachments["slot_gear_head"].item or table.clone_instance(MasterItems.get_item("content/items/characters/player/human/gear_head/empty_headgear"))
    local custom_head_gear = mod:make_custom_item("slot_gear_head", gear_head_item)

    if not item.attachments then
      rawset(item, "attachments", {})
    end

    if not item.attachments["slot_gear_head"] then
      rawset(item.attachments, "slot_gear_head" , {
              ["children"] = {},
              ["material_overrides"] = {},
              ["item"] = ""
            })
    end

    rawset(item.attachments["slot_gear_head"], "item" , custom_head_gear)

    return item
  end

  local slot_data = mod.current_slots_data[slot_name]
  local item_custom = nil

  if mod.current_slots_data.gear_customization_data then
    item_custom = mod.current_slots_data.gear_customization_data[base_item.name]
  end

  if (not item_custom) and (not slot_data) then
    return base_item
  end

  local customized_item = table.clone_instance(base_item)
  local master_item = table.clone(MasterItems.get_item(base_item.name))

  if customized_item.attachments and master_item.attachments then
    rawset(customized_item, "attachments", table.merge(master_item.attachments, customized_item.attachments))
  end

  if customized_item.material_overrides then
    rawset(customized_item, "material_overrides", master_item.material_overrides or {})
  end

  local skip_attachments = false
  local has_custom_attach_material = false
  local attachments = {}
  local material_overrides = {}
  local full_mat_name = slot_name .."_material"

  local original_mat_data = master_item.material_overrides and mod:merge_materials(master_item.material_overrides) or {}
  local custom_slot_mat_data = mod:custom_preset_slot_to_material(slot_data)

  custom_slot_mat_data = table.merge_recursive(table.clone(original_mat_data), table.clone(custom_slot_mat_data))

  ItemMaterialOverrides[full_mat_name] = table.clone(custom_slot_mat_data)

  if not item_custom then
    skip_attachments = true
  end

  local has_extra_attachment = false



  if customized_item then
    if not customized_item.attachments then
      rawset(customized_item, "attachments", {})
    end
    -- to account for the added attachment, check the saved data first if available
    local attach_count = table.size(item_custom and item_custom.attachments or customized_item.attachments)

    if item_custom and item_custom.extra_attachments then
      for k, item in pairs(item_custom.extra_attachments) do
        local attach_name = "attachment_"..(attach_count+k)
        customized_item.attachments[attach_name] =
        {
          ["children"] = {},
          ["material_overrides"] = {},
          ["item"] = item
        }

        item_custom.attachments[item] =
        {
          ["is_visible"] = true,
          ["customize"] = true,
          ["name"] = attach_name,
          ["is_extra"] = true,
        }

        mod:load_item_packages(MasterItems.get_item(item))
      end

      has_extra_attachment = true

      -- save the current loadout to make sure the attachments are saved
      mod:save_current_loadout()

      item_custom.extra_attachments = nil -- attachment added, no need to keep them here
    end

    if item_custom then
      for item, att_data in pairs(item_custom.attachments) do
        if att_data.is_extra then

          customized_item.attachments[att_data.name] =
          {
            ["children"] = {},
            ["material_overrides"] = {},
            ["is_extra"] = true,
            ["item"] = item
          }
        end
      end

      skip_attachments = false
      has_extra_attachment = true
    end
  end

  if (not skip_attachments) and customized_item.attachments then
    for attach_name, attach_data in pairs(customized_item.attachments) do
      if attach_data.item and attach_data.item ~= "" then
        local item = attach_data.item

        if type(item) == "table" then
          item = item.name or "empty"
        end

        local short_name = mod:shorten_item_name(item)
        local data = item_custom and item_custom.attachments[item]
        local attach_mat_name = slot_name .."_"..attach_name.."_"..short_name.."_material"

        if data then
          if data.is_visible then
            if data.material_data then
              ItemMaterialOverrides[attach_mat_name] = mod:custom_preset_slot_to_material(data.material_data)

              if not data.material_overrides then
                data.material_overrides = { attach_mat_name }
              else
                table.insert(data.material_overrides, attach_mat_name)
              end

              data.material_data = nil
            end

            if data.material_overrides and table.size(data.material_overrides) > 0 then
              has_custom_attach_material = true

              local attach = table.clone(attach_data)

              if not attach_data.material_overrides then
                attach.material_overrides = table.clone(data.material_overrides)
              else
                attach.material_overrides = table.clone(data.material_overrides)
              end

              ItemMaterialOverrides[attach_mat_name] = table.clone(mod:merge_materials(attach.material_overrides))

              attach.material_overrides = { attach_mat_name }
              attachments[attach_name] = table.clone(attach)
            else
              if attach_data.material_overrides then
                table.insert(attach_data.material_overrides, full_mat_name)
                attachments[attach_name] = table.clone(attach_data)
              end
            end
          end
        else
          if attach_data.material_overrides then
            table.insert(attach_data.material_overrides, full_mat_name)
            attachments[attach_name] = table.clone(attach_data)
          end
        end
      else
        if attach_data.material_overrides then
          table.insert(attach_data.material_overrides, full_mat_name)
          attachments[attach_name] = table.clone(attach_data)
        end
      end

      if attach_data.material_overrides then
        local mat_overrides = {}

        -- todo: get mat overrides for extra attachments
        if master_item.attachments and master_item.attachments[attach_name] and master_item.attachments[attach_name].material_overrides then
          mat_overrides = table.clone(master_item.attachments[attach_name].material_overrides)
        end

        -- avoid duplication, todo: avoid making them in the first place
        table.append_non_indexed(mat_overrides, attach_data.material_overrides)

        attach_data.material_overrides = table.unique_array_values(mat_overrides)
      end
    end

    rawset(customized_item, "attachments", table.clone(attachments))
  elseif not customized_item then
    for attach_name, attach_data in pairs(customized_item.attachments) do
      rawset(attach_data, "material_overrides", {})
    end
  end

  if slot_name == "slot_gear_upperbody" then
    if mod.current_slots_data["shirtless"] then
      rawset(customized_item, "mask_torso", "mask_default")
      rawset(customized_item, "mask_arms", "mask_default")
      rawset(customized_item, "hide_slots", {})
      rawset(customized_item, "attachments", {})

    elseif item_custom then
      rawset(customized_item, "mask_torso", item_custom.mask_torso)
      rawset(customized_item, "mask_arms", item_custom.mask_arms)

      local hide_slots = {}

      if item_custom.hide_body then
        table.insert(hide_slots, "slot_body_torso")
      end
      if item_custom.hide_arms then
        table.insert(hide_slots, "slot_body_arms")
      end

      rawset(customized_item, "hide_slots", hide_slots)
    end
  elseif slot_name == "slot_gear_lowerbody" then
    if mod.current_slots_data["pantless"] then
      rawset(customized_item, "mask_legs", "mask_default")
      rawset(customized_item, "hide_slots", {})
      rawset(customized_item, "attachments", {})

      skip_attachments = true
    elseif item_custom then
      rawset(customized_item, "mask_legs", item_custom.mask_legs)

      local hide_slots = {}

      if item_custom.hide_legs then
        table.insert(hide_slots, "slot_body_legs")
      end

      rawset(customized_item, "hide_slots", hide_slots)
    end
  elseif slot_name == "slot_gear_head" then
    if item_custom then
      rawset(customized_item, "hide_eyebrows", item_custom.hide_eyebrows)
      rawset(customized_item, "hide_beard", item_custom.hide_beard)
      rawset(customized_item, "mask_hair", item_custom.mask_hair)
      rawset(customized_item, "mask_facial_hair", item_custom.mask_facial_hair)


      if customized_item.base_unit == "content/characters/empty_item/empty_item" then
        rawset(customized_item, "base_unit", "content/characters/player/human/third_person/base_gear_rig")
        rawset(customized_item.resource_dependencies, "content/characters/player/human/third_person/base_gear_rig", true)
      end
      -- local hide_slots = {}

      -- if item_custom.hide_hair then
      --  table.insert(hide_slots, "slot_body_hair")
      -- end

      -- rawset(customized_item, "hide_slots", hide_slots)
    end
  end

  local material_names = {}

  if not has_custom_attach_material then
    if item_custom and item_custom.material_overrides then
      material_overrides = table.clone(item_custom.material_overrides)
    end

    table.insert(material_names, full_mat_name)
  end

  ItemMaterialOverrides[full_mat_name] = table.clone(custom_slot_mat_data)

  for _, mat_name in pairs(master_item.material_overrides or {}) do
    if string.find(mat_name, "emissive_") then
      table.insert(material_names, mat_name)
    end
  end

  rawset(customized_item, "material_overrides", material_names)

  return customized_item
end

mod.gear_custom_to_str = function(self, item_data)
  local str = ""

  str = str.."slot;"..item_data.slot.."###"
  str = str.."item;"..item_data.item.."###"

  if item_data.slot == "slot_gear_upperbody" then
    str = str.."mask_torso;"..(item_data.mask_torso or "").."###"
    str = str.."mask_arms;"..(item_data.mask_arms or "").."###"
    str = str.."hide_body;"..tostring(item_data.hide_body).."###"
    str = str.."hide_arms;"..tostring(item_data.hide_arms).."###"
  elseif item_data.slot == "slot_gear_lowerbody" then
    str = str.."mask_legs;"..(item_data.mask_legs or "").."###"
    str = str.."hide_legs;"..tostring(item_data.hide_legs).."###"
  elseif item_data.slot == "slot_gear_head" then
    str = str.."hide_eyebrows;"..tostring(item_data.hide_eyebrows).."###"
    if item_data.hide_hair then
      str = str.."hide_hair;"..tostring(item_data.hide_hair).."###"
    end
    str = str.."hide_beard;"..tostring(item_data.hide_beard).."###"
    str = str.."mask_hair;"..(item_data.mask_hair or "").."###"
    str = str.."mask_facial_hair;"..(item_data.mask_facial_hair or "").."###"
  end

  local first = true

  for item, at_data in pairs(item_data.attachments) do
    if not first then
      str = str.."###"
    else
      first = false
    end

    str = str.."item;"..item.."|"
    str = str.."is_visible;"..tostring(at_data.is_visible).."|"
    str = str.."customize;"..tostring(at_data.customize).."|"
    str = str.."name;"..at_data.name.."|"

    local material = mod:merge_materials(at_data.material_overrides)
    local custom_mat = mod:material_data_to_custom(material)
    str = str..mod:custom_mat_to_str(custom_mat).."|"

    str = str.."is_extra;"..tostring(at_data.is_extra or false)
  end

  return str
end


mod.gear_custom_from_str = function(self, data_str)
  local data = { attachments = {} }

  local t = mod:split_str(data_str, "###")

  for i=1,#t do
    local vt = mod:split_str(t[i], "|")

    local size = table.size(vt)
    -- attachments
    if size > 1 then
      local att_data = {}
      local item = string.split(vt[1], ";")[2]

      att_data.is_visible = string.split(vt[2], ";")[2] == "true"
      att_data.customize = string.split(vt[3], ";")[2] == "true"
      att_data.name = string.split(vt[4], ";")[2]
      att_data.is_extra = string.split(vt[6] or "is_extra;false", ";")[2] == "true"

      if att_data.is_extra then
        mod:load_item_packages(MasterItems.get_item(item))
      end

      att_data.material_data = mod:custom_material_from_str(vt[5])

      data.attachments[item] = att_data
    elseif table.size(vt) == 1 then
      local vt2 = string.split(vt[1], ";")
      local key = vt2[1]
      local value = vt2[2]

      if key and value then
        if string.match(key, "hide_") then
          data[key] = value == "true"
        else
          data[key] = value
        end
      end
    end
  end

  return data
end


-- todo: load custom changes from loadout afterwards
mod.load_slot_data = function(self, slot)

  local slot_name = slot.name
  local item = slot.item
  local name = item and item.name or ""

  if slot.name == "slot_body_face" then
    slot_name = "slot_gear_head"

    item = slot.item and slot.item.attachments and slot.item.attachments.slot_gear_head and slot.item.attachments.slot_gear_head.item

    if item then
      name = item.__master_item and item.__master_item.name or item.name
      item = table.clone(MasterItems.get_item(name))
    end
  end

  if item then
    local master_item = MasterItems.get_item(name)

    -- don't override existing gear data
    if mod.current_slots_data.gear_customization_data[name] then
      return
    end

    mod.current_slots_data.gear_customization_data[name] = {}

    local data = {}
    data.custom_attachment_mats = false
    data.item = name
    data.slot = slot_name

    if slot_name == "slot_gear_upperbody" then
      data.mask_torso = master_item.mask_torso
      data.mask_arms = master_item.mask_arms
      data.hide_body = false
      data.hide_arms = false

      if master_item.hide_slots then
        for k,v in pairs(master_item.hide_slots) do
          if v == "slot_body_arms" then
            data.hide_arms = true
          elseif v == "slot_body_torso" then
            data.hide_body = true
          end
        end
      end
    elseif slot_name == "slot_gear_lowerbody" then
      data.mask_legs = master_item.mask_legs
      data.hide_legs = false

      if master_item.hide_slots then
        for k,v in pairs(master_item.hide_slots) do
          if v == "slot_body_legs" then
            data.hide_legs = true
          end
        end
      end
    elseif slot_name == "slot_gear_head" then
      data.hide_eyebrows = master_item.hide_eyebrows or false
      data.hide_beard = master_item.hide_beard or false
      data.mask_hair = master_item.mask_hair
      data.mask_facial_hair = master_item.mask_facial_hair
    end

    data.attachments = {}

    if master_item.attachments then
      for attach_name, attach_data in pairs(master_item.attachments) do
        if attach_data.item and attach_data.item ~= "" then
          local itm = attach_data.item

          data.attachments[itm] = {}
          data.attachments[itm].is_visible = true
          data.attachments[itm].customize = true
          data.attachments[itm].name = attach_name
          data.attachments[itm].material_overrides = {}
        end
      end
    end

    mod.current_slots_data.gear_customization_data[name] = table.clone(data)
  end
end



mod.show_body_slot = function(self, visual_loadout_extension)
  if not mod.current_slots_data.gear_customization_data then
    return false
  end

	if mod.current_slots_data["shirtless"] then
		return true
	end

  if visual_loadout_extension then
    local slot = visual_loadout_extension._equipment["slot_gear_upperbody"]
    local item = slot.item

    if item then
      local slot_data = mod.current_slots_data.gear_customization_data[item.name]

      if slot_data and slot_data.hide_body == false then
        return true
      end
    end
  end

	return false
end

mod.show_arms_slot = function(self, visual_loadout_extension)
  if not mod.current_slots_data.gear_customization_data then
    return false
  end

	if mod.current_slots_data["shirtless"] then
		return true
	end

  if visual_loadout_extension then
    local slot = visual_loadout_extension._equipment["slot_gear_upperbody"]
    local item = slot.item

    if item then
      local slot_data = mod.current_slots_data.gear_customization_data[item.name]

      if slot_data and slot_data.hide_arms == false then
        return true
      end
    end
  end

	return false
end

mod.show_legs_slot = function(self, visual_loadout_extension)
  if not mod.current_slots_data.gear_customization_data then
    return false
  end

	if mod.current_slots_data["pantless"] then
		return true
	end

  if visual_loadout_extension then
    local slot = visual_loadout_extension._equipment["slot_gear_lowerbody"]
    local item = slot.item

    if item then
      local slot_data = mod.current_slots_data.gear_customization_data[item.name]

      if slot_data and slot_data.hide_legs == false then
        return true
      end
    end
  end

	return false
end

mod.current_head_gear_hide_hair = function()
  local vle = mod:get_visual_loadout_extension()

  if vle then
    local head_slot = vle._equipment["slot_gear_head"]

    if head_slot and head_slot.item then
      for k,v in pairs(head_slot.item.hide_slots or {}) do
        if v == "slot_body_hair" then
          return true
        end
      end
    end
  end

  return false
end