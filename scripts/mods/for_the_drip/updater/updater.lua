local mod = get_mod("for_the_drip")

mod.update_available = false

local mod_folder = "./../mods/for_the_drip/scripts/mods/for_the_drip/"
local mod_files_url = "https://raw.githubusercontent.com/Adspartan/For_the_Drip/refs/heads/main/scripts/mods/for_the_drip/"


mod.get_current_version = function(self)
  return mod:io_read_content("for_the_drip/scripts/mods/for_the_drip/updater/version")
end

mod.download_lua_file = function(self, url, name)
  return Managers.backend:url_request(url, {
		require_auth = false,
	}):next(function(data) return data.body end, function() return false end)
end

mod.check_for_update = function(self)
  local current_version = mod:get_current_version()

  return mod:download_lua_file(mod_files_url.."updater/version.lua"):next(function(result)
    if result then
      local version = result

      if version ~= current_version then
        local c_split = string.split(current_version, ".")
        local r_split = string.split(version, ".")

        if c_split[1] == r_split[1] then
          if c_split[2] == r_split[2] then
            if tonumber(c_split[3]) < tonumber(r_split[3]) then
              mod.update_available = true
            end
          else
            if tonumber(c_split[2]) < tonumber(r_split[2]) then
              mod.update_available = true
            end
          end
        else
          if tonumber(c_split[1]) < tonumber(r_split[1]) then
            mod.update_available = true
          end
        end
      end
    else
      mod:echo("Error: Failed to retrieve version file.")
    end
  end)
end

mod.run_update_check = function(self)
  mod:check_for_update():next(function()
    if mod.update_available then
      Promise.delay(10):next(function() mod:echo("FTD Update available,\nuse the command /ftd_update to auto update on download it from https://github.com/Adspartan/For_the_Drip/releases/latest") end)
    end
  end)
end

mod.get_update_file_list = function()
  return mod:download_lua_file(mod_files_url.."updater/file_list.lua"):next(function(result)
    if not result then
      return nil
    else
      return Mods.lua.loadstring(result), name
    end
  end)
end

mod:command("ftd_update", "Update For the Drip", function()
  mod:check_for_update():next(function()
    if mod.update_available then
      mod:update_mod_files()
    else
      mod:echo("No update found")
    end
  end)
end)

mod.update_mod_files = function(self)
  mod:echo("Updating")

  mod:get_update_file_list():next(function(file_list)
    if file_list then
      local files_content = {}
      local dl_promises = {}
      local dl_failed = false

      for k, name in pairs(file_list) do
        dl_promises[#dl_promises + 1] = mod:download_lua_file(mod_files_url..name..".lua", name):next(function(content, name)
          if not content then
            dl_failed = true
          else
            files_content[name] = content
          end
        end)
      end

      Promise.all(unpack(dl_promises)):next(function()
        if not dl_failed then
          for name, content in pairs(files_content) do
            mod:override_mod_file(mod_folder..name..".lua", content)
          end

          mod:echo("New version: "..mod:get_current_version())
          mod:echo("You can now reload your mods or restart the game !")

          mod.update_available = false
        else
          mod:echo("Error: failed to download one or more files, update aborted.")
        end
      end)
    else
      mod:echo("Error: failed to retrieve file list.")
    end
  end)
end
