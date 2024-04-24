# Why isn't the mod on nexus ?
Because there's still some issues with it, they are getting sorted out but I don't want to upload an unstable mod there.



# Support
For support go to the [Modding Discord](https://discord.gg/rKYWtaDx4D) -> [For the Drip Post](https://discord.com/channels/1048312349867646996/1048318548180738118/1163114688540848169)



# How to use

## Basic Customization
- Add the mod to your mod folder and into you mod_load_order.txt (below the weapon customization mod if you have it)
- Setup the keybinds in the mod options
- **Make sure your game isn't set to fullscreen or you won't be able to use the UI**
- Go the the Mourningstar or Psykhanium
- Make sure to be in 3rd person mode to change your gear's look for a better experience
- Select which slots you want the apply changes for better control (primary -> melee weapon, secondary -> ranged weapon)
- Change materials and apply (if the option to apply automatically isn't selected)
  - Colors to change the coloring of the items (color_x indicate the number of colors for this specific material)
  - Materials to change what kind of material the parts of the item will look like (ex: cloth/leather)
    - Wear: change how much wear/visible sign of use an item has
    - Cloth: to change non metallic parts
    - Metal: to change metallic parts
  - Patterns to change how the different colors are displayed
    
 
:warning: **Not all materials will affect the same parts of an item**

Colors and Patterns will only affect Cloth parts if the material used allows it

Some details/parts on the cosmetics may not be affected at all by material changes !
  

## Advanced Customization

Select a slot in the 'Slot Customization' section to customize it further
- Hide Attachments by unselecting them
- Select which attachments get customized (material changes) by checking/unchecking 'Customize'
- Add new attachments to the item by selecting one in the 'Extra Attachment' drop down and pressing 'Add attachment'
- Extra attachments can be removed by clicking on the 'x' button on the right
- 'Hide x' checkboxes are used to hide/show body parts
- Masks are used to partially hide body parts to avoid clipping with the cosmetics (only work if the body part is not hidden already)


## Presets
- You can save your current customizations to new preset or override an existing one.
- Presets aren't tied to loadout currently, it'll most likely come as an option in the future
- One preset can have customization data for multiple items of the same slot



# Currently Known Issues
- **If the UI goes out of the game window it'll bug out/move on its own, there is a keybind to reset the UI when that happens** (quirk of the ImGui implementation in the game)
- Head masks aren't working
- Voice filters not being applied
  
