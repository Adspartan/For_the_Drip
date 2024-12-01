local mod = get_mod("for_the_drip")

local ItemMaterialOverrides = require("scripts/settings/equipment/item_material_overrides/item_material_overrides")
local FixedFrame = require("scripts/utilities/fixed_frame")
local MasterItems = require("scripts/backend/master_items")
local Promise = require("scripts/foundation/utilities/promise")

local show_editor = false
local reset_ingui_pos = false

local materials_header_open = true
local slot_selection_header = true
local body_options_header = true
local presets_header = true
local unit_header = true

mod.font_scale = nil

mod.reset_editor_nav_combos = function(self)
  mod.color_material_combo = nil
  mod.pattern_material_combo = nil
  mod.gear_material_combo = nil

  mod.mask_torso_combo = nil
  mod.mask_arms_combo = nil
  mod.mask_legs_combo = nil
  mod.mask_face_combo = nil
  mod.mask_hair_combo = nil
  mod.mask_facial_hair_combo = nil

  mod.extra_attachments_combo = nil
end

mod.reset_window_pos = function()
  reset_ingui_pos = true
end


mod.selected_color_material = "none"
mod.selected_pattern_material = "none"
mod.selected_gear_material = "none"
mod.selected_preset = "none"
mod.selected_preset_name = "none"
mod.decals_filter = ""
mod.selected_attachment_index = 0
mod.selected_unit_slot = "none"
mod.selected_extra_attach = ""
mod.selected_extra_decal = ""
mod.selected_hair_color_index = 1

local selected_preset_index = 0

mod.slots_selection_status = {}

local reset_selected_slots = false

local apply_changes = function()
  local player = Managers.player:local_player_safe(1)

  for slot, checked in pairs(mod.slots_selection_status) do
    if checked then
      if reset_selected_slots then
        mod:reset_slot(slot)
      end

      -- update the values, the UI will always have the most up to date ones
      if mod.color_material_combo then
        mod.selected_color_material = mod.color_material_combo._value
        mod.selected_gear_material = mod.gear_material_combo._value
        mod.selected_pattern_material = mod.pattern_material_combo._value
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

local extra_attach_change = function()
  if mod.extra_attachments_combo then
    mod:preview_attachment(mod.extra_attachments_combo._value)
  end
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

    mod:reset_changelogs_ui_pos()
  end

  local title = "Drip Editor"

  if mod.current_version and mod.current_version ~= "" then
    title = title.." v"..mod.current_version
  end

  if mod.update_available then
    title = title.." - Update Available !"
  end

  local _, closed = Imgui.begin_window(title, "always_auto_resize", "menu_bar")

  if closed then
    self:close()
    mod:close_changelogs_ui()
  else
    self:ui_content()
  end

  Imgui.end_window()
end

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

  if Imgui.button("Apply##body_option_btn", x-35, 30 * mod.font_scale) then
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
          mod.extra_attachments_combo = nil

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

          if not mod.mask_torso_combo then
            mod.mask_torso_combo = mod:create_nav_combo("Body Mask", mod.masks_per_slots.slot_body_torso, data.mask_torso, mod.on_mask_changed)
          end

          data.mask_torso = mod.mask_torso_combo:display()

          Imgui.spacing()
          Imgui.same_line()

          data.hide_arms = Imgui.checkbox("Hide Arms##hide_arms_btn", data.hide_arms)
          Imgui.same_line()

          if not mod.mask_arms_combo then
            mod.mask_arms_combo = mod:create_nav_combo("Arms Mask", mod.masks_per_slots.slot_body_arms, data.mask_arms, mod.on_mask_changed)
          end

          data.mask_arms = mod.mask_arms_combo:display()

          Imgui.separator()
        end

        if mod.selected_unit_slot == "slot_gear_lowerbody" then
          Imgui.spacing()
          Imgui.same_line()
          data.hide_legs = Imgui.checkbox("Hide Legs##hide_legs_btn", data.hide_legs)

          Imgui.same_line()

          if not mod.mask_legs_combo then
            mod.mask_legs_combo = mod:create_nav_combo("Legs Mask", mod.masks_per_slots.slot_body_legs, data.mask_legs, mod.on_mask_changed)
          end

          data.mask_legs = mod.mask_legs_combo:display()

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

          if not mod.mask_face_combo then
            mod.mask_face_combo = mod:create_nav_combo("Face Mask", mod.face_masks, data.mask_face, mod.on_mask_changed)
          end

          data.mask_face = mod.mask_face_combo:display()

          Imgui.spacing()
          Imgui.same_line()

          if not mod.mask_hair_combo then
            if mod:persistent_table("data").breed == "ogryn" then
              mod.mask_hair_combo = mod:create_nav_combo("Hair Mask", mod.ogryn_hair_masks, data.mask_hair, mod.on_mask_changed)
            else
              mod.mask_hair_combo = mod:create_nav_combo("Hair Mask", mod.human_hair_masks, data.mask_hair, mod.on_mask_changed)
            end
          end

          data.mask_hair = mod.mask_hair_combo:display()

          Imgui.spacing()
          Imgui.same_line()

          if not mod.mask_facial_hair_combo then
            if mod:persistent_table("data").breed == "ogryn" then
              mod.mask_facial_hair_combo = mod:create_nav_combo("Face Hair Mask", mod.ogryn_face_hair_masks, data.mask_facial_hair, mod.on_mask_changed)
            else
              mod.mask_facial_hair_combo = mod:create_nav_combo("Face Hair Mask", mod.human_face_hair_masks, data.mask_facial_hair, mod.on_mask_changed)
            end
          end

          data.mask_facial_hair = mod.mask_facial_hair_combo:display()

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

          if not mod.extra_attachments_combo then
            local breed = mod:persistent_table("data").breed
            local attach_list = mod.attachment_per_slot_per_breed[breed] and mod.attachment_per_slot_per_breed[breed][mod.selected_unit_slot] or {}

            mod.extra_attachments_combo = mod:create_filter_nav_combo("Extra Attachment", attach_list, "", extra_attach_change)
          end

          mod.selected_extra_attach = mod.extra_attachments_combo:display()
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
            mod.current_preview_attach_display = ""
          end
        end

        Imgui.separator()
        Imgui.spacing()
        Imgui.same_line()

        if Imgui.button("Apply changes", x -35, 30 * mod.font_scale) then
          mod:save_current_loadout()
          mod:refresh_all_gear_slots()
        end
      end
    end
  end
end

ImguiDripEditor.ui_content = function(self)
  if not mod.font_scale then
    mod.font_scale = mod:get("mod.font_scale") or 1.0
    mod:set("mod.font_scale", mod.font_scale)
  end

  if Imgui.begin_menu_bar() then
    if Imgui.begin_menu("Settings") then
      reset_selected_slots = Imgui.checkbox("Reset selected slots before applying changes     ", reset_selected_slots)
      mod:set("apply_mat_on_index_change", Imgui.checkbox(mod:localize("apply_mat_on_index_change"), mod:get("apply_mat_on_index_change")))
      mod:set("apply_masks_on_change", Imgui.checkbox("Apply masks on change", mod:get("apply_masks_on_change")))
      mod:set("preview_attachments", Imgui.checkbox(mod:localize("preview_attachments"), mod:get("preview_attachments")))

      local new_fs = Imgui.slider_float("Font scale", mod.font_scale, 0.5, 3)

      if new_fs ~= mod.font_scale then
        mod.font_scale = new_fs
        mod:set("mod.font_scale", mod.font_scale)
      end


      Imgui.end_menu()
    end

    if Imgui.begin_menu("Changelogs") then
      if Imgui.button("Show/Hide") then
        mod:toggle_changelogs_ui()
      end
      Imgui.end_menu()
    end

    Imgui.end_menu_bar()
  end


  Imgui.set_window_font_scale(mod.font_scale)

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

    -- all 3 are reset at the same time
    if not mod.color_material_combo then
      mod.color_material_combo =   mod:create_nav_combo("Colors   ", mod.color_materials, mod.selected_color_material, apply_changes_on_change, "none")
      mod.gear_material_combo =    mod:create_nav_combo("Materials", mod.gear_materials, mod.selected_gear_material, apply_changes_on_change, "none")
      mod.pattern_material_combo = mod:create_nav_combo("Patterns ", mod.pattern_materials, mod.selected_pattern_material, apply_changes_on_change, "none")
    end

    mod.selected_color_material = mod.color_material_combo:display()
    Imgui.spacing()
    Imgui.same_line()
    mod.selected_gear_material = mod.gear_material_combo:display()
    Imgui.spacing()
    Imgui.same_line()
    mod.selected_pattern_material = mod.pattern_material_combo:display()

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
        mod.new_preset_name = ""
      end

      for id, name in pairs(mod.presets_info.presets) do
        if name and mod.presets[id] then
          if Imgui.selectable(name, mod.selected_preset == id) then
            mod.selected_preset = id
            mod.selected_preset_name = name
            mod.new_preset_name = name
          end
        end
      end

      Imgui.end_combo()
    end


    Imgui.spacing()
    Imgui.same_line()

    if Imgui.button("Load Preset", x-35, 30 * mod.font_scale) then
      if mod.selected_preset ~= "none" then
        mod.load_preset(mod.selected_preset)
      end
    end

    if mod.selected_preset ~= "none" then
      Imgui.spacing()
      Imgui.same_line()

      mod.new_preset_name = Imgui.input_text("", mod.new_preset_name)
      Imgui.same_line()
      if Imgui.button("Rename Preset") then
        mod:rename_selected_preset()
        mod.selected_preset_name = mod.new_preset_name
      end

      Imgui.spacing()
      Imgui.same_line()

      if Imgui.button("Override Preset", x-35, 30 * mod.font_scale) then
        mod:override_selected_preset()
      end

      Imgui.spacing()
      Imgui.same_line()

      if Imgui.button("Delete Preset", x-35, 30 * mod.font_scale) then
        mod:deleted_selected_preset()
      end
    end

    Imgui.separator()
  end

  Imgui.spacing()
  Imgui.same_line()

  if Imgui.button("Apply", x / 2 - 20, 30 * mod.font_scale) then
    apply_changes()
  end

  Imgui.same_line()

  if Imgui.button("Save Preset", x / 2 - 20, 30 * mod.font_scale) then
    mod:save_current_look()
  end

  Imgui.separator()

  Imgui.spacing()
  Imgui.same_line()

  if Imgui.button("Reset selected slots",  x / 2 - 20, 30 * mod.font_scale) then
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

  if Imgui.button("Reset all slots",  x / 2 - 20, 30 * mod.font_scale) then
    mod:reset_visual_loadout()
  end

  Imgui.separator()

  Imgui.spacing()
  Imgui.same_line()
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

    -- check for updates when opening the editor, 6min cooldown
    mod:auto_check_for_update_if_on_cd()

    if (not mod.attachment_per_slot_per_breed) and (not mod.is_fetching_attachments) then
      mod:fetch_avaiable_attachment_per_slot_per_breed()
    end
  end
end

mod.update = function()
  if show_editor then
    editor:update()
    mod:update_changelogs_ui()
  end
end
