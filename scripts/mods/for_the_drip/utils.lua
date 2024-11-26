local mod = get_mod("for_the_drip")

mod.split_str = function(self, str, sep)
  if sep == '' then return {str} end

  local res, from = {}, 1

  repeat
    local pos = str:find(sep, from)
    res[#res + 1] = str:sub(from, pos and pos - 1)
    from = pos and pos + #sep
  until not from

  return res
end

string.starts_with_any = function(str, ...)
  local t = {...}

  for k, v in pairs(t) do
    if string.starts_with(str, v) then
      return true
    end
  end

  return false
end

string.contains_any = function(str, ...)
  local t = {...}

  for k, v in pairs(t) do
    if string.find(str, v) then
      return true
    end
  end

  return false
end

mod.shorten_item_name = function(self, name)
  if not name then
    return "<nil>"
  end

  if name == "" then
    return name
  end

  local t = string.split(name, "/")

  return t[#t]
end

mod.get_highest_attachment_id = function(self, item)
  local ids = {0,}

  for name, data in pairs(item.attachments or {}) do
    table.insert(ids, tonumber(string.split(name, "_")[2]))
  end

  return math.max(unpack(ids))
end

mod.get_visual_loadout_extension = function()
  local player = Managers.player:local_player_safe(1)

  if player then
    return ScriptUnit.extension(player.player_unit, "visual_loadout_system")
  end

  return nil
end

-- customized table.tostring functions (functions and (rec-limit) mess with the text editor)
local _value_to_string_array, _table_tostring_array = nil

function _value_to_string_array(v, depth, max_depth, skip_private, sort_keys)
  if type(v) == "table" then
    if depth <= max_depth then
      return _table_tostring_array(v, depth + 1, max_depth, skip_private, sort_keys)
    else
      return {
        "\"(rec-limit)\""
      }
    end
  elseif type(v) == "string" then
    return {
      "\"",
      v,
      "\""
    }
  else
    return {
      tostring(v)
    }
  end
end

function _table_tostring_array(t, depth, max_depth, skip_private, sort_keys)
  local str = {
    "{\n"
  }
  local last_tabs = string.rep("\t", depth - 1)
  local tabs = last_tabs .. "\t"
  local len = #t

  for i = 1, len do
    str[#str + 1] = tabs

    table.append(str, _value_to_string_array(t[i], depth, max_depth, skip_private, sort_keys))

    str[#str + 1] = ",\n"
  end

  local string_key_count = 0
  local string_keys = {}

  for key, value in pairs(t) do
    local key_type = type(key)
    local is_string = key_type == "string"
    local is_number = key_type == "number"
    local is_function = key_type == "function"

    if key == "set_temporary_overrides" then
    --  Nothing
    elseif is_string and skip_private and key:sub(1, 1) == "_" then
      -- Nothing
    elseif is_number and key > 0 and key <= len then
      -- Nothing
    elseif is_string then
      string_keys[string_key_count + 1] = key
      string_key_count = string_key_count + 1
    elseif is_function then
      string_keys[string_key_count + 1] = "\"[function]\""
      string_key_count = string_key_count + 1
    else
      local key_str = nil

      if is_number then
        key_str = string.format("[%i]", key)
      else
        key_str = tostring(key)
      end

      str[#str + 1] = tabs
      str[#str + 1] = key_str
      str[#str + 1] = " = "

      table.append(str, _value_to_string_array(value, depth, max_depth, skip_private, sort_keys))

      str[#str + 1] = ",\n"
    end
  end

  if sort_keys then
    table.sort(string_keys)
  end

  for i = 1, string_key_count do
    local key_str = string_keys[i]
    local value = t[key_str]
    str[#str + 1] = tabs
    str[#str + 1] = "[\""..key_str.."\"]"
    str[#str + 1] = " = "

    table.append(str, _value_to_string_array(value, depth, max_depth, skip_private, sort_keys))

    str[#str + 1] = ",\n"
  end

  str[#str + 1] = last_tabs
  str[#str + 1] = "}"

  return str
end

mod.table_tostring = function (self, t, max_depth, skip_private, sort_keys)
  return table.concat(_table_tostring_array(t, 1, max_depth or 1, skip_private, sort_keys ~= false))
end
