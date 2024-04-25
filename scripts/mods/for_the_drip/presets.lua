local mod = get_mod("for_the_drip")

local ItemMaterialOverrides = require("scripts/settings/equipment/item_material_overrides/item_material_overrides")

mod.default_slot_data = function()
  return {
    slot_gear_head = {},
    slot_gear_upperbody = {},
    slot_gear_lowerbody = {},
    slot_gear_extra_cosmetic = {},
    slot_primary = {},
    slot_secondary = {},
    gear_customization_data = {},
    shirtless = false,
    pantless = false
  }
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
    if not string.match(slot, "slot_") and slot ~= "gear_customization_data" then
      if str ~= "" then
        str = str.."###"
      end
      str = str..slot.."###"..tostring(slot_data)
    elseif slot ~= "gear_customization_data" then
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
    end
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

local loadout_from_str = function(str)
  local st_1 = nil
  local st_2 = nil

  if string.find(str, "#####") then
    local tab = mod:split_str(str, "#####")
    st_1 = tab[1]
    st_2 = tab[2]
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
        loadout[slot] = data == "true"
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

  return loadout
end


mod.load_preset = function(id)
  local data = mod.saved_looks[id]

  if data then
    mod:reset_all_gear_slots() -- to clear out customizations
    mod.current_slots_data = table.clone(data)
    mod:save_current_loadout()
    mod:refresh_all_gear_slots()
  end
end

mod.save_loadout_to_current_char = function()
  local id = mod:persistent_table("data").character_id

  if id then
    mod.character_slots_data[id] = table.clone(mod.current_slots_data)
  end
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

mod.load_saved_loadouts = function(self)
  mod.saved_looks = {}

  if mod.file_exist("loadouts.txt") then
    local lines = mod.read_all_lines("loadouts.txt")

    for line in lines do
      if line ~= "" then
        local preset = table.clone(loadout_from_str(line))
        local id = tostring(mod.max_preset_id+1)
        preset.id = preset.id or id

        if tonumber(preset.id) > mod.max_preset_id then
          mod.max_preset_id = tonumber(preset.id)
        end

        preset.name = preset.name or ("Preset "..id)

        mod.saved_looks[preset.id] = preset
      end
    end
  end
end

mod.load_current_character_loadout = function()
  local id = mod:persistent_table("data").character_id

  local player = Managers.player:local_player_safe(1)

  if player then
    id = player:character_id()

    if id then
      mod:persistent_table("data").character_id = id
      mod:load_character_loadout(id)
    end
  end
end

mod.load_character_loadout = function(self, id)
  if not mod.character_slots_data[id] then
    if id and mod.file_exist("loadout_"..id..".txt") then
      for line in mod.read_all_lines("loadout_"..id..".txt") do
        mod.current_slots_data = table.clone(loadout_from_str(line))
        mod.character_slots_data[id] = table.clone(mod.current_slots_data)
        break
      end
    else
      mod.current_slots_data = mod:default_slot_data()

      if id then
        mod.character_slots_data[id] = mod:default_slot_data()
      end
    end
  else
    mod.current_slots_data = table.clone(mod.character_slots_data[id])
  end
end


mod.deleted_selected_preset = function()
  if mod.selected_preset ~= "none" then
    local temp = {}

    for id,preset in pairs(mod.saved_looks) do
      if id ~= mod.selected_preset then
        temp[id] = preset
      end
    end

    mod:echo(mod.selected_preset_name.. " has been deleted")

    mod.saved_looks = table.clone(temp)
    mod.selected_preset = "none"
    mod.selected_preset_name = "none"

    mod:save_loadouts_to_file()
  end
end

mod.override_selected_preset = function()
  if mod.selected_preset ~= "none" then
    local id = mod.saved_looks[mod.selected_preset].id
    local name = mod.saved_looks[mod.selected_preset].name

    mod.saved_looks[mod.selected_preset] = table.clone(mod.current_slots_data)
    mod.saved_looks[mod.selected_preset].id = id
    mod.saved_looks[mod.selected_preset].name = name

    mod:echo(mod.selected_preset_name.. " has been overridden")

    mod:save_loadouts_to_file()
  end
end

mod.save_current_look = function()
  mod.max_preset_id = mod.max_preset_id + 1
  local index = tostring(mod.max_preset_id)
  mod.saved_looks[index] = table.clone(mod.current_slots_data)
  mod.saved_looks[index].id = index
  mod.saved_looks[index].name = "Preset "..index

  mod:echo("Preset ".. index.. " saved")

  mod:save_loadouts_to_file()
end

mod.save_loadouts_to_file = function()
  local data = {}

  for k,v in pairs(mod.saved_looks) do
    table.insert(data, loadout_to_string(v))
  end

  mod.dump_table_values_to_file(data, "loadouts", false)
  mod:save_current_loadout()
end

mod.save_current_loadout = function()
  local data = {loadout_to_string(mod.current_slots_data)}
  mod.dump_table_values_to_file(data, "current_loadout", false)

  local id = mod:persistent_table("data").character_id
  if id then
    mod.dump_table_values_to_file(data, "loadout_"..id, false)
    mod.character_slots_data[id] = table.clone(mod.current_slots_data)
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
