local mod = get_mod("for_the_drip")
local dmf = get_mod("DMF")

local _io = dmf:persistent_table("_io")
_io.initialized = _io.initialized or false
if not _io.initialized then
  _io = dmf.deepcopy(Mods.lua.io)
end

local _os = dmf:persistent_table("_os")
_os.initialized = _os.initialized or false
if not _os.initialized then
  _os = dmf.deepcopy(Mods.lua.os)
end

mod.setup_output_folder = function()
  local settings_folder = mod:get("output_folder")

  if settings_folder and settings_folder ~= "" then
    mod:persistent_table("data").directory = settings_folder
  else
    mod:persistent_table("data").directory = _os.getenv('APPDATA').."/Fatshark/Darktide/for_the_drip/"
  end

  mod:create_output_directory()
end

mod.create_output_directory = function()
  _os.execute("mkdir " .. "\"" .. mod:persistent_table("data").directory .. "\" 2>nul")
end

mod.append_to_file = function(line, filename)
  if not line or not filename then
    return
  end

  local file = assert(_io.open(mod:persistent_table("data").directory .. filename .. ".txt", "a"))

  file:write(line.."\n")
  file:close()
end

mod.dump_table_keys_to_file = function(table, filename, append)
  if not table or not filename then
    return
  end

  local mode = "w+"

  if append then
    mode = "a"
  end

  local file = assert(_io.open(mod:persistent_table("data").directory .. filename .. ".txt", mode))

  for key,_  in pairs(table) do
    file:write(key.."\n")
  end

  file:close()
end

mod.dump_table_values_to_file = function(table, filename, append)
  if not table or not filename then
    return
  end

  local mode = "w+"

  if append then
    mode = "a"
  end

  local file = assert(_io.open(mod:persistent_table("data").directory .. filename .. ".txt", mode))

  for k,v  in pairs(table) do
    file:write(v.."\n")
  end

  file:close()
end

mod.dump_table_to_file = function(self, t, depth, filename, append)
  if not table or not filename then
    return
  end

  local mode = "w+"

  if append then
    mode = "a"
  end

  local file = assert(_io.open(mod:persistent_table("data").directory .. filename .. ".lua", mode))

  file:write(mod:table_tostring(t, depth).."\n")

  file:close()
end

mod.file_exist = function(file)
  local f = _io.open(mod:persistent_table("data").directory..file, "r")

  if f then
    _io.close(f)
    return true
  end

  return false
end

mod.read_all_lines = function(file)
  return _io.lines(mod:persistent_table("data").directory..file)
end


mod.save_table_to_file = function(data, filename)
  local file,err =_io.open(mod:persistent_table("data").directory..filename..".lua", "wb")

  if err then
    mod:echo("Failed to save file: '"..filename"' error: "..err)
    return err
  end

  file:write(mod:table_tostring(data, 10))
  file:close()
end

local _loadstring = Mods.lua.loadstring

mod.load_lua_file = function(filename)
  local f = assert(_io.open(mod:persistent_table("data").directory..filename..".lua", "r"))
  local content = f:read("*all")
  f:close()

  local func = _loadstring("local t ="..content.."\nreturn t")

  if func then
    return func()
  else
    mod:echo("Failed to load file '"..filename.."'")
  end
end


mod.override_mod_file = function(self, filepath, content)
  local file = assert(_io.open(filepath, "w+"))
  file:write(content)
  file:close()
end
