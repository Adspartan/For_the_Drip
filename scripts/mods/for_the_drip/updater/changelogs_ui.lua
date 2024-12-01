local mod = get_mod("for_the_drip")

local ChangelogsUI = class("ChangelogsUI")

--local changelogs = ChangelogsUI:new()
local changelogs_window = nil

mod.parse_changelogs = function(self)
  changelogs_window = ChangelogsUI:new()
end


local function compare_versions(a, b)
  local ta = string.split(a, ".")
  local tb = string.split(b, ".")

  if ta[1] ~= tb[1] then
    return tonumber(ta[1]) > tonumber(tb[1])
  else
    if ta[2] ~= tb[2] then
      return tonumber(ta[2]) > tonumber(tb[2])
    else
      return tonumber(ta[3]) > tonumber(tb[3])
    end
  end
end

ChangelogsUI.init = function(self)
  self._show = false

  local file_content = mod:io_read_content("for_the_drip/scripts/mods/for_the_drip/updater/changelogs")

  if file_content then
    self._changelogs = (Mods.lua.loadstring(file_content)())
    self._versions = {}
    self._versions_header = {}

    for version, data in pairs(self._changelogs) do
      self._versions[#self._versions + 1] = version
      self._versions_header[version] = false
    end

    table.sort(self._versions, compare_versions)
  end
end

ChangelogsUI.render = function(self)
  for k, v in pairs(self._versions) do
    self._versions_header[v] = Imgui.collapsing_header("Version "..v, false)

    if self._versions_header[v] then
      local content = self._changelogs[v]

      if type(content) == "string" then
        Imgui.text("  - "..content)
      else
        for key, value in pairs(content) do
          if type(key) == "number" then
            Imgui.text("  - "..value)
          else
            Imgui.text("  - "..key)

            for sk, sv in pairs(value) do
              Imgui.text("    - "..sv)
            end
          end
        end
      end
    end
  end
end

ChangelogsUI.collapse_header = function(self)
  for k, v in pairs(self._versions_header) do
    self._versions_header[k] = false
  end
end

local reset_pos = false
local first_display = true

mod.reset_changelogs_ui_pos = function()
  reset_pos = true
end

mod.update_changelogs_ui = function(self)
  if changelogs_window and changelogs_window._show then
    if reset_pos then
      Imgui.set_next_window_pos(200,25)
    end

    if first_display then
      Imgui.set_next_window_size(500 * mod.font_scale, 700)
      Imgui.set_next_window_pos(400,100)

      first_display = false
    end

    local _, closed = Imgui.begin_window("For the Drip Changelogs")
    Imgui.set_window_font_scale(mod.font_scale)

    if closed then
      changelogs_window._show = false
      changelogs_window:collapse_header()
    else
      changelogs_window:render()
    end

    Imgui.end_window()
  end
end

mod.close_changelogs_ui = function(self)
  if changelogs_window then
    changelogs_window._show = false
    changelogs_window:collapse_header()
  end
end

mod.toggle_changelogs_ui = function(self)
  if changelogs_window then
    if changelogs_window._show then
      changelogs_window._show = false
      changelogs_window:collapse_header()
    else
      changelogs_window._show = true
    end
  end
end



