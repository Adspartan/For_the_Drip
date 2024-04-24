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

local directory = nil

mod.setup_output_folder = function()
  directory = _os.getenv('APPDATA').."/Fatshark/Darktide/for_the_drip/"
  _os.execute("mkdir " .. "\"" .. directory .. "\" 2>nul")
end

mod.append_to_file = function(line, filename)
  if not line or not filename then
    return
  end

  local file = assert(_io.open(directory .. filename .. ".txt", "a"))

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

  local file = assert(_io.open(directory .. filename .. ".txt", mode))

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

  local file = assert(_io.open(directory .. filename .. ".txt", mode))

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

  local file = assert(_io.open(directory .. filename .. ".txt", mode))

  file:write(table.tostring(t, depth).."\n")

  file:close()
end

mod.file_exist = function(file)
  local f = _io.open(directory..file, "r")

  if f then
    _io.close(f)
    return true
  end

  return false
end

mod.read_all_lines = function(file)
  return _io.lines(directory..file)
end
