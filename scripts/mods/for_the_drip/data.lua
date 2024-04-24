local mod = get_mod("for_the_drip")

local ItemMaterialOverrides = require("scripts/settings/equipment/item_material_overrides/item_material_overrides")

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

mod.human_hair_masks =
{
	"hair_no_mask",
	"hair_mask_underside_back_01",
	"hair_mask_underside_back_02",
	"hair_mask_half_left_01",
	"hair_mask_half_right_01",
	"hair_mask_half_right_02",
	"hair_mask_back",
	"hair_mask_back_big",
	"hair_mask_back_top",
	"hair_mask_backside_02",
	"hair_mask_fringe_big",
	"hair_mask_fringe",
	"hair_mask_fringe_tight",
	"hair_mask_fringe_inverted",
	"hair_mask_top",
	"hair_mask_top_bigger",
	"hair_mask_top_big",
	"hair_mask_top_big_01",
	"hair_mask_back_01",
	"hair_mask_shrink_01",
	"hair_mask_shrink_02",
}

mod.human_face_hair_masks =
{
	"facial_hair_no_mask",
	"facial_hair_mask_neck_01",
	"facial_hair_mask_chin_strap_01",
	"facial_hair_mask_chin_01",
	"facial_hair_mask_chin_sides_01",
	"facial_hair_mask_chin_sides_02",
	"facial_hair_mask_chin_sides_03",
	"facial_hair_mask_sides_01",
	"facial_hair_mask_sides_02",
	"facial_hair_keep_small_sideburns_01",
	"facial_hair_keep_small_sideburns_02",
	"facial_hair_mask_underside_01",
}

mod.ogryn_hair_masks =
{
	"hair_no_mask",
	"ogryn_hair_mask_fringe",
	"ogryn_hair_mask_back_01",
	"ogryn_hair_mask_beret",
	"ogryn_hair_mask_cap_01",
	"ogryn_hair_mask_cap_02",
	"ogryn_hair_mask_top_01",
	"ogryn_hair_mask_top_02",
	"ogryn_hair_mask_half_left",
	"ogryn_hair_mask_half_right",
	"ogryn_hair_mask_half_right_02",
}

mod.ogryn_face_hair_masks =
{
	"facial_hair_no_mask",
	"ogryn_facial_hair_mask_sides_01",
	"ogryn_facial_hair_mask_sides_02",
	"ogryn_facial_hair_mask_sides_03",
	"ogryn_facial_hair_mask_chin_strap_01",
	"ogryn_facial_hair_mask_chin_strap_02",
	"ogryn_facial_hair_keep_small_sideburns_01",
	"ogryn_facial_hair_keep_small_sideburns_02",
}

mod.masks_per_slots = {}
mod.masks_per_slots["slot_body_torso"] =
{
	"mask_default",
	"mask_torso_keep_collar",
	"mask_torso_keep_pecs",
	"mask_torso_keep_armpits"
}

mod.masks_per_slots["slot_body_legs"] =
{
	"mask_default",
	"mask_legs_keep_knees_and_shins",
	"mask_legs_keep_knees",
	"mask_feet_and_shins_keep_knees_and_thighs",
	"mask_feet"
}
mod.masks_per_slots["slot_body_arms"] =
{
	"mask_default",
	"mask_arms_keep_forearms",
	"mask_hands",
	"mask_upperarms_hands_keep_wrist",
	"mask_arms_keep_forearms_and_hands",
	"mask_arms_keep_wrist_and_hands",
	"mask_arms_keep_hands",
	"mask_arms_keep_fingers",
	"mask_arms_keep_finger_tops",
	"mask_arms_shoulders_01",
	"mask_arms_shoulders_02",
	"mask_arms_shoulders_03",
	"mask_arms_keep_upperarms_forearms",
	"mask_arms_hands_keep_wrist"
}


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

mod:hook_require("scripts/settings/equipment/item_material_overrides/item_material_overrides_gear_colors", function(instance)
	if instance then
		mod.color_materials = {}

		for k,v in pairs(instance) do
			if not string.match(k, "debug") then
				table.insert(mod.color_materials, k)
			end
		end
	end

  table.sort(mod.color_materials)
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

mod.add_custom_body_masks = function()
	ItemMaterialOverrides["mask_feet"] =
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
end