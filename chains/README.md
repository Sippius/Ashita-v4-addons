# Chains - Skillchains reborn
### Active Battle Skillchain Display.

**Designed for and tested on retail.**

Displays a text object containing skillchain elements resonating on current target, timer for skillchain window and a list of weapon skills that can skillchain based on the weapon you have currently equipped.

Chains is based on the skillchains addon by Ivaar for Ashita-v3. It has mostly been recoded for Ashita-v4 while maintaining the same functionality.

### Commands
The following commands may be used to adjust the window position.

    /chains visible      -- displays text box - hold shift+click and drag it to desired location

    /chains move <x> <y> -- reposition the window to the defined x, y coordinates

The following commands toggle the display information.

    /chains color   -- colorize properties and elements

    /chains pet     -- smn and bst pet skills

    /chains spell   -- sch immanence and blue magic spells

    /chains weapon  -- weapon skills

### Notable features that have changed
- Display configuration is not currently stored per job and not all options are supported.
- Information is displayed through IMGUI instead of a font object.
- BLU and SCH spells only display when the associated abilities are active.
- Skillchains are calculated on each render cycle for the active target rather than once for each target. This allows for real time updates based on active abilities and equipped weapon at the cost of additional workload.
- Because the addon has been recoded and logic changed, it may not act exactly the same.

### Noteable features that are the same
- Display format (with and without color)
- Support for spells under Immanence, Chain Affinity and Azure Lore
- Support for Pet and NPC weaponskills
- Support for Aeonic weapons and ultimate skillchains (limited testing)

### Known Issues/limitations
- Pet skills only work on BST and SMN main
- Chain Affinity only works with BLU main
- Azure Lore duration is hard coded to 30 seconds (no check for relic hands)
- Cannot detect when another player cancels their spell abilities
- Aeonic testing is limited due to lack of weapon to test with
- Pet skill IDs and skillchain properties in skills.lua require modification for private servers

### Possible future ehancements
- Improve display configuration and re-implement some/all of the previous options
- Add support for element images in addition to or in place of element/property text names
- Add support for Chain Affinity with BLU as subjob

### Acknowledgments
All credit goes to Ivaar for the original skillchains implementation which was used as the tempalte for how to accomplish the desired results and how to deal with some of the corner cases.

Special thanks to Atom0s and Thorny. Many of their addons are used as examples of how to accomplish various tasks.
