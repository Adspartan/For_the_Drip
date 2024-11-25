local mod = get_mod("for_the_drip")

local NavigationCombo = class("NavigationCombo")

mod.create_nav_combo = function(self, title, elements, initial_value, value_changed_cb)
  return NavigationCombo:new(title, elements, initial_value, value_changed_cb)
end

mod.on_mask_changed = function()
  if mod:get("apply_masks_on_change") then
    mod:save_current_loadout()
    mod:refresh_all_gear_slots()
  end
end

NavigationCombo.init = function(self, title, elements, initial_value, value_changed_cb)
  self._title = title
  self._elements = table.clone(elements)
  self._max_index = #elements
  self._value = initial_value
  self._value_changed_cb = value_changed_cb

  self._index = 0

  for k,v in pairs(elements) do
    if v == initial_value then
      self._index = k
      break
    end
  end
end

NavigationCombo.reset_selection = function(self)
  self._index = 1
  self._value = self._elements[1]

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
