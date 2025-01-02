# Why isn't the mod on Nexus?
Because there's still some issues with it; they are getting sorted out, but I don't want to upload an unstable mod there.

As of v0.12.0 the mod has an update checker and updater, so you'll be warned when there is a new update available and can update by typing `/ftd_update` in the game chatbox.


# Support
For support go to the [Darktide Modders Discord](https://discord.gg/rKYWtaDx4D) -> [For the Drip Post](https://discord.com/channels/1048312349867646996/1048318548180738118/1163114688540848169)



# How to use

## Installation
1. Go to the [latest release](https://github.com/Adspartan/For_the_Drip/releases/latest) on this repository
2. Download the `for_the_drip.zip` archive
3. Choose an installation method based on which mod manager you're using
    - Manual, no mod manager:
         1. Unzip the archive and add the `for_the_drip` folder to your Darktide mods folder
         2. Type `for_the_drip` into your `mod_load_order.txt` (place it below the [Extended Weapon Customization](https://www.nexusmods.com/warhammer40kdarktide/mods/277/) mod if you have it)
         3. Save the `mod_load_order.txt` file
    - Vortex: Choose one of the following ways to install mods manually through Vortex
        - Click `Install From File` on the top bar of the Mods section, then select the archive
        - Drag the archive into the `DROP FILES HERE` bar in the Mods section
        - Drag the archive into the Vortex downloads folder
4. Set up the keybinds in the Mod Options menu
## Basic Customization
1. Go to the Mourningstar or Psykhanium
    - When changing your gear's appearances, staying in 3rd person makes it easier to see changes compared to 1st person
    - The [Camera FreeFlight](https://www.nexusmods.com/warhammer40kdarktide/mods/32) mod gives more viewing angles, but using it while the Drip Editor is open is difficult because moving the mouse affects both the cursor position and the camera angle
2. Select which slots you want to apply changes to (box has a checkmark -> changes will apply)
    - This is the 'Slots' section: 1st section from the top of the Drip Editor
    - slot_primary -> melee weapon, slot_secondary -> ranged weapon)
3. Change material types and click 'Apply' at the bottom (if you haven't enabled the option to apply materials automatically)
      - Colors: the coloring of the items 
        - 'color_x' at the start of the name indicates the number of colors for this specific material (ex: `color_3_colour_desert_01` has 3 colors)
        - Some materials do not contain this indicator, but may still contain multiple colors (ex: `color_cadia_02` has 3 colors)
      - Material: what kind of material the parts of the item will look like (ex: cloth/leather)
        - Wear: changes how much wear (visible signs of use) an item has
        - Fabric: changes non-metallic parts
        - Metal: changes metallic parts
      - Patterns: how colors are displayed
        - Patterns ending in '_inv' differ in which parts they apply to (ex: applying a Pattern to clothes but not the armor)
        - Works when the selected Color has multiple colors
 
:warning: **Not all materials will affect the same parts of an item**

Colors and Patterns will only affect Cloth parts if the material used allows it (ex: `fabric_leather_03_wear_01` is black leather no matter what Color/Pattern you have chosen)

Some details/parts on the cosmetics may not be affected at all by material changes!
  

## Advanced Customization

Select a slot in the 'Slot Customization' section (4th from the top of the Drip Editor) to customize it further
- Hide Attachments by unselecting them
- Select which attachments get customized (material changes) by checking/unchecking 'Customize'
- Add new attachments to the item by selecting one in the 'Extra Attachment' drop down and pressing 'Add attachment'
- Extra attachments can be removed by clicking on the 'x' button on the right
- 'Hide x' checkboxes are used to hide/show body parts
- Masks are used to partially hide body parts to avoid clipping with the cosmetics (only work if the body part is not hidden already)


## Presets
- You can save your current customizations to new preset or override an existing one
- Presets aren't tied to loadout currently; it'll most likely come as an option in the future
- One preset can have customization data for multiple items of the same slot



# Currently Known Issues
- **If the UI goes out of the game window it'll bug out/move on its own, use the keybind to reset the UI. It must be set in the Mod Options menu first** (quirk of the ImGui implementation in the game)
- Voice filters not being applied
  
