local mod = get_mod("for_the_drip")

local ItemMaterialOverrides = require("scripts/settings/equipment/item_material_overrides/item_material_overrides")
local MasterItems = require("scripts/backend/master_items")

mod.default_slot_data = function()
  return {
    slot_gear_head = {},
    slot_gear_upperbody = {},
    slot_gear_lowerbody = {},
    slot_gear_extra_cosmetic = {},
    slot_primary = {},
    slot_secondary = {},
    gear_customization_data = {},
    body_customization_data = {},
  }
end

mod.load_preset_packages = function(self, preset)
  if preset.gear_customization_data then
    for name, data in pairs(preset.gear_customization_data) do
      for att_item_name, att_data in pairs(data.attachments or {}) do
        if att_data.is_extra then
          mod:load_item_packages(MasterItems.get_item(att_item_name))
        end
      end
    end
  end
end

mod.load_presets_v2 = function(self)
  if mod.file_exist("presets_info.lua") then
    mod.presets_info = mod.load_lua_file("presets_info")

    for id, name in pairs(mod.presets_info.presets) do
      mod.presets[id] = mod.load_lua_file("preset_"..id)
      mod:load_preset_packages(mod.presets[id])
    end
  else
    if mod.file_exist("loadouts.txt") then
      mod:echo("Importing old presets..")

      local lines = mod.read_all_lines("loadouts.txt")

      mod.presets_info =
      {
        max_preset_id = 0,
        presets = {},
        character_presets = {}
      }

      for line in lines do
        if line ~= "" then
          local preset = table.clone(mod.deprecated_loadout_from_str(line))

          preset.id = preset.id or tostring(mod.presets_info.max_preset_id+1)

          if tonumber(preset.id) > mod.presets_info.max_preset_id then
            mod.presets_info.max_preset_id = tonumber(preset.id)
          end

          preset.name = preset.name or ("Preset "..preset.id)

          mod.presets[preset.id] = preset
          mod.presets_info.presets[preset.id] = preset.name
        end
      end
    end

    -- save to convert to the new format
    mod:save_presets_v2()
    mod:echo("Done")
  end
end

mod.save_presets_infos = function(self)
  mod.save_table_to_file(mod.presets_info, "presets_info")
end

mod.save_presets_v2 = function(self)
  mod:save_presets_infos()

  for id, name in pairs(mod.presets_info.presets) do
    if mod.presets[id] then
      mod.save_table_to_file(mod.presets[id], "preset_"..id)
    end
  end

  for id, exist in pairs(mod.presets_info and mod.presets_info.character_presets or {}) do
    if mod.character_presets[id] then
      mod.save_table_to_file(mod.character_presets[id], "preset_"..id)
    end
  end
end

local slot_data_to_str = function(slot_data)
  local str = ""

  for type_name, type_data in pairs(slot_data) do
    for k, v in pairs(type_data) do
      if str ~= "" then
        str = str..";"
      end

      str = str..type_name..";"..k..";"

      if type(v) == "table" then
        local value_str = ""

        for _, value in pairs(v) do
          if value_str ~= "" then
            value_str = value_str..","
          end

          value_str = value_str..value
        end

        str = str..value_str
      else
        str =  str..v
      end
    end
  end

  return str
end

mod.custom_mat_to_str = function(self, data)
  local str = ""

  for type_name, type_data in pairs(data) do
    for k, v in pairs(type_data) do
      if str ~= "" then
        str = str..";"
      end

      str = str..type_name..";"..k..";"

      if type(v) == "table" then
        local value_str = ""

        for _, value in pairs(v) do
          if value_str ~= "" then
            value_str = value_str..","
          end

          value_str = value_str..value
        end

        str = str..value_str
      else
        str =  str..v
      end
    end
  end

  return str
end


mod.slot_data_to_str = function(self, data)
  return slot_data_to_str(data)
end

local loadout_to_string = function(loadout)
  local str = ""

  for slot, slot_data in pairs(loadout) do
    if not string.match(slot, "slot_") and slot ~= "gear_customization_data" and slot ~= "body_customization_data" then
      if str ~= "" then
        str = str.."###"
      end
      str = str..slot.."###"..tostring(slot_data)
    elseif slot ~= "gear_customization_data" and slot ~= "body_customization_data" then
      local data_str = slot_data_to_str(slot_data)

      if data_str ~= "" then
        if str ~= "" then
          str = str.."###"
        end

        str = str..slot.."###"..data_str
      end
    end
  end

  if loadout.gear_customization_data then
    local gcd = loadout.gear_customization_data

    if type(gcd) == "table" then
      local first = true

      str = str.."#####"

      for item, item_data in pairs(gcd) do
        if not first then
          str = str.."####"
        else
          first = false
        end

        str = str.. mod:gear_custom_to_str(item_data)
      end

      if table.size(gcd) == 0 then
        str = str.."false"
      end
    else
      str = str.."false"
    end
  else
    str = str.."#####false"
  end

  if loadout.body_customization_data then
    local bcd = loadout.body_customization_data

    if type(bcd) == "table" then
      local first = true

      str = str.."#####"

      for name, value in pairs(bcd) do
        if not first then
          str = str.."###"
        else
          first = false
        end

        str = str.. name..";"..tostring(value)
      end

      if table.size(bcd) == 0 then
        str = str.."false"
      end
    else
      str = str.."false"
    end
  else
    str = str.."false"
  end

  return str
end

mod.custom_material_from_str = function(self, material_str)
  local data = {}

  if (not material_str) or material_str == "" then
    return nil
  end

  local t_data = string.split(material_str, ";")

  for k=1,#t_data,3 do
    local type_name = t_data[k]
    local name = t_data[k+1]
    local values = t_data[k+2]

    if not data[type_name] then
      data[type_name] = {}
    end

    local v_data = string.split(values, ",")

    if type_name == "textures" or type_name == "number" then
      data[type_name][name] = values
    elseif type_name == "scalar" then
      data[type_name][name] = { tonumber(v_data[1]) }
    elseif type_name == "scalar2" then
      data[type_name][name] = { tonumber(v_data[1]), tonumber(v_data[2]) }
    elseif type_name == "scalar3" then
      data[type_name][name] = { tonumber(v_data[1]), tonumber(v_data[2]),tonumber(v_data[3]) }
    elseif type_name == "scalar4" then
      data[type_name][name] = { tonumber(v_data[1]), tonumber(v_data[2]),tonumber(v_data[3]), tonumber(v_data[4]) }
    end
  end

  return data
end

mod.deprecated_loadout_from_str = function(str)
  local st_1 = nil
  local st_2 = nil
  local st_3 = nil

  if string.find(str, "#####") then
    local tab = mod:split_str(str, "#####")
    st_1 = tab[1]
    st_2 = tab[2]

    if table.size(tab) > 2 then
      st_3 = tab[3]
    end
  else
    st_1 = str
  end

  local t = mod:split_str(st_1, "###")
  local loadout = mod:default_slot_data()

  for i=1,#t,2 do
    local slot = t[i]
    local data = t[i+1]

    if not string.find(slot, "slot_") then
      if slot == "shirtless" or slot == "pantless" then
        loadout.body_customization_data[slot] = data == "true"
      else
        loadout[slot] = data
      end
    else
      loadout[slot] = mod:custom_material_from_str(data)
    end
  end

  if st_2 and st_2 ~= "" and st_2 ~= "false" then
    local tc = nil

    if not string.find(st_2, "####") then
      tc = { st_2 }
    else
      tc = mod:split_str(st_2, "####")
    end

    if tc and tc ~= "false" and tc ~= "" then
      for i=1,#tc do
        if tc[i] then
          local item_custom = mod:gear_custom_from_str(tc[i])

          if item_custom and item_custom.item then
            loadout.gear_customization_data[item_custom.item] = item_custom
          end
        end
      end
    end
  end

  if st_3 and st_3 ~= "" and st_3 ~= "false" then
    local body_tab = mod:split_str(st_3, "###")

    for k, v in pairs(body_tab) do
      local split = mod:split_str(v, ";")

      local key = split[1]
      local value = split[2]
      if value == "false" or value == "true" then
        loadout.body_customization_data[key] = value == "true"
      else
        loadout.body_customization_data[key] = value
      end
    end
  end

  return loadout
end


mod.load_preset = function(id)
  local data = mod.presets[id]

  if not data then
    data = mod:default_slot_data()
  end

  mod:reset_all_gear_slots() -- to clear out customizations
  mod.current_slots_data = table.clone(data)
  mod:save_current_loadout()
  mod:refresh_all_gear_slots()
end

mod.material_data_to_custom = function(self, material_data)
  local data = {}

  if material_data and material_data.property_overrides ~= nil then
    for property_name, property_override_data in pairs(material_data.property_overrides) do
      if type(property_override_data) == "number" then
        if not data["number"] then
          data["number"] = {}
        end

        data["number"][property_name] = property_override_data
      else
        local property_override_data_num = #property_override_data

        if property_override_data_num == 1 then
          if not data["scalar"] then
            data["scalar"] = {}
          end

          data["scalar"][property_name] = property_override_data

        elseif property_override_data_num == 2 then
          if not data["scalar2"] then
            data["scalar2"] = {}
          end

          data["scalar2"][property_name] = property_override_data

        elseif property_override_data_num == 3 then
          if not data["scalar3"] then
            data["scalar3"] = {}
          end

          data["scalar3"][property_name] = property_override_data

        elseif property_override_data_num == 4 then
          if not data["scalar4"] then
            data["scalar4"] = {}
          end

          data["scalar4"][property_name] = property_override_data
        end
      end
    end
  end

  if material_data and material_data.texture_overrides ~= nil then
    for texture_slot, texture_override_data in pairs(material_data.texture_overrides) do
      if not data.textures then
        data.textures = {}
      end

      data["textures"][texture_slot] = texture_override_data.resource
    end
  end

  return data
end

mod.save_material_override_to_slot = function(slot_name, material_override_data)
  if not mod.current_slots_data[slot_name] then
    mod.current_slots_data[slot_name] = {}
  end

  if material_override_data and material_override_data.property_overrides ~= nil then
    for property_name, property_override_data in pairs(material_override_data.property_overrides) do
      if type(property_override_data) == "number" then
        if not mod.current_slots_data[slot_name]["number"] then
          mod.current_slots_data[slot_name]["number"] = {}
        end

        mod.current_slots_data[slot_name]["number"][property_name] = property_override_data

      else
        local property_override_data_num = #property_override_data

        if property_override_data_num == 1 then
          if not mod.current_slots_data[slot_name]["scalar"] then
            mod.current_slots_data[slot_name]["scalar"] = {}
          end

          mod.current_slots_data[slot_name]["scalar"][property_name] = property_override_data

        elseif property_override_data_num == 2 then
          if not mod.current_slots_data[slot_name]["scalar2"] then
            mod.current_slots_data[slot_name]["scalar2"] = {}
          end

          mod.current_slots_data[slot_name]["scalar2"][property_name] = property_override_data

        elseif property_override_data_num == 3 then
          if not mod.current_slots_data[slot_name]["scalar3"] then
            mod.current_slots_data[slot_name]["scalar3"] = {}
          end

          mod.current_slots_data[slot_name]["scalar3"][property_name] = property_override_data

        elseif property_override_data_num == 4 then
          if not mod.current_slots_data[slot_name]["scalar4"] then
            mod.current_slots_data[slot_name]["scalar4"] = {}
          end

          mod.current_slots_data[slot_name]["scalar4"][property_name] = property_override_data
        end
      end
    end
  end

  if material_override_data.texture_overrides ~= nil then
    for texture_slot, texture_override_data in pairs(material_override_data.texture_overrides) do
      if not mod.current_slots_data[slot_name].textures then
        mod.current_slots_data[slot_name].textures = {}
      end

      mod.current_slots_data[slot_name]["textures"][texture_slot] = texture_override_data.resource
    end
  end
end

mod.load_current_character_loadout = function()
  local id = mod:persistent_table("data").character_id

  local player = Managers.player:local_player_safe(1)

  mod.current_slots_data = mod:default_slot_data()

  if player then
    id = player:character_id()

    if id then
      mod:persistent_table("data").character_id = id
      mod:load_character_loadout(id, true)
    end
  end
end

mod.load_character_loadout = function(self, id, apply)
  if not id then
    return
  end

  if mod.presets_info.character_presets[id] then
    -- not loaded yet or it has been manually deleted
    if not mod.character_presets[id] then
      if mod.file_exist("preset_"..id..".lua") then
        mod.character_presets[id] = mod.load_lua_file("preset_"..id)
        mod.presets_info.character_presets[id] = true

        mod:load_preset_packages(mod.character_presets[id])
      else
        mod.character_presets[id] = mod:default_slot_data()
        mod.presets_info.character_presets[id] = false
      end
    end
  else
    if mod.file_exist("loadout_"..id..".txt") then
      for line in mod.read_all_lines("loadout_"..id..".txt") do
        mod.character_presets[id] = table.clone(mod.deprecated_loadout_from_str(line))
        mod.presets_info.character_presets[id] = true
        mod.save_table_to_file(mod.character_presets[id], "preset_"..id)
        mod:save_presets_infos()
        break
      end
    else
      mod.character_presets[id] = mod:default_slot_data()
      mod.presets_info.character_presets[id] = false
    end
  end

  if apply then
    mod.current_slots_data = table.clone(mod.character_presets[id])
  end
end


mod.deleted_selected_preset = function()
  if mod.selected_preset ~= "none" then
    local temp = {}
    local temp_presets_info = {}

    for id,name in pairs(mod.presets_info.presets) do
      if id ~= mod.selected_preset then
        temp[id] = mod.presets[id]
        temp_presets_info[id] = mod.presets_info.presets[id]
      end
    end

    mod:echo(mod.selected_preset_name.. " has been deleted")

    mod.presets = table.clone(temp)
    mod.presets_info.presets = table.clone(temp_presets_info)
    mod.selected_preset = "none"
    mod.selected_preset_name = "none"
    mod.new_preset_name = "none"

    mod:save_presets_infos()
  end
end

mod.rename_selected_preset = function()
  if mod.selected_preset ~= "none" and mod.new_preset_name ~= "" then
    local id = mod.selected_preset
    local name = mod.presets_info.presets[id]

    mod.presets[id].name = mod.new_preset_name
    mod.presets_info.presets[id] = mod.new_preset_name

    mod:echo(mod.selected_preset_name.. " has been renamed to ".. mod.new_preset_name)

    mod.selected_preset_name = mod.new_preset_name

    mod.save_table_to_file(mod.presets[id], "preset_"..id)
    mod:save_presets_infos()
  end
end

mod.override_selected_preset = function()
  if mod.selected_preset ~= "none" then
    local id = mod.selected_preset

    mod.presets[id] = table.clone(mod.current_slots_data)

    mod:echo(mod.selected_preset_name.. " has been overridden")

    mod.save_table_to_file(mod.presets[id], "preset_"..id)
    mod:save_presets_infos()
  end
end

mod.save_current_look = function()
  mod.presets_info.max_preset_id = mod.presets_info.max_preset_id + 1
  local index = tostring(mod.presets_info.max_preset_id)
  mod.presets[index] = table.clone(mod.current_slots_data)
  mod.presets[index].id = index
  mod.presets[index].name = "Preset "..index

  mod.presets_info.presets[index] = mod.presets[index].name
  mod.save_table_to_file(mod.presets[index], "preset_"..index)

  mod:echo("Preset ".. index.. " saved")

  local id = mod:persistent_table("data").character_id
  if id then
    mod.save_table_to_file(mod.character_presets[id], "preset_"..id)
    mod.presets_info.character_presets[id] = true
  end

  mod:save_presets_infos()
end


mod.save_current_loadout = function()
  local id = mod:persistent_table("data").character_id
  if id then
    mod.character_presets[id] = table.clone(mod.current_slots_data)
    mod.presets_info.character_presets[id] = true

    mod.save_table_to_file(mod.character_presets[id], "preset_"..id)
    mod:save_presets_infos()
  end
end

mod.merge_materials = function(self, material_overrides)
  local mat = { property_overrides = {}, texture_overrides = {} }

  if material_overrides then
    for _, mat_name in pairs(material_overrides) do
      local material_override_data = ItemMaterialOverrides[mat_name]

      if material_override_data then
        if material_override_data.property_overrides ~= nil then
          for property_name, property_override_data in pairs(material_override_data.property_overrides) do
            if type(property_override_data) == "number" then
              mat[property_name] = property_override_data
            else
              mat[property_name] = table.clone(property_override_data)
            end
          end
        end

        if material_override_data.texture_overrides ~= nil then
          for texture_slot, texture_override_data in pairs(material_override_data.texture_overrides) do
            mat.texture_overrides[texture_slot] = table.clone(texture_override_data)
          end
        end
      end
    end
  end

  return mat
end

mod.custom_preset_slot_to_material = function(self, preset_slot_data)
  local result_data = { property_overrides = {}, texture_overrides = {} }

  if preset_slot_data then
    if preset_slot_data["number"] then
      for property_name, data in pairs(preset_slot_data["number"]) do
        result_data.property_overrides[property_name] = tonumber(data)
      end
    end
    if preset_slot_data["scalar"] then
      for property_name, data in pairs(preset_slot_data["scalar"]) do
        result_data.property_overrides[property_name] = table.clone(data)
      end
    end
    if preset_slot_data["scalar2"] then
      for property_name, data in pairs(preset_slot_data["scalar2"]) do
        result_data.property_overrides[property_name] = table.clone(data)
      end
    end
    if preset_slot_data["scalar3"] then
      for property_name, data in pairs(preset_slot_data["scalar3"]) do
        result_data.property_overrides[property_name] = table.clone(data)
      end
    end
    if preset_slot_data["scalar4"] then
      for property_name, data in pairs(preset_slot_data["scalar4"]) do
        result_data.property_overrides[property_name] = table.clone(data)
      end
    end
    if preset_slot_data["textures"] then
      for texture_slot, texture in pairs(preset_slot_data["textures"]) do
        result_data.texture_overrides[texture_slot] = { resource = texture }
      end
    end
  end

  return result_data
end
