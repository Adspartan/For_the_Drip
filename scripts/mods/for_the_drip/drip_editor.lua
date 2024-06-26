local mod = get_mod("for_the_drip")

local ItemMaterialOverrides = require("scripts/settings/equipment/item_material_overrides/item_material_overrides")
local FixedFrame = require("scripts/utilities/fixed_frame")
local MasterItems = require("scripts/backend/master_items")
local Promise = require("scripts/foundation/utilities/promise")

local show_editor = false
local reset_ingui_pos = false

local materials_header_open = true
local slot_selection_header = true
local options_header = true
local body_options_header = true
local presets_header = true
local unit_header = true

mod.reset_window_pos = function()
  reset_ingui_pos = true
end

-- todo: checkbox or toggle in the settings
mod:hook("UIManager", "using_input", function(func, ...)
  return show_editor or func(...)
end)

local ImguiDripEditor = class("ImguiDripEditor")
local editor = ImguiDripEditor:new()

ImguiDripEditor.open = function(self)
  if not Managers.input:cursor_active() then
    Managers.input:push_cursor(self.__class_name)
  end

  show_editor = true
  Imgui.open_imgui()
end

ImguiDripEditor.update = function(self)
  if reset_ingui_pos then
    -- close headers
    materials_header_open = false
    slot_selection_header = false
    options_header = false
    body_options_header = false
    presets_header = false
    unit_header = false

    reset_ingui_pos = false
    Imgui.set_next_window_pos(25,25)
  end

  local _, closed = Imgui.begin_window("Drip Editor", "always_auto_resize")

  if closed then
    self:close()
  else
    self:ui_content()
  end

  Imgui.end_window()
end

mod.selected_color_material = "none"
mod.selected_pattern_material = "none"
mod.selected_gear_material = "none"
mod.selected_preset = "none"
mod.selected_preset_name = "none"
mod.attachment_filter = ""
mod.selected_attachment_index = 0
local selected_preset_index = 0

local color_index = 1
local pattern_index = 1
local gear_index = 1

mod.slots_selection_status = {}

local reset_selected_slots = false

local apply_changes = function()
  local player = Managers.player:local_player_safe(1)

  for slot, checked in pairs(mod.slots_selection_status) do
    if checked then
      if reset_selected_slots then
        mod:reset_slot(slot)
      end

      if mod.selected_color_material ~= "none" then
        mod.apply_mat_to_slot(slot, mod.selected_color_material)
      end
      if mod.selected_pattern_material ~= "none" then
        mod.apply_mat_to_slot(slot, mod.selected_pattern_material)
      end
      if mod.selected_gear_material ~= "none" then
        mod.apply_mat_to_slot(slot, mod.selected_gear_material)
      end

      if slot == "slot_primary" or slot == "slot_secondary" then
        mod:apply_customization_to_back_weapons(player.player_unit, slot)
      end
    end
  end

  mod:save_current_loadout()
end

local apply_changes_on_change = function()
  if mod:get("apply_mat_on_index_change") then
    apply_changes()
  end
end

mod.selected_unit_slot = "none"
mod.selected_extra_attach = ""
mod.selected_hair_color_index = 1

ImguiDripEditor.body_customization_ui = function(self)
  local x = Imgui.get_window_size()
  local data = mod.current_slots_data.body_customization_data

  if (not data) or type(data) == "string" then
    mod.current_slots_data.body_customization_data = {}
    data = mod.current_slots_data.body_customization_data
  end

  if data.use_custom_hair_color == nil then
    data["use_custom_hair_color"] = false
    data["custom_hair_color"] = ""
  end

  body_options_header = Imgui.collapsing_header("Body Options", body_options_header)

  if body_options_header == false then
    return
  end

  if not data["shirtless"] then
    data["shirtless"] = false
  end
  if not data["pantless"] then
    data["pantless"] = false
  end

  Imgui.spacing()
  Imgui.same_line()
  data["shirtless"] = Imgui.checkbox("Shirtless ", data["shirtless"])
  Imgui.same_line()
  Imgui.spacing()
  Imgui.same_line()
  data["pantless"] = Imgui.checkbox("Pantless", data["pantless"])

  Imgui.spacing()
  Imgui.same_line()

  data.use_custom_hair_color = Imgui.checkbox("Use Custom Hair Color", data.use_custom_hair_color)

  if data.use_custom_hair_color then
    Imgui.spacing()
    Imgui.same_line()

    if Imgui.begin_combo("Hair Color", data.custom_hair_color) then
      for k,v in pairs(mod.available_colors) do
        if Imgui.selectable(v, v == data.custom_hair_color) then
          mod.selected_hair_color_index = k
          data.custom_hair_color = v
        end
      end

      Imgui.end_combo()
    end

    Imgui.same_line()
    Imgui.spacing()
    Imgui.same_line()

    if Imgui.button("<##hair_color") then
      mod.selected_hair_color_index = mod.selected_hair_color_index - 1

      if mod.selected_hair_color_index <= 0 then
        mod.selected_hair_color_index = #mod.available_colors
      end

      data.custom_hair_color = mod.available_colors[mod.selected_hair_color_index]
      mod:save_current_loadout()
      mod:refresh_all_gear_slots()
    end

    Imgui.same_line()

    if Imgui.button(">##hair_color") then
      mod.selected_hair_color_index = mod.selected_hair_color_index + 1

      if mod.selected_hair_color_index > #mod.available_colors then
        mod.selected_hair_color_index = 1
      end

      data.custom_hair_color = mod.available_colors[mod.selected_hair_color_index]
      mod:save_current_loadout()
      mod:refresh_all_gear_slots()
    end
  end

  Imgui.spacing()
  Imgui.same_line()

  if Imgui.button("Apply##body_option_btn", x-35) then
    mod:save_current_loadout()
    mod:refresh_all_gear_slots()
  end
end

ImguiDripEditor.slot_customization_ui = function(self)
  local x = Imgui.get_window_size()

  unit_header = Imgui.collapsing_header("Slot Customization", unit_header)

  if unit_header == false then
    return
  end

  Imgui.spacing()
  Imgui.same_line()

  local visual_loadout_extension = mod:get_visual_loadout_extension()

  if Imgui.begin_combo("Slot##customizable_slot_btn", mod.selected_unit_slot) then
    local old_selected_slot = mod.selected_unit_slot

    for k,slot in pairs(mod.customizable_slots) do
      if Imgui.selectable(slot, slot == mod.selected_unit_slot)  then
        mod.selected_unit_slot = slot

        if old_selected_slot ~= slot then
          mod:reset_selected_attachment()

          if old_selected_slot ~= "none" then
            if old_selected_slot == "slot_gear_head" then
              mod:refresh_slot("slot_body_face")
            else
              mod:refresh_slot(old_selected_slot)
            end
          end
        end

        if slot ~= "none" then
          if visual_loadout_extension then
            if slot == "slot_gear_head" then
              mod:load_slot_data(visual_loadout_extension._equipment["slot_body_face"])
            else
              mod:load_slot_data(visual_loadout_extension._equipment[slot])
            end
          end
        end
      end
    end
    Imgui.end_combo()
  end

  if mod.selected_unit_slot ~= "none" and visual_loadout_extension then
    local item = mod:get_slot_item(mod.selected_unit_slot)

    if item then
      local data = mod.current_slots_data.gear_customization_data[item.name]

      if data then
        if mod.selected_unit_slot == "slot_gear_upperbody" then
          Imgui.spacing()
          Imgui.same_line()
          data.hide_body = Imgui.checkbox("Hide Body##hide_body_btn", data.hide_body)

          Imgui.same_line()

          if Imgui.begin_combo("Body Mask", data.mask_torso) then
            for k,mask in pairs(mod.masks_per_slots.slot_body_torso) do
              if Imgui.selectable(mask, mask == data.mask_torso) then
                data.mask_torso = mask
              end
            end

            Imgui.end_combo()
          end


          Imgui.spacing()
          Imgui.same_line()

          data.hide_arms = Imgui.checkbox("Hide Arms##hide_arms_btn", data.hide_arms)
          Imgui.same_line()

          if Imgui.begin_combo("Arms Mask",data.mask_arms) then
            for k,mask in pairs(mod.masks_per_slots.slot_body_arms) do
              if Imgui.selectable(mask, mask == data.mask_arms) then
              data.mask_arms = mask
              end
            end

            Imgui.end_combo()
          end

          Imgui.separator()
        end

        if mod.selected_unit_slot == "slot_gear_lowerbody" then
          Imgui.spacing()
          Imgui.same_line()
          data.hide_legs = Imgui.checkbox("Hide Legs##hide_legs_btn", data.hide_legs)

          Imgui.same_line()

          if Imgui.begin_combo("Legs Mask",data.mask_legs) then
            for k,mask in pairs(mod.masks_per_slots.slot_body_legs) do
              if Imgui.selectable(mask, mask == data.mask_legs) then
              data.mask_legs = mask
              end
            end

            Imgui.end_combo()
          end

          Imgui.separator()
        end

        if mod.selected_unit_slot == "slot_gear_head" then
          if data.hide_hair == nil then
            data.hide_hair = mod:current_head_gear_hide_hair()
          end
          if data.mask_face == nil then
            data.mask_face = mod:current_head_gear_mask_face()
          end

          Imgui.spacing()
          Imgui.same_line()
          data.hide_hair = Imgui.checkbox("Hide Hair##hide_hair_btn", data.hide_hair)
          Imgui.same_line()
          Imgui.spacing()
          Imgui.same_line()
          data.hide_beard = Imgui.checkbox("Hide Beard##hide_beard_btn", data.hide_beard)
          Imgui.same_line()
          Imgui.spacing()
          Imgui.same_line()
          data.hide_eyebrows = Imgui.checkbox("Hide Eyebrows##hide_eyebrows_btn", data.hide_eyebrows)
          Imgui.spacing()
          Imgui.same_line()

          if Imgui.begin_combo("Face Mask", data.mask_face) then
            for k,mask in pairs(mod.face_masks) do
              if Imgui.selectable(mask, mask == data.mask_face) then
                data.mask_face = mask
              end
            end

            Imgui.end_combo()
          end

          Imgui.spacing()
          Imgui.same_line()

          if Imgui.begin_combo("Hair Mask", data.mask_hair) then
            if mod:persistent_table("data").breed == "ogryn" then
              for k,mask in pairs(mod.ogryn_hair_masks) do
                if Imgui.selectable(mask, mask == data.mask_hair) then
                data.mask_hair = mask
                end
              end
            else
              for k,mask in pairs(mod.human_hair_masks) do
                if Imgui.selectable(mask, mask == data.mask_hair) then
                data.mask_hair = mask
                end
              end
            end

            Imgui.end_combo()
          end

          Imgui.spacing()
          Imgui.same_line()

          if Imgui.begin_combo("Face Hair Mask", data.mask_facial_hair) then
            if mod:persistent_table("data").breed == "ogryn" then
              for k,mask in pairs(mod.ogryn_face_hair_masks) do
                if Imgui.selectable(mask, mask == data.mask_hair) then
                data.mask_hair = mask
                end
              end
            else
              for k,mask in pairs(mod.human_face_hair_masks) do
                if Imgui.selectable(mask, mask == data.mask_hair) then
                data.mask_hair = mask
                end
              end
            end

            Imgui.end_combo()
          end

          Imgui.separator()
        end

        data.custom_attachment_mats = false

        if data.attachments then
          for item, attach_customization in pairs(data.attachments) do
            Imgui.spacing()
            Imgui.same_line()
            attach_customization.is_visible = Imgui.checkbox(mod:shorten_item_name(item).."##"..mod.selected_unit_slot, attach_customization.is_visible)

            if attach_customization.is_visible then
              Imgui.same_line()
              attach_customization.customize = Imgui.checkbox("Customize##"..attach_customization.name..mod.selected_unit_slot, attach_customization.customize)

              if attach_customization.customize == false then
                data.custom_attachment_mats = true
              end
            else
              data.custom_attachment_mats = true
            end


            if attach_customization.is_extra then
              Imgui.same_line()
              Imgui.spacing()
              Imgui.same_line()

              if Imgui.button("x##custom_attach_del_"..attach_customization.name) then
                if mod:remove_custom_attachment(data.item, attach_customization.name, item) and mod:get("apply_mat_on_index_change") then
                  mod:save_current_loadout()
                  mod:refresh_all_gear_slots()
                end
              end
            end
          end
        end

        if mod.attachment_per_slot_per_breed then
          Imgui.separator()
          Imgui.spacing()
          Imgui.same_line()

          local old_filter = mod.attachment_filter
          mod.attachment_filter = Imgui.input_text("Filter", mod.attachment_filter)

          if old_filter ~= mod.attachment_filter then
            mod.selected_attachment_index = 0
          end

          Imgui.spacing()
          Imgui.same_line()

          if Imgui.begin_combo("Extra Attachment", mod.selected_extra_attach) then
            local breed = mod:persistent_table("data").breed
            local t = mod.attachment_per_slot_per_breed[breed] and mod.attachment_per_slot_per_breed[breed][mod.selected_unit_slot] or {}

            local index = 0

            for k, attach in pairs(t) do
              if mod.attachment_filter == "" or string.find(attach, mod.attachment_filter) then
                index = index + 1

                if Imgui.selectable(attach, attach == mod.selected_extra_attach) then
                  mod.selected_attachment_index = index
                  mod:preview_attachment(attach)
                end
              end
            end

            Imgui.end_combo()
          else
            Imgui.same_line()
            Imgui.spacing()
            Imgui.same_line()

            if Imgui.button("<##previous_attachment_btn") then
              if mod.selected_attachment_index > 1 then
                mod.selected_attachment_index = mod.selected_attachment_index - 1
                mod:update_preview_attachment_index()
              end
            end

            Imgui.same_line()

            if Imgui.button(">##next_attachment_btn") then
              mod.selected_attachment_index = mod.selected_attachment_index + 1
              mod:update_preview_attachment_index()
            end

            Imgui.same_line()
            Imgui.spacing()
            Imgui.same_line()

            if Imgui.button("x##clear_attach_name") then
              mod:reset_selected_attachment()
            end
          end
        end

        if mod.selected_extra_attach ~= "" then
          Imgui.spacing()
          Imgui.same_line()

          if Imgui.button("Add Attachment", x-35) then
            if not data.attachments then
              data.attachments = {}
            end

            data.attachments[mod.selected_extra_attach] = mod:make_extra_attach_data(mod.selected_extra_attach, item)
            mod:save_current_loadout()

            mod:load_item_packages(MasterItems.get_item(mod.selected_extra_attach), function()
              mod:refresh_all_gear_slots()
            end)

            mod.selected_extra_attach = ""
          end
        end

        Imgui.separator()
        Imgui.spacing()
        Imgui.same_line()

        if Imgui.button("Apply changes", x -35, 30) then
          mod:save_current_loadout()
          mod:refresh_all_gear_slots()
        end
      end
    end
  end
end

ImguiDripEditor.ui_content = function(self)
  local x = Imgui.get_window_size()
  slot_selection_header = Imgui.collapsing_header("Slots", slot_selection_header)

  if slot_selection_header then
    for k, slot in ipairs(mod.all_slots) do
      Imgui.spacing()
      Imgui.same_line()
      -- todo: localize
      if mod.slots_selection_status[slot] == nil then
        mod.slots_selection_status[slot] = true
      end

      mod.slots_selection_status[slot] = Imgui.checkbox(slot, mod.slots_selection_status[slot])

      if k == 1 or k == 3 or k == 5 then
        Imgui.same_line()
      end
    end

    Imgui.separator()
  end

  materials_header_open = Imgui.collapsing_header("Material Types", materials_header_open)

  if materials_header_open then
    Imgui.spacing()
    Imgui.same_line()

    if Imgui.begin_combo("Colors", mod.selected_color_material) then

      if Imgui.selectable("none", mod.selected_color_material == "none") then
        mod.selected_color_material = "none"
        color_index = 1
        apply_changes_on_change()
      end

      for k,v in ipairs(mod.color_materials) do
        if Imgui.selectable(v, v == mod.selected_color_material)  then
          mod.selected_color_material = v
          color_index = k+1
          apply_changes_on_change()
        end
      end

      Imgui.end_combo()
    else
      Imgui.same_line(30)

      if Imgui.button("<##color") then
        color_index = color_index - 1

        if color_index < 1 then
          color_index = #mod.color_materials + 1
        end

        if color_index == 1 then
          mod.selected_color_material = "none"
        else
          mod.selected_color_material = mod.color_materials[color_index-1]
        end

        apply_changes_on_change()
      end

      Imgui.same_line()
      Imgui.next_column()

      if Imgui.button(">##color") then
        color_index = color_index + 1

        if color_index > #mod.color_materials + 1 then
          color_index = 1
        end

        if color_index == 1 then
          mod.selected_color_material = "none"
        else
          mod.selected_color_material = mod.color_materials[color_index-1]
        end

        apply_changes_on_change()
      end
    end

    Imgui.spacing()
    Imgui.same_line()

    if Imgui.begin_combo("Materials", mod.selected_gear_material) then
      if Imgui.selectable("none", mod.selected_gear_material == "none") then
        mod.selected_gear_material = "none"
        gear_index = 1
        apply_changes_on_change()
      end

      for k,v in ipairs(mod.gear_materials) do
        if Imgui.selectable(v, v == mod.selected_gear_material)  then
          mod.selected_gear_material = v
          gear_index = k+1
          apply_changes_on_change()
        end
      end

      Imgui.end_combo()
    else
      Imgui.same_line(9)
      if Imgui.button("<##material") then
        gear_index = gear_index - 1

        if gear_index < 1 then
          gear_index = #mod.gear_materials + 1
        end

        if gear_index == 1 then
          mod.selected_gear_material = "none"
        else
          mod.selected_gear_material = mod.gear_materials[gear_index-1]
        end

        apply_changes_on_change()
      end
      Imgui.same_line()
      if Imgui.button(">##material") then
        gear_index = gear_index + 1

        if gear_index > #mod.gear_materials + 1 then
          gear_index = 1
        end

        if gear_index == 1 then
          mod.selected_gear_material = "none"
        else
          mod.selected_gear_material = mod.gear_materials[gear_index-1]
        end

        apply_changes_on_change()
      end
    end

    Imgui.spacing()
    Imgui.same_line()

    if Imgui.begin_combo("Patterns", mod.selected_pattern_material) then
      if Imgui.selectable("none", mod.selected_pattern_material == "none") then
        mod.selected_pattern_material = "none"
        pattern_index = 1
        apply_changes_on_change()
      end

      for k,v in ipairs(mod.pattern_materials) do
        if Imgui.selectable(v, v == mod.selected_pattern_material)  then
          mod.selected_pattern_material = v
          pattern_index = k+1
          apply_changes_on_change()
        end
      end

      Imgui.end_combo()
    else
      Imgui.same_line(16)

      if Imgui.button("<##pattern") then
        pattern_index = pattern_index - 1

        if pattern_index < 1 then
          pattern_index = #mod.pattern_materials + 1
        end

        if pattern_index == 1 then
          mod.selected_pattern_material = "none"
        else
          mod.selected_pattern_material = mod.pattern_materials[pattern_index-1]
        end

        apply_changes_on_change()
      end

      Imgui.same_line()

      if Imgui.button(">##pattern") then
        pattern_index = pattern_index + 1

        if pattern_index > #mod.pattern_materials + 1 then
          pattern_index = 1
        end

        if pattern_index == 1 then
          mod.selected_pattern_material = "none"
        else
          mod.selected_pattern_material = mod.pattern_materials[pattern_index-1]
        end

        apply_changes_on_change()
      end
    end

    Imgui.separator()
  end

  self:body_customization_ui()

  self:slot_customization_ui()

  presets_header = Imgui.collapsing_header("Presets##header", presets_header)

  if presets_header then
    Imgui.spacing()
    Imgui.same_line()

    if Imgui.begin_combo("Selected Preset", mod.selected_preset_name) then
      if Imgui.selectable("none", mod.selected_preset == "none") then
        mod.selected_preset = "none"
        mod.selected_preset_name = "none"
      end

      for i=1,mod.max_preset_id do
        local id = tostring(i)
        if mod.saved_looks[id] then
          if Imgui.selectable(mod.saved_looks[id].name, mod.selected_preset == id) then
            mod.selected_preset = id
            mod.selected_preset_name = mod.saved_looks[id].name
          end
        end
      end

      Imgui.end_combo()
    end


    Imgui.spacing()
    Imgui.same_line()

    if Imgui.button("Load Preset", x-35, 30) then
      if mod.selected_preset ~= "none" then
        mod.load_preset(mod.selected_preset)
      end
    end

    if mod.selected_preset ~= "none" then
      Imgui.spacing()
      Imgui.same_line()

      if Imgui.button("Override Preset", x-35, 30) then
        mod:override_selected_preset()
      end

      Imgui.spacing()
      Imgui.same_line()

      if Imgui.button("Delete Preset", x-35, 30) then
        mod:deleted_selected_preset()
      end
    end

    Imgui.separator()
  end

  options_header = Imgui.collapsing_header("Options", options_header)

  if options_header then
    Imgui.spacing()
    Imgui.same_line()
    reset_selected_slots = Imgui.checkbox("Reset selected slots before applying changes     ", reset_selected_slots)

    Imgui.spacing()
    Imgui.same_line()
    mod:set("apply_mat_on_index_change", Imgui.checkbox(mod:localize("apply_mat_on_index_change"), mod:get("apply_mat_on_index_change")))

    Imgui.spacing()
    Imgui.same_line()
    mod:set("preview_attachments", Imgui.checkbox(mod:localize("preview_attachments"), mod:get("preview_attachments")))

    Imgui.separator()
  end


  Imgui.spacing()
  Imgui.same_line()

  if Imgui.button("Apply", x / 2 - 20, 30) then
    apply_changes()
  end

  Imgui.same_line()

  if Imgui.button("Save Preset", x / 2 - 20, 30) then
    mod:save_current_look()
  end

  Imgui.separator()

  Imgui.spacing()
  Imgui.same_line()

  if Imgui.button("Reset selected slots",  x / 2 - 20, 30) then
    for slot, checked in pairs(mod.slots_selection_status) do
      if checked then
        mod:reset_slot(slot)

        if slot == mod.selected_unit_slot then
          mod.selected_unit_slot = "none"
        end
      end
    end
  end

  Imgui.same_line()

  if Imgui.button("Reset all slots",  x / 2 - 20, 30) then
    mod:reset_visual_loadout()
  end
end


ImguiDripEditor.close = function(self)
  if Managers.input:cursor_active() then
    Managers.input:pop_cursor(self.__class_name)
  end

  show_editor = false
  Imgui.close_imgui()
end

mod.toggle_ui = function()
  if show_editor then
    editor:close()
  else
    editor:open()

    if (not mod.attachment_per_slot_per_breed) and (not mod.is_fetching_attachments) then
      mod:fetch_avaiable_attachment_per_slot_per_breed()
    end
  end
end

mod.update = function()
  if show_editor then
    editor:update()
  end
end
