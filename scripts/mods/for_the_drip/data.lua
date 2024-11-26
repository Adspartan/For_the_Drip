local mod = get_mod("for_the_drip")

local ItemMaterialOverrides = require("scripts/settings/equipment/item_material_overrides/item_material_overrides")
local Promise = require("scripts/foundation/utilities/promise")

--------------------
-- slot_weapon_skin

mod.color_materials = {}
mod.pattern_materials = {}
mod.gear_materials = {}
mod.decal_materials = {}

mod.all_slots =
{
  "slot_gear_head",
  "slot_gear_upperbody",
  "slot_gear_lowerbody",
  "slot_gear_extra_cosmetic",
  "slot_primary",
  "slot_secondary"
}

mod.customizable_slots =
{
  "none",
  "slot_gear_head",
  "slot_gear_upperbody",
  "slot_gear_lowerbody",
  "slot_gear_extra_cosmetic",
}

mod.face_masks = {}
mod.human_hair_masks = {}
mod.human_face_hair_masks = {}
mod.ogryn_hair_masks = {}
mod.ogryn_face_hair_masks = {}

mod.masks_per_slots = {}
mod.available_colors = {}
mod.available_colors_textures = {}

local decal_table =
{
  decal_atlas_o_brawler_lugger_01 = "content/textures/gear_decals/decal_atlas_o_brawler_lugger_01",
  decal_atlas_cadia_01 = "content/textures/gear_decals/decal_atlas_cadia_01",
  decal_atlas_ogryn_01 = "content/textures/gear_decals/decal_atlas_ogryn_01",
  decal_atlas_psyker_02 = "content/textures/gear_decals/decal_atlas_psyker_02",
  decal_atlas_npc_01 = "content/textures/gear_decals/decal_atlas_npc_01",
  decal_atlas_zealot_01 = "content/textures/gear_decals/decal_atlas_zealot_01",
  decal_atlas_v_leader_grunt_01 = "content/textures/gear_decals/decal_atlas_v_leader_grunt_01",
  decal_atlas_christmas_01 = "content/textures/gear_decals/decal_atlas_christmas_01",
  decal_atlas_death_korps_of_krieg_01 = "content/textures/gear_decals/decal_atlas_death_korps_of_krieg_01",
  decal_atlas_veteran_01 = "content/textures/gear_decals/decal_atlas_veteran_01",
  decal_atlas_zola = "content/textures/gear_decals/decal_atlas_zola",
  decal_atlas_veteran_02 = "content/textures/gear_decals/decal_atlas_veteran_02",
  decal_atlas_d7 = "content/textures/gear_decals/decal_atlas_d7",
  decal_atlas_psyker_01 = "content/textures/gear_decals/decal_atlas_psyker_01",
  decal_atlas_special_events_01 = "content/textures/gear_decals/decal_atlas_special_events_01",
  decal_atlas_hive_scum_01 = "content/textures/gear_decals/decal_atlas_hive_scum_01",
  decal_atlas_steel_legion_01 = "content/textures/gear_decals/decal_atlas_steel_legion_01",
  decal_atlas_skulls_edition = "content/textures/gear_decals/decal_atlas_skulls_edition",
  decal_atlas_holidays_01 = "content/textures/gear_decals/decal_atlas_holidays_01",
  decal_atlas_z_preacher_maniac_01 = "content/textures/gear_decals/decal_atlas_z_preacher_maniac_01",
  decal_atlas_moebian_01 = "content/textures/gear_decals/decal_atlas_moebian_01",
  decal_atlas_ogryn_02 = "content/textures/gear_decals/decal_atlas_ogryn_02",
  decal_atlas_holidays_02 = "content/textures/gear_decals/decal_atlas_holidays_02",
  decal_atlas_p_biomancer_protector_01 = "content/textures/gear_decals/decal_atlas_p_biomancer_protector_01"
}
local decal_material_types =
{
  false,
  "coated",
  "oxidized"
}

-- ... = filters
mod.filter_masks = function(self, input, default_mask, ...)
  local masks = {}

  for k,v in pairs(input) do
    if (not string.match(k, "debug")) and k ~= default_mask and string.starts_with_any(k, ...) then
      table.insert(masks, k)
    end
  end

  table.sort(masks)
  table.insert(masks, 1, default_mask)

  return masks
end

mod:hook_require("scripts/settings/equipment/item_material_overrides/player_material_overrides_base_body_mask", function(instance)
  if instance then
    -- custom
    instance["mask_feet"] =
    {
      property_overrides =
      {
        mask_top_bottom =
        {
          0.2,
          0
        }
      }
    }

    mod.masks_per_slots["slot_body_torso"] = mod:filter_masks(instance, "mask_default", "mask_torso_")
    mod.masks_per_slots["slot_body_arms"] = mod:filter_masks(instance, "mask_default", "mask_arms_", "mask_hands", "mask_upperarms", "mask_half_upperarms")
    mod.masks_per_slots["slot_body_legs"] = mod:filter_masks(instance, "mask_default", "mask_legs", "mask_feet")
  end
end)

mod:hook_require("scripts/settings/equipment/item_material_overrides/player_material_overrides_face_mask", function(instance)
  if instance then
    mod.face_masks = mod:filter_masks(instance, "mask_face_none", "mask_")
  end
end)

mod:hook_require("scripts/settings/equipment/item_material_overrides/player_material_overrides_hair_headgear_mask", function(instance)
  if instance then
    mod.human_hair_masks = mod:filter_masks(instance, "hair_no_mask", "hair_")
    mod.ogryn_hair_masks = mod:filter_masks(instance, "hair_no_mask", "ogryn_hair_")
    mod.human_face_hair_masks = mod:filter_masks(instance, "facial_hair_no_mask", "facial_hair_")
    mod.ogryn_face_hair_masks = mod:filter_masks(instance, "facial_hair_no_mask", "ogryn_facial_hair_")
  end
end)

mod:hook_require("scripts/settings/equipment/item_material_overrides/item_material_overrides_gear_colors", function(instance)
  if instance then
    mod.color_materials = {}

    for k,v in pairs(instance) do
      if not string.match(k, "debug") then
        table.insert(mod.color_materials, k)
      end

      for t, texture in pairs(v.texture_overrides or {}) do
        local index = mod:shorten_item_name(texture["resource"])

        if not mod.available_colors_textures[index] then
          table.insert(mod.available_colors, index)
          mod.available_colors_textures[index] = texture["resource"]
        end
      end
    end
  end

  -- give it some time to finish loading everything
  Promise.delay(0.5):next(function()
    table.sort(mod.available_colors)
  end)

  table.sort(mod.color_materials)
end)

mod:hook_require("scripts/settings/equipment/item_material_overrides/player_material_overrides_hair_colors", function(instance)
  if instance then
    for k,v in pairs(instance) do
      for t, texture in pairs(v.texture_overrides or {}) do
        local index = mod:shorten_item_name(texture["resource"])

         if not mod.available_colors_textures[index] then
          table.insert(mod.available_colors, index)
          mod.available_colors_textures[index] = texture["resource"]
        end
      end
    end
  end
end)

mod:hook_require("scripts/settings/equipment/item_material_overrides/item_material_overrides_gear_patterns", function(instance)
  if instance then
    mod.pattern_materials = {}

    for k,v in pairs(instance) do
      if not string.match(k, "debug") then
        table.insert(mod.pattern_materials, k)
      end
    end
  end

  table.sort(mod.pattern_materials)
end)

mod:hook_require("scripts/settings/equipment/item_material_overrides/item_material_overrides_gear_materials", function(instance)
  if instance then
    mod.gear_materials = {}

    for k,v in pairs(instance) do
      if not string.match(k, "debug") then
        table.insert(mod.gear_materials, k)
      end
    end
  end

  table.sort(mod.gear_materials)
end)

mod:hook_require("scripts/settings/equipment/item_material_overrides/player_material_overrides_gear_decals", function(instance)
  if instance then
    mod.decal_materials = {}

    for k,v in pairs(instance) do
      if not string.match(k, "debug") then
        table.insert(mod.decal_materials, k)
      end
    end
  end

  table.sort(mod.decal_materials)
end)
