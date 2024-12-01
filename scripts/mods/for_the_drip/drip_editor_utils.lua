local mod = get_mod("for_the_drip")

mod.window_position = {}

mod.check_current_window_dimensions = function(window_id)
  if not window_id then
    return
  end

  local x,y = Imgui.get_window_pos()
  local w,h = Imgui.get_window_size()

  local screen_w = RESOLUTION_LOOKUP.width
  local screen_h = RESOLUTION_LOOKUP.height

  local shift_x = 0
  local shift_y = 0
  local need_relocate = false

  if (x+w) > (screen_w - 5)  then
    shift_x = screen_w - (x+w) - 5
    need_relocate = true
  elseif x < 10 then
    shift_x = 10
    need_relocate = true
  end

  if (y+h) > (screen_h - 5) then
    shift_y = screen_h - (y+h) - 5
    need_relocate = true
  elseif y < 10 then
    shift_y = 10
    need_relocate = true
  end

  --
  if w > (screen_w - 20) or h > (screen_h - 20) then
    mod:reset_window_pos()
  end

  mod.window_position[window_id] =
  {
    ["px"] = (x + shift_x),
    ["py"] = (y  + shift_y),
    ["need_relocate"] = need_relocate,
  }
end

mod.move_next_window = function(window_id)
  if window_id and mod.window_position[window_id] and mod.window_position[window_id].need_relocate then
    Imgui.set_next_window_pos(mod.window_position[window_id].px, mod.window_position[window_id].py)
    mod.window_position[window_id].need_relocate = false
  end
end

mod.on_mask_changed = function()
  if mod:get("apply_masks_on_change") then
    mod:save_current_loadout()
    mod:refresh_all_gear_slots()
  end
end


local NavigationCombo = class("NavigationCombo")

mod.create_nav_combo = function(self, title, elements, initial_value, value_changed_cb, reset_value)
  return NavigationCombo:new(title, elements, initial_value, value_changed_cb, reset_value)
end

NavigationCombo.init = function(self, title, elements, initial_value, value_changed_cb, reset_value)
  self._title = title
  self._elements = table.clone(elements)
  self._max_index = #elements
  self._value = initial_value
  self._value_changed_cb = value_changed_cb
  self._reset_value = reset_value

  self._index = 0

  for k,v in pairs(elements) do
    if v == initial_value then
      self._index = k
      break
    end
  end
end

NavigationCombo.reset_selection = function(self)
  if self._reset_value then
    self._index = 0
    self._value = self._reset_value
  else
    self._index = 1
    self._value = self._elements[1]
  end

  self:on_value_changed()
end

NavigationCombo.display = function(self)
  if Imgui.begin_combo(self._title, self._value) then
    for k,v in pairs(self._elements) do
      if Imgui.selectable(v, v == self._value) then
        self._index = k
        self._value = v

        self:on_value_changed()
      end
    end

    Imgui.end_combo()
  end

  Imgui.same_line()
  Imgui.spacing()
  Imgui.same_line()

  if Imgui.button("<##previous_"..self._title) then
    if self._index > 1 then
      self._index = self._index - 1
    else
      self._index = #self._elements
    end

    self._value = self._elements[self._index]
    self:on_value_changed()
  end

  Imgui.same_line()

  if Imgui.button(">##next_"..self._title) then
    self._index = self._index + 1

    if self._index > #self._elements then
      self._index = 1
    end

    self._value = self._elements[self._index]
    self:on_value_changed()
  end

  Imgui.same_line()

  if Imgui.button("reset##reset_"..self._title) then
    self:reset_selection()
  end

  return self._value
end

NavigationCombo.on_value_changed = function(self)
  if self._value_changed_cb then
    self._value_changed_cb()
  end
end

--------------------------
--- FilterNavigationCombo

local FilterNavigationCombo = class("FilterNavigationCombo")

mod.create_filter_nav_combo = function(self, title, elements, initial_value, value_changed_cb)
  return FilterNavigationCombo:new(title, elements, initial_value, value_changed_cb)
end

FilterNavigationCombo.init = function(self, title, elements, initial_value, value_changed_cb)
  self._title = title
  self._elements = table.clone(elements)
  self._current_elements = table.clone(elements)
  self._max_index = #elements
  self._value = initial_value
  self._value_changed_cb = value_changed_cb
  self._filter = ""
  self._preview_value = ""

  self._index = 0

  for k,v in pairs(elements) do
    if v == initial_value then
      self._index = k
      break
    end
  end
end

FilterNavigationCombo.display = function(self)
  local filter = self._filter

  Imgui.spacing()
  Imgui.same_line()
  self._filter = Imgui.input_text("Filter", self._filter)

  if self._filter ~= filter then
    self:update_filtered_values()
  end

  Imgui.same_line()
  Imgui.spacing()
  Imgui.same_line()

  if Imgui.button("clear##clear_filter_"..self._title) then
    self._filter = ""
    self:update_filtered_values()
  end

  Imgui.spacing()
  Imgui.same_line()

  if Imgui.begin_combo(self._title, self._value) then
    for k,v in pairs(self._current_elements) do
      if Imgui.selectable(v, v == self._value) then
        self._index = k
        self._value = v

        self:on_value_changed()
      end
    end

    Imgui.end_combo()
  end

  Imgui.same_line()
  Imgui.spacing()
  Imgui.same_line()

  if Imgui.button("<##previous_"..self._title) then
    if self._index > 1 then
      self._index = self._index - 1
    else
      self._index = #self._current_elements
    end

    self._value = self._current_elements[self._index]
    self:on_value_changed()
  end

  Imgui.same_line()

  if Imgui.button(">##next_"..self._title) then
    self._index = self._index + 1

    if self._index > #self._current_elements then
      self._index = 1
    end

    self._value = self._current_elements[self._index]
    self:on_value_changed()
  end

  Imgui.same_line()

  if Imgui.button("reset##reset_"..self._title) then
    self:reset_selection()
    self:on_value_changed()
  end

  Imgui.spacing()
  Imgui.same_line()
  Imgui.text("Attachment: "..self._index.."/"..(#self._current_elements).."   "..self._preview_value)

  return self._value
end

FilterNavigationCombo.reset_selection = function(self)
  self._index = 0
  self._value = ""

  self:on_value_changed()
end

FilterNavigationCombo.reset_filter = function(self)
  self._filter = ""

  self:update_filtered_values()
end

FilterNavigationCombo.update_filtered_values = function(self)
  if (not self._filter) or self._filter == "" then
    self._current_elements = table.clone(self._elements)
  else
    self._current_elements = {}

    for k,v in pairs(self._elements) do
      if string.find(v, self._filter) then
        self._current_elements[#self._current_elements + 1] = v
      end
    end
  end

  self._index = 0

  for k,v in pairs(self._current_elements) do
    if v == self._value then
      self._index = k
      break
    end
  end
end

FilterNavigationCombo.on_value_changed = function(self)
  self._preview_value = mod:shorten_item_name(self._value)

  if self._value_changed_cb then
    self._value_changed_cb()
  end
end
