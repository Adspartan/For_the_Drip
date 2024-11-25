local nl_1 ="\n    "
local nl_2 ="\n      "
return
{
  ["0.12.2"] =
  {
    "Add changelogs",
    "Add current version to the FTD window title",
  },
  ["0.12.1"] =
  {
    "Add navigation buttons for the masks",
    "Add setting to auto apply masks changes",
  },
  ["0.12.0"] =
  {
    ["Add an update checker and auto updater"] =
    {
      "You'll get a chat message when the mods are loaded if there's an update available"..nl_2.."and the FTD window will show it too",
      "Use the command /ftd_update to update the mod",
    },
  },
  ["0.11.1"] =
  {
    "Fix preset rename/override not working in some cases",
    "Display attachment index, count and name when selecting extra attachments",
    "Fix attachments filter that was letting through some items with attachments"..nl_1.."(those were causing problems as they can't be used as attachments)",
  },
  ["0.11.0"] =
  {
    "Add the option to rename presets",
    "Implement a new way to save presets (old ones are automatically imported)",
    "Fix possible crash when customizing empty backpacks",
  },
  ["0.10.4"] =
  {
    "Fix hide hair default value for head gear",
    "Always load known packages too just in case",
  },
  ["0.10.3"] =
  {
    "Fix crash that could happen when reloading mods",
    "Fix empty backpack extra attachment (limited to 1 attachment)",
    "Fix customization not loading in the main menu when selecting a different character",
  },
  ["0.10.2"] =
  {
    "Fix default hair color not working properly",
    "Fix 'hide hair' option not using the right value when first loading the head gear slot item",
    "Fix attachments overriding each other",
  },
  ["0.10.1"] =
  {
    "Fix delay between unequipping an item and equipping it back that caused issues/crashes",
  },
  ["0.10.0"] =
  {
    ["Add selected attachment preview (on by default)"] =
    {
      "Add the currently selected attachment to your cosmetic item as a temporary attachment",
      "Use the '<' and '>' buttons to get the previous/next attachment in the list using the current filter"..nl_2.."(does not circle back to the end/start when reaching an extremity)",
      "Use the 'x' button to remove the currently selected attachment (resets the selected index too)",
      "Add option to toggle the feature in the option header",
    },
  },
  ["0.9.1"] =
  {
    "Fix crash when picking up mission items (batteries, vacuum capsules, ...)",
  },
  ["0.9.0"] =
  {
    "Add custom hair colors",
    "Add face mask option (to hide part of the face to prevent clipping)",
    "Add option to hide/show hair, even on cosmetics that usually hide them",
    "Fix hair masks not being applied",
  },
  ["0.8.1"] =
  {
    "Fix issues in the inventory screen (player model not updated/cosmetics not previewing).",
    "Fix extra attachments still being visible after deleting them."
  },
  ["0.8.0"] =
  {
    "Initial github release"
  },
}
