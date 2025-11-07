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
    mod:load_item_packages(item, function()
      local t = FixedFrame.get_latest_fixed_time() or 1

      visual_loadout_extension:unequip_item_from_slot(slot_name, t)
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

mod.make_custom_item = function(self, slot_name, source_item, source)
  if not source_item then
    return nil
  end

  local should_edit = slot_name == "slot_primary" or slot_name == "slot_secondary" or string.find(slot_name, "slot_body_") or string.find(slot_name, "slot_gear_")

  if not should_edit then
    return source_item
  end

  local body_data = mod.current_slots_data.body_customization_data


  if slot_name == "slot_body_eye_color" then
    local token = source_item.material_overrides
        and source_item.material_overrides[1]
        or "eyes_blue_01"      

    rawset(source_item, "material_overrides", { token })

    
    rawset(source_item, "material_override_apply_to_parent", true)
    rawset(source_item, "parent_slot_names", { "slot_body_face" })
end

  if slot_name == "slot_body_face" or slot_name == "slot_body_hair_color" then
    local mats = table.clone(source_item.material_overrides or {})

    if body_data and body_data.use_custom_hair_color and body_data.custom_hair_color ~= "" then
      local mat_name = "hair_color_custom"

      ItemMaterialOverrides[mat_name] = {
        texture_overrides = {
          hair_color_gradient = {
            resource = mod.available_colors_textures[body_data.custom_hair_color]
          }
        },
	    }

      if not table.array_contains(mats, "hair_color_custom") then
        table.insert(mats, "hair_color_custom")
      end

      rawset(source_item, "material_overrides", mats)
    elseif source_item.material_overrides and table.array_contains(mats, "hair_color_custom") then
      mats = table.filter(mats, function(v) return v ~= "hair_color_custom" end)
      rawset(source_item, "material_overrides", mats)
    end
  end

  if slot_name == "slot_body_face" then
        local gear_head_item = source_item.attachments and source_item.attachments["slot_gear_head"] and source_item.attachments["slot_gear_head"].item
    if gear_head_item then
      gear_head_item = table.clone_instance(gear_head_item)
    end
    local custom_head_gear = mod:make_custom_item("slot_gear_head", gear_head_item)

    if not source_item.attachments then
      rawset(source_item, "attachments", {})
    end

    if not source_item.attachments["slot_gear_head"] then
      rawset(source_item.attachments, "slot_gear_head" , {
              ["children"] = {},
              ["material_overrides"] = {},
              ["item"] = ""
            })
    end

    rawset(source_item.attachments["slot_gear_head"], "item" , custom_head_gear)

    local hide_hair = false
    local hide_beard = false

    if custom_head_gear then
      rawset(source_item, "hide_eyebrows", custom_head_gear.hide_eyebrows)
      rawset(source_item, "hide_beard", custom_head_gear.hide_beard)
      rawset(source_item, "mask_hair", custom_head_gear.mask_hair)
      rawset(source_item, "mask_facial_hair", custom_head_gear.mask_facial_hair)
      rawset(source_item, "mask_face", custom_head_gear.mask_face)

      if mod.current_slots_data.gear_customization_data then
        local head_gead_data = mod.current_slots_data.gear_customization_data[custom_head_gear.name]

        if head_gead_data then
          hide_hair = head_gead_data.hide_hair
        else
          hide_hair = mod:head_gear_hide_hair(custom_head_gear)
        end
      else
        hide_hair = mod:head_gear_hide_hair(custom_head_gear)
      end

      hide_beard = custom_head_gear.hide_beard
    end

    if hide_hair then
      rawset(source_item.attachments, "slot_body_hair" ,
      {
        children = {},
        item = "",
      })
    else
      local player = Managers.player:local_player_safe(1)
      local loadout = player:profile().loadout

      local hair_item = mod:add_required_body_attachments(loadout["slot_body_hair"], loadout, "slot_body_hair")

      rawset(source_item.attachments, "slot_body_hair" ,
      {
        item = mod:make_custom_item("slot_body_hair", hair_item),
      })
    end

    if hide_beard then
      rawset(source_item.attachments, "slot_body_face_hair", {
        children = {},
        item = ""
      })
    else
      local player = Managers.player:local_player_safe(1)
      local loadout = player:profile().loadout
      local face_hair_item = loadout["slot_body_face_hair"]

      if face_hair_item then
        face_hair_item = mod:add_required_body_attachments(face_hair_item, loadout, "slot_body_face_hair")

        rawset(source_item.attachments, "slot_body_face_hair", {
          item = mod:make_custom_item("slot_body_face_hair", face_hair_item)
        })
      end
    end

    do
      local player = Managers.player and Managers.player:local_player_safe(1)

      if player then
        local loadout = player:profile().loadout or {}
        local face_tattoo_item = loadout["slot_body_face_tattoo"]

        if face_tattoo_item and face_tattoo_item ~= "" then
          local cloned_tattoo_item = table.clone_instance(face_tattoo_item)

          if not source_item.attachments then
            rawset(source_item, "attachments", {})
          end

          if not source_item.attachments["slot_body_face_tattoo"] then
            rawset(source_item.attachments, "slot_body_face_tattoo", {
              item = cloned_tattoo_item,
            })
          else
            source_item.attachments["slot_body_face_tattoo"].item = cloned_tattoo_item
          end
        end
      end
    end

    do
      local player = Managers.player and Managers.player:local_player_safe(1)

      if player then
        local loadout = player:profile().loadout or {}
        local face_scar_item = loadout["slot_body_face_scar"]

        if face_scar_item and face_scar_item ~= "" then
          local cloned_scar_item = table.clone_instance(face_scar_item)

          if not source_item.attachments then
            rawset(source_item, "attachments", {})
          end

          if not source_item.attachments["slot_body_face_scar"] then
            rawset(source_item.attachments, "slot_body_face_scar", { item = cloned_scar_item })
          else
            source_item.attachments["slot_body_face_scar"].item = cloned_scar_item
          end
        end
      end
    end

    do
      local player = Managers.player and Managers.player:local_player_safe(1)

      if player then
        local loadout = player:profile().loadout or {}
        local skin_color_item = loadout["slot_body_skin_color"]

        if skin_color_item and skin_color_item ~= "" then
          
          local cloned_skin_item = table.clone_instance(skin_color_item)

          if not source_item.attachments then
            rawset(source_item, "attachments", {})
          end

          rawset(source_item.attachments, "slot_body_skin_color", {
            item = cloned_skin_item,
          })
        end
      end
    end

    return source_item
  end

  local slot_data = mod.current_slots_data[slot_name]
  local customization_data = nil

  if mod.current_slots_data.gear_customization_data then
    customization_data = mod.current_slots_data.gear_customization_data[source_item.name]
  end

  if (not customization_data) and ((not slot_data) or (next(slot_data) == nil)) then
    if mod.selected_unit_slot == slot_name and mod.selected_extra_attach ~= "" then
      if not source_item.attachments then
        rawset(source_item, "attachments", {})
      end

      local attach_name = "attachment_preview"

      source_item.attachments[attach_name] =
      {
        ["children"] = {},
        ["material_overrides"] = {},
        ["item"] = mod.selected_extra_attach,
        ["is_extra"] = true,
        ["is_preview"] = true,
      }
    end

    return source_item
  end

  local master_item = table.clone(MasterItems.get_item(source_item.name))
  local skip_attachments = false
  local has_custom_attach_material = false
  local attachments = {}
  local material_overrides = {}
  local full_mat_name = slot_name .."_material"

  local original_mat_data = master_item.material_overrides and mod:merge_materials(master_item.material_overrides) or {}
  local custom_slot_mat_data = mod:custom_preset_slot_to_material(slot_data)

  custom_slot_mat_data = table.merge_recursive(table.clone(original_mat_data), table.clone(custom_slot_mat_data))

  ItemMaterialOverrides[full_mat_name] = table.clone(custom_slot_mat_data)

  if slot_name == "slot_primary" or slot_name == "slot_secondary" then
    rawset(source_item, "material_overrides", {full_mat_name})

    return source_item
  end


  if source_item.material_overrides then
    rawset(source_item, "material_overrides", master_item.material_overrides or {})
  end

  if not customization_data then
    skip_attachments = true
  end

  local has_extra_attachment = false
  local is_empty_backpack = false
  local attach_count = 0

  if source_item then
    if not source_item.attachments then
      rawset(source_item, "attachments", {})
    else
      -- reset extra attachments in case they got removed
      for name, att_data in pairs(source_item.attachments) do
        if att_data.is_extra then
          source_item.attachments[name] =
          {
            ["children"] = {},
            ["material_overrides"] = {},
            ["item"] = "",
            ["is_extra"] = true,
          }
        end

        attach_count = attach_count + 1
      end
    end

    if customization_data then
      for item, att_data in pairs(customization_data.attachments) do
        if att_data.is_extra then

          source_item.attachments[att_data.name] =
          {
            ["children"] = {},
            ["material_overrides"] = {},
            ["is_extra"] = true,
            ["item"] = table.clone(MasterItems.get_item(item))
          }
        end
      end

      skip_attachments = false
      has_extra_attachment = true
    end

    attach_count = table.size(source_item.attachments)

    if mod.selected_unit_slot == slot_name and mod.selected_extra_attach ~= "" then
      if not source_item.attachments then
        rawset(source_item, "attachments", {})
      end

      local attach_count = table.size(source_item.attachments)
      local attach_name = "attachment_preview"

      source_item.attachments[attach_name] =
      {
        ["children"] = {},
        ["material_overrides"] = {},
                  ["item"] = MasterItems.get_item(mod.selected_extra_attach) and table.clone(MasterItems.get_item(mod.selected_extra_attach)) or {},        ["is_extra"] = true,
        ["is_preview"] = true,
      }
    end
  end

  if (not skip_attachments) and source_item.attachments then
    for attach_name, attach_data in pairs(source_item.attachments) do
      if attach_data.item and attach_data.item ~= "" then
        local item = attach_data.item

        if type(item) == "table" then
          item = item.name or "empty"
        end

        local short_name = mod:shorten_item_name(item)
        local data = customization_data and customization_data.attachments[item]
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

    rawset(source_item, "attachments", table.clone(attachments))
  elseif not source_item then
    for attach_name, attach_data in pairs(source_item.attachments) do
      rawset(attach_data, "material_overrides", {})
    end
  end

  if slot_name == "slot_gear_upperbody" then
    if body_data["shirtless"] then
      rawset(source_item, "mask_torso", "mask_default")
      rawset(source_item, "mask_arms", "mask_default")
      rawset(source_item, "hide_slots", {})
      rawset(source_item, "attachments", {})

    elseif customization_data then

      local torso_mask = customization_data.mask_torso
      local arms_mask  = customization_data.mask_arms

      if customization_data.hide_body == false and (torso_mask == nil or torso_mask == "") then
        torso_mask = "mask_default"
      end

      if customization_data.hide_arms == false and (arms_mask == nil or arms_mask == "") then
        arms_mask = "mask_default"
      end

      rawset(source_item, "mask_torso", torso_mask)
      rawset(source_item, "mask_arms",  arms_mask)

      local hide_slots = {}

      if customization_data.hide_body then
        table.insert(hide_slots, "slot_body_torso")
      end
      if customization_data.hide_arms then
        table.insert(hide_slots, "slot_body_arms")
      end

      rawset(source_item, "hide_slots", hide_slots)
    end
  elseif slot_name == "slot_gear_lowerbody" then
    if body_data["pantless"] then
      rawset(source_item, "mask_legs", "mask_default")
      rawset(source_item, "hide_slots", {})
      rawset(source_item, "attachments", {})

      skip_attachments = true
    elseif customization_data then
      local legs_mask = customization_data.mask_legs

      if customization_data.hide_legs == false and (legs_mask == nil or legs_mask == "") then
        legs_mask = "mask_default"
      end

      rawset(source_item, "mask_legs", legs_mask)

      local hide_slots = {}

      if customization_data.hide_legs then
        table.insert(hide_slots, "slot_body_legs")
      end

      rawset(source_item, "hide_slots", hide_slots)
    end
  elseif slot_name == "slot_gear_extra_cosmetic" then
    if source_item.name == "content/items/characters/player/human/backpacks/empty_backpack" then
      for k, v in pairs(source_item.attachments or {}) do
        if v.item and v.item ~= "" then
          local backpack_error = false

          if type(v.item) == "string" then
            local miv_item = MasterItems.get_item(v.item)

            if miv_item then
              v.item = table.clone(miv_item)
            else
              backpack_error = true
            end

          end

          is_empty_backpack = true

          if backpack_error == false then
            -- swap the 2 units
            rawset(source_item, "base_unit", v.item.base_unit)
            rawset(source_item, "material_overrides", table.clone(v.item.material_overrides))
            rawset(source_item, "resource_dependencies", table.clone(v.item.resource_dependencies))
          end

          -- only 1 backpack
          break
        end
      end

      rawset(source_item, "attachments", {})
      rawset(source_item, "is_fallback_item", false)
      rawset(source_item, "sort_order", 0)
      rawset(source_item, "source", 4)
    end
  elseif slot_name == "slot_gear_head" then
    if customization_data then
      customization_data.mask_face = customization_data.mask_face or ""

      rawset(source_item, "hide_eyebrows", customization_data.hide_eyebrows)
      rawset(source_item, "hide_beard", customization_data.hide_beard)
      rawset(source_item, "mask_hair", customization_data.mask_hair)
      rawset(source_item, "mask_facial_hair", customization_data.mask_facial_hair)
      rawset(source_item, "mask_face", customization_data.mask_face)

      if source_item.base_unit == "content/characters/empty_item/empty_item" then
        rawset(source_item, "base_unit", "content/characters/player/human/third_person/base_gear_rig")
        rawset(source_item.resource_dependencies, "content/characters/player/human/third_person/base_gear_rig", true)
      end

      local hide_slots = {}

      if customization_data.hide_hair == nil then
        customization_data.hide_hair = mod:current_head_gear_hide_hair()
      end

      if customization_data.hide_hair then
        table.insert(hide_slots, "slot_body_hair")
      end

      rawset(source_item, "hide_slots", hide_slots)
    end
  end

  local material_names = {}

  if is_empty_backpack then
    material_names = table.clone(source_item.material_overrides or {})
  end

  if not has_custom_attach_material then
    if customization_data and customization_data.material_overrides then
      if is_empty_backpack then
        for k, v in pairs(customization_data.material_overrides) do
          material_names[#material_names+1] = v
        end
      else
        material_overrides = table.clone(customization_data.material_overrides)
      end
    end

    table.insert(material_names, full_mat_name)
  end

  ItemMaterialOverrides[full_mat_name] = table.clone(custom_slot_mat_data)

  for _, mat_name in pairs(master_item.material_overrides or {}) do
    if string.find(mat_name, "emissive_") then
      table.insert(material_names, mat_name)
    end
  end

  rawset(source_item, "material_overrides", material_names)

  return source_item
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
    if item_data.hide_hair ~= nil then
      str = str.."hide_hair;"..tostring(item_data.hide_hair).."###"
    end
    str = str.."hide_beard;"..tostring(item_data.hide_beard).."###"
    str = str.."mask_face;"..(item_data.mask_face or "").."###"
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
      data.hide_hair = mod:current_head_gear_hide_hair()
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

mod.make_extra_attach_data = function(self, attach_item_name, item)
  return
  {
    ["is_visible"] = true,
    ["is_extra"] = true,
    ["customize"] = true,
    ["name"] = "attachment_"..(mod:get_highest_attachment_id(item)+1).."_"..mod:shorten_item_name(attach_item_name),
    ["material_overrides"] = {},
  }
end

mod.show_body_slot = function(self, visual_loadout_extension)
  if not mod.current_slots_data.gear_customization_data then
    return false
  end

  if mod.current_slots_data.body_customization_data["shirtless"] then
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

  if mod.current_slots_data.body_customization_data["shirtless"] then
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

  if mod.current_slots_data.body_customization_data["pantless"] then
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

mod.current_head_gear_mask_face = function()
  local vle = mod:get_visual_loadout_extension()

  if vle then
    local head_slot = vle._equipment["slot_gear_head"]

    if head_slot and head_slot.item then
      return head_slot.item.mask_face or ""
    end
  end

  return ""
end

mod.head_gear_hide_hair = function(self, item)
  if not item then
    return false
  end

  if item.name == "content/items/characters/player/human/gear_head/empty_headgear" or item.mask_hair ~= "" then
    return false
  end

  for k,v in pairs(item.hide_slots or {}) do
    if v == "slot_body_hair" then
      return true
    end
  end

  return false
end

mod.current_head_gear_hide_hair = function()
  local vle = mod:get_visual_loadout_extension()

  if vle then
    local head_slot = vle._equipment["slot_gear_head"]
    local face_slot = vle._equipment["slot_body_face"]


    if head_slot and head_slot.item then
      return mod:head_gear_hide_hair(head_slot.item)
    elseif face_slot and face_slot.item and face_slot.item.attachments then
      local slot_body_hair = face_slot.item.attachments.slot_body_hair
      if slot_body_hair and slot_body_hair.item and slot_body_hair.item ~= "" then
        return false
      else
        return true
      end
    end
  end

  return false
end

mod.reset_selected_attachment = function(self)
  mod.selected_extra_attach = ""

  if mod.selected_unit_slot ~= "none" then
    mod:refresh_slot(mod.selected_unit_slot == "slot_gear_head" and "slot_body_face" or mod.selected_unit_slot)
  end
end

mod.update_preview_attachment_index = function(self)
  if mod.selected_attachment_index < 1 then
    mod:reset_selected_attachment()
  end

  local breed = mod:persistent_table("data").breed
  local t = mod.attachment_per_slot_per_breed[breed] and mod.attachment_per_slot_per_breed[breed][mod.selected_unit_slot] or {}
  local index = 0
  local last_index_found = 0
  local last_attach_found = ""

  for k, attach in pairs(t) do
    if mod.attachment_filter == "" or string.find(attach, mod.attachment_filter) then
      index = index + 1
      last_index_found = index
      last_attach_found = attach

      if index == mod.selected_attachment_index then
        mod.selected_attachment_index = index
        mod.current_preview_attach_display = mod:shorten_item_name(attach)
        mod:preview_attachment(attach)
        return
      end
    end
  end

  -- index not found, get the highest one found
  if last_attach_found ~= "" then
    mod.selected_attachment_index = last_index_found
    mod:preview_attachment(last_attach_found)
  else
    mod:reset_selected_attachment()
  end
end

mod.preview_attachment = function(self, item_name)
  if item_name and item_name ~= "" then
    if mod:get("preview_attachments") then
      mod:load_item_packages(MasterItems.get_item(item_name), function()
        mod.selected_extra_attach = item_name
        mod:refresh_slot(mod.selected_unit_slot == "slot_gear_head" and "slot_body_face" or mod.selected_unit_slot)
      end)
    else
      mod.selected_extra_attach = item_name
    end
  else
    mod.selected_extra_attach = ""

    if mod:get("preview_attachments") then
      mod:refresh_slot(mod.selected_unit_slot == "slot_gear_head" and "slot_body_face" or mod.selected_unit_slot)
    end
  end
end
