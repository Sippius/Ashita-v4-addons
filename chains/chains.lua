--[[
* Chains displays current skillchains for the active target.
* It is based on the skillchains addon by Ivaar for Ashita v3.
*
* Several functions are leveraged from LuAshitacast by Thorny
* ParseActionPacket function is leveraged from timers by The Mystic
*
* Chains is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Chains is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with Ashita.  If not, see <https://www.gnu.org/licenses/>.
--]]

addon.name     = 'chains';
addon.author   = 'Sippius - Original Ashita-v3 skillchains by Ivaar';
addon.version  = '0.6';
addon.desc     = 'Display current skillchain options.';

require('common');
local ffi = require('ffi');
local chat = require('chat');
local imgui = require('imgui');
local settings = require('settings');

local skills = require('skills');

--=============================================================================
-- Addon Variables
--=============================================================================
local default_settings = T{
    position_x = 100,
    position_y = 100,
    display = T{
        color = true,
        pet = true,
        spell = true,
        weapon = true,
    },
};

local chains = T{
    settings = settings.load(default_settings),
    visible = false,
    move = nil,

    debug = false,
    forceAeonic = 0, -- set from 0 to 3
    forceImmanence = false, -- boolean
    forceAffinity = false, -- boolean
};

-- store player ID
-- * capture on init
local playerID;

-- store list of valid player/pet skills
-- * capture bluskill on 0x44 packet or first GetSkillchains call
-- * capture wepskill on 0xAC packet or first GetSkillchains call
-- * capture petskill on 0xAC packet or first GetSkillchains call
-- * capture schskill on load
local actionTable = T{
    schskill = skills.immanence,
};

-- store per player buff information
-- * player/buff added through action packet
-- * buff deleted through action packet when used or through presentevent on timeout
-- * player deleted through present event when no buff active
local playerTable = T{
};

-- store per target information on properties and duration
-- * target added through action packet
-- * target deleted through present event on timeout
local targetTable = T{
};

-- static information on skillchains
local chainInfo = T{
    Radiance = T{level = 4, burst = T{'Fire','Wind','Lightning','Light'}},
    Umbra    = T{level = 4, burst = T{'Earth','Ice','Water','Dark'}},
    Light    = T{level = 3, burst = T{'Fire','Wind','Lightning','Light'},
        aeonic = T{level = 4, skillchain = 'Radiance'},
        Light  = T{level = 4, skillchain = 'Light'},
    },
    Darkness = T{level = 3, burst = T{'Earth','Ice','Water','Dark'},
        aeonic   = T{level = 4, skillchain = 'Umbra'},
        Darkness = T{level = 4, skillchain = 'Darkness'},
    },
    Gravitation = T{level = 2, burst = T{'Earth','Dark'},
        Distortion    = T{level = 3, skillchain = 'Darkness'},
        Fragmentation = T{level = 2, skillchain = 'Fragmentation'},
    },
    Fragmentation = T{level = 2, burst = T{'Wind','Lightning'},
        Fusion     = T{level = 3, skillchain = 'Light'},
        Distortion = T{level = 2, skillchain = 'Distortion'},
    },
    Distortion = T{level = 2, burst = T{'Ice','Water'},
        Gravitation = T{level = 3, skillchain = 'Darkness'},
        Fusion      = T{level = 2, skillchain = 'Fusion'},
    },
    Fusion = T{level = 2, burst = T{'Fire','Light'},
        Fragmentation = T{level = 3, skillchain = 'Light'},
        Gravitation   = T{level = 2, skillchain = 'Gravitation'},
    },
    Compression = T{level = 1, burst = T{'Darkness'},
        Transfixion = T{level = 1, skillchain = 'Transfixion'},
        Detonation  = T{level = 1, skillchain = 'Detonation'},
    },
    Liquefaction = T{level = 1, burst = T{'Fire'},
        Impaction = T{level = 2, skillchain = 'Fusion'},
        Scission  = T{level = 1, skillchain = 'Scission'},
    },
    Induration = T{level = 1, burst = T{'Ice'},
        Reverberation = T{level = 2, skillchain = 'Fragmentation'},
        Compression   = T{level = 1, skillchain = 'Compression'},
        Impaction     = T{level = 1, skillchain = 'Impaction'},
    },
    Reverberation = T{level = 1, burst = T{'Water'},
        Induration = T{level = 1, skillchain = 'Induration'},
        Impaction  = T{level = 1, skillchain = 'Impaction'},
    },
    Transfixion = T{level = 1, burst = T{'Light'},
        Scission      = T{level = 2, skillchain = 'Distortion'},
        Reverberation = T{level = 1, skillchain = 'Reverberation'},
        Compression   = T{level = 1, skillchain = 'Compression'},
    },
    Scission = T{level = 1, burst = T{'Earth'},
        Liquefaction  = T{level = 1, skillchain = 'Liquefaction'},
        Reverberation = T{level = 1, skillchain = 'Reverberation'},
        Detonation    = T{level = 1, skillchain = 'Detonation'},
    },
    Detonation = T{level = 1, burst = T{'Wind'},
        Compression = T{level = 2, skillchain = 'Gravitation'},
        Scission    = T{level = 1, skillchain = 'Scission'},
    },
    Impaction = T{level = 1, burst = T{'Lightning'},
        Liquefaction = T{level = 1, skillchain = 'Liquefaction'},
        Detonation   = T{level = 1, skillchain = 'Detonation'},
    },
};

-- IMGUI RGB color format {red, green, blue, alpha}
local colors = {};           -- Color codes by Sammeh
colors.Light =         { 1.0, 1.0, 1.0, 1.0 }; --'0xFFFFFFFF';
colors.Dark =          { 0.0, 0.0, 0.8, 1.0 }; --'0x0000CCFF';
colors.Ice =           { 0.0, 1.0, 1.0, 1.0 }; --'0x00FFFFFF';
colors.Water =         { 0.0, 1.0, 1.0, 1.0 }; --'0x00FFFFFF';
colors.Earth =         { 0.6, 0.5, 0.0, 1.0 }; --'0x997600FF';
colors.Wind =          { 0.4, 1.0, 0.4, 1.0 }; --'0x66FF66FF';
colors.Fire =          { 1.0, 0.0, 0.0, 1.0 }; --'0xFF0000FF';
colors.Lightning =     { 1.0, 0.0, 1.0, 1.0 }; --'0xFF00FFFF';
colors.Gravitation =   { 0.4, 0.2, 0.0, 1.0 }; --'0x663300FF';
colors.Fragmentation = { 1.0, 0.6, 1.0, 1.0 }; --'0xFA9CF7FF';
colors.Fusion =        { 1.0, 0.4, 0.4, 1.0 }; --'0xFF6666FF';
colors.Distortion =    { 0.2, 0.6, 1.0, 1.0 }; --'0x3399FFFF';
colors.Darkness =      colors.Dark;
colors.Umbra =         colors.Dark;
colors.Compression =   colors.Dark;
colors.Radiance =      colors.Light;
colors.Transfixion =   colors.Light;
colors.Induration =    colors.Ice;
colors.Reverberation = colors.Water;
colors.Scission =      colors.Earth;
colors.Detonation =    colors.Wind;
colors.Liquefaction =  colors.Fire;
colors.Impaction =     colors.Lightning;

local statusID = {
    AL  = 163, -- Azure Lore
    CA  = 164, -- Chain Affinity
    AM1 = 270, -- Aftermath: Lv.1
    AM2 = 271, -- Aftermath: Lv.2
    AM3 = 272, -- Aftermath: Lv.3
    IM  = 470  -- Immanence
};

local MessageTypes = T{
    2,   -- '<caster> casts <spell>. <target> takes <amount> damage'
    100, -- 'The <player> uses ..'
    110, -- '<user> uses <ability>. <target> takes <amount> damage.'
  --161, -- Additional effect: <number> HP drained from <target>.
  --162, -- Additional effect: <number> MP drained from <target>.
    185, -- 'player uses, target takes 10 damage. DEFAULT'
    187, -- '<user> uses <skill>. <amount> HP drained from <target>'
    317, -- 'The <player> uses .. <target> takes .. points of damage.'
  --529, -- '<user> uses <ability>. <target> is chainbound.',
    802  -- 'The <user> uses <skill>. <number> HP drained from <target>.'
}

local PetMessageTypes = T{
    110, -- '<user> uses <ability>. <target> takes <amount> damage.'
    317  -- 'The <player> uses .. <target> takes .. points of damage.'
};

local ChainBuffTypes = T{
    [statusID.AL] = { duration = 30 }, -- 40 with relic hands
    [statusID.CA] = { duration = 30 },
    [statusID.IM] = { duration = 60 }
};

local EquipSlotNames = T{
    [1] = 'Main',
    --[2] = 'Sub',
    [3] = 'Range',
    --[4] = 'Ammo',
    --[5] = 'Head',
    --[6] = 'Body',
    --[7] = 'Hands',
    --[8] = 'Legs',
    --[9] = 'Feet',
    --[10] = 'Neck',
    --[11] = 'Waist',
    --[12] = 'Ear1',
    --[13] = 'Ear2',
    --[14] = 'Ring1',
    --[15] = 'Ring2',
    --[16] = 'Back'
};

local SkillPropNames = T{
    [1] = 'Light',
    [2] = 'Darkness',
    [3] = 'Gravitation',
    [4] = 'Fragmentation',
    [5] = 'Distortion',
    [6] = 'Fusion',
    [7] = 'Compression',
    [8] = 'Liquefaction',
    [9] = 'Induration',
    [10] = 'Reverberation',
    [11] = 'Transfixion',
    [12] = 'Scission',
    [13] = 'Detonation',
    [14] = 'Impaction',
    [15] = 'Radiance',
    [16] = 'Umbra'
};

--=============================================================================
-- Registers a callback for the settings to monitor for character switches.
--=============================================================================
settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        chains.settings = s;
    end

    settings.save();
end);

--=============================================================================
-- Return table with color formatting applied to each table entry
-- @return {table}
--=============================================================================
-- based on code from skillchains by Ivaar
--=============================================================================
local function GetPropertyColor(t)
    if chains.settings.display.color then
        return colors[t]
    end
    return { 1.0, 1.0, 1.0, 1.0 };
end

--=============================================================================
-- Return count of requested buff. Return zero if buff is not active.
-- @return {table}
--=============================================================================
-- based on code from LuAshitacast by Thorny
--=============================================================================
local GetBuffCount = function(matchBuff)
    local count = 0;
    local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs();
    if (type(matchBuff) == 'string') then
        local matchText = string.lower(matchBuff);
        for _, buff in pairs(buffs) do
            local buffString = AshitaCore:GetResourceManager():GetString("buffs.names", buff);
			if (buffString ~= nil) and (string.lower(buffString) == matchText) then
                count = count + 1;
            end
        end
    elseif (type(matchBuff) == 'number') then
        for _, buff in pairs(buffs) do
            if (buff == matchBuff) then
                count = count + 1;
            end
        end
    end
    return count;
end

--=============================================================================
-- Return equipment data
-- @return {table}
--=============================================================================
-- based on code from LuAshitacast by Thorny
--=============================================================================
-- Combined gData.GetEquipment and gEquip.GetCurrentEquip
--=============================================================================
local GetEquipment = function()
    local inventoryManager = AshitaCore:GetMemoryManager():GetInventory();
    local equipTable = {};
    for k, v in pairs(EquipSlotNames) do
        local equippedItem = inventoryManager:GetEquippedItem(k - 1);
        local index = bit.band(equippedItem.Index, 0x00FF);
        local eqEntry = {};
        if (index == 0) then
            eqEntry.Container = 0;
            eqEntry.Item = nil;
        else
            eqEntry.Container = bit.band(equippedItem.Index, 0xFF00) / 256;
            eqEntry.Item = inventoryManager:GetContainerItem(eqEntry.Container, index);
            if (eqEntry.Item.Id == 0) or (eqEntry.Item.Count == 0) then
                eqEntry.Item = nil;
            end
        end
        if (type(eqEntry) == 'table') and (eqEntry.Item ~= nil) then
            local resource = AshitaCore:GetResourceManager():GetItemById(eqEntry.Item.Id);
            if (resource ~= nil) then
                local singleTable = {};
                singleTable.Container = eqEntry.Container;
                singleTable.Item = eqEntry.Item;
                singleTable.Name = resource.Name[1];
                singleTable.Resource = resource;
                equipTable[v] = singleTable;
            end
        end
    end
    return equipTable;
end

--=============================================================================
-- Return player data
-- @return {table}
--=============================================================================
-- based on code from LuAshitacast by Thorny
--=============================================================================
local GetPlayer = function()
    local playerTable = {};
    --local pEntity = AshitaCore:GetMemoryManager():GetEntity();
    local pParty = AshitaCore:GetMemoryManager():GetParty();
    local pPlayer = AshitaCore:GetMemoryManager():GetPlayer();
    --local myIndex = pParty:GetMemberTargetIndex(0);

    local mainJob = pPlayer:GetMainJob();
    playerTable.MainJob = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", mainJob);
    playerTable.MainJobLevel = pPlayer:GetJobLevel(mainJob);
    playerTable.MainJobSync = pPlayer:GetMainJobLevel();
    playerTable.Name = pParty:GetMemberName(0);
    local subJob = pPlayer:GetSubJob();
    playerTable.SubJob = AshitaCore:GetResourceManager():GetString("jobs.names_abbr", subJob);
    playerTable.SubJobLevel = pPlayer:GetJobLevel(subJob);
    playerTable.SubJobSync = pPlayer:GetSubJobLevel();
    playerTable.TP = pParty:GetMemberTP(0);

    return playerTable;
end

--=============================================================================
-- Return table with current weaponskill data
-- @return {table}
--=============================================================================
local GetWeaponskills = function()
    local skillTable = T{};
    local pPlayer = AshitaCore:GetMemoryManager():GetPlayer();

    for k,v in pairs(skills[3]) do
        if v and pPlayer:HasWeaponSkill(k) then
            skillTable:append(v);
        end
    end

    return skillTable;
end

--=============================================================================
-- Return table with current pet skill data
-- @return {table}
--=============================================================================
local function GetPetskills()
    local skillTable = T{};
    local pPlayer = AshitaCore:GetMemoryManager():GetPlayer();

    for k,v in pairs(skills.playerPet) do
        if v and pPlayer:HasAbility(k+512) then
            skillTable:append(v);
        end
    end

    return skillTable;
  end

--=============================================================================
-- Returns the table of current set BLU spells.
-- @return {table} The current set BLU spells.
--=============================================================================
-- based on code from blusets by Atom0s
--=============================================================================
local blu = {
    offset = ffi.cast('uint32_t*', ashita.memory.find('FFXiMain.dll', 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0))
};

function GetBluskills()
    local skillTable = T{};

    local ptr = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'));
    if (ptr == 0) then
        return T{ };
    end
    ptr = ashita.memory.read_uint32(ptr);
    if (ptr == 0) then
        return T{ };
    end
    --local spellTable = T(ashita.memory.read_array((ptr + blu.offset[0]) + (blu.is_blu_main() and 0x04 or 0xA0), 0x14));
    local spellTable = T(ashita.memory.read_array((ptr + blu.offset[0]) + 0x04, 0x14));

    for _,v in pairs(spellTable) do
        if skills[4][v+512] then
            skillTable:append(skills[4][v+512]);
        end
    end

    return skillTable;
end

--=============================================================================
-- Return current aftermath level
-- @return {integer}
--=============================================================================
local GetAftermathLevel = function()
    return GetBuffCount(statusID.AM1) + 2*GetBuffCount(statusID.AM2) + 3*GetBuffCount(statusID.AM3) + chains.forceAeonic;
end

--=============================================================================
-- Return action property table with aeonic property added
-- @return {table}
--=============================================================================
local GetAeonicProperty = function(action, actor)
    local propertyTable = table.copy(action.skillchain);

    if action.aeonic and (action.weapon or chains.forceAeonic > 0) and actor == playerID and GetAftermathLevel()>0 then
        local main = GetEquipment().Main;
        local range = GetEquipment().Range;
        local validMain = action.weapon == (main and main.Name) or chains.forceAeonic > 0;
        local validRange = action.weapon == (range and range.Name);
        if validMain or validRange then
            table.insert(propertyTable,1,action.aeonic);
        end
    end

    return propertyTable;
end

--=============================================================================
-- Return formatted table of valid skillchain options
-- @return {table}
--=============================================================================
local GetSkillchains = function(target)
    local actions = T{};
    local chainTable = T{};
    local levelTable = T{{},{},{},{}};

    local mainJob = GetPlayer().MainJob;
    local enableSCH = mainJob == 'SCH' and ((playerTable[playerID] and playerTable[playerID][statusID.IM]) or
                                            chains.forceImmanence);
    local enableBLU = mainJob == 'BLU' and ((playerTable[playerID] and playerTable[playerID][statusID.AL]) or
                                            (playerTable[playerID] and playerTable[playerID][statusID.CA]) or
                                            chains.forceAffinity);

    -- Create weaponskill table if it does not already exist
    -- Will update through incoming 0xAC packets
    if not actionTable.wepskill then
        actionTable.wepskill = GetWeaponskills();
    end

    -- Create petskill table if it does not already exist
    -- Will update through incoming 0xAC packets
    if T{ 'BST', 'SMN' }:contains(mainJob) and not actionTable.petskill then
            actionTable.petskill = GetPetskills();
    end

    -- Create bluskill table if it does not already exist
    -- Will update through incoming 0x44 packets
    if mainJob == 'BLU' and not actionTable.bluskill then
        actionTable.bluskill = GetBluskills();
    end

    -- Initialize actions with weaponskills
    if chains.settings.display.weapon then
        actions = actions:extend(actionTable.wepskill);
    end

    -- Add skill tables based on job and active buffs
    if chains.settings.display.pet and mainJob:any('BST','SMN') and actionTable.petskill then
        actions = actions:extend(actionTable.petskill);
    elseif chains.settings.display.spell and enableBLU and actionTable.bluskill then
        actions = actions:extend(actionTable.bluskill);
    elseif chains.settings.display.spell and enableSCH and actionTable.schskill then
        actions = actions:extend(actionTable.schskill);
    end

    -- Search for valid skillchains and store into a table per skillchain level
    -- iterate over current abilities
    for _,action in pairs(actions) do

        -- insert aeonic property
        local actionProperty = GetAeonicProperty(action,playerID);

        -- iterate over 1st property (target property)
        for _,prop1 in pairs(target.property) do
            local match = nil;

            -- iterate over 2nd property (action property) and exit after first match
            for _,prop2 in pairs(actionProperty) do
                match = chainInfo[prop1][prop2];
                if match then break end
            end

            -- store first match and exit
            if match then
                -- check for ultimate skillchain
                local checkAeonic = chainInfo[prop1].level == 3 and (target.step + GetAftermathLevel()) >= 4;
                if checkAeonic and chainInfo[prop1]['aeonic'] then
                    match = chainInfo[prop1]['aeonic'];
                end

                -- add skillchain information to table
                local skillchain = {
                    outText = ('%-17s>> Lv.%d'):fmt(action.en, match.level),
                    outProp = match.skillchain,
                }
                table.insert(levelTable[match.level],skillchain);
                break;
            end;
        end
    end

    -- Sort results to a single table based on skillchain level
    for x=4,1,-1 do
        for _,v in pairs(levelTable[x]) do
            table.insert(chainTable,v);
        end
    end

    return chainTable;
end

--=============================================================================
-- Print formatted error information
--=============================================================================
-- Copied from tHotBar by Thorny as part of ParseActionPacket
--=============================================================================
local function Error(text)
    local color = ('\30%c'):format(68);
    local highlighted = color .. string.gsub(text, '$H', '\30\01\30\02');
    highlighted = string.gsub(highlighted, '$R', '\30\01' .. color);
    print(chat.header(addon.name) .. highlighted .. '\30\01');
end

--=============================================================================
-- Return action packet data in a table format
-- @return {table}
--=============================================================================
-- based on code from tHotBar by Thorny
-- https://github.com/Windower/Lua/blob/dev/addons/libs/packets/data.lua
-- https://github.com/Windower/Lua/blob/dev/addons/libs/packets/fields.lua
--=============================================================================
function ParseActionPacket(e)
    local bitData;
    local bitOffset;
    local maxLength = e.size * 8;

    local function UnpackBits(length)
        if ((bitOffset + length) > maxLength) then
            maxLength = 0; --Using this as a flag since any malformed fields mean the data is trash anyway.
            return 0;
        end
        local value = ashita.bits.unpack_be(bitData, 0, bitOffset, length);
        bitOffset = bitOffset + length;
        return value;
    end

    local pendingActionPacket = T{};
    bitData = e.data_raw;
    bitOffset = 40;

    pendingActionPacket.UserId = UnpackBits(32);
    local targetCount = UnpackBits(6);
    bitOffset = bitOffset + 4; --Unknown 4 bits
    pendingActionPacket.Type = UnpackBits(4);
    pendingActionPacket.Id = UnpackBits(32); --{unknown[15:0], param[15:0]}
    bitOffset = bitOffset + 32; --Unknown 32 bits --{recast[31:0]}?

    pendingActionPacket.Targets = T{};
    for i = 1,targetCount do
        local target = T{};
        target.Id = UnpackBits(32);
        local actionCount = UnpackBits(4);
        target.Actions = T{};
        for j = 1,actionCount do
            local action = {};
            action.Reaction = UnpackBits(5);
            action.Animation = UnpackBits(12);
            action.SpecialEffect = UnpackBits(7);
            action.Knockback = UnpackBits(3);
            action.Param = UnpackBits(17);
            action.Message = UnpackBits(10);
            action.Flags = UnpackBits(31);

            local hasAdditionalEffect = (UnpackBits(1) == 1);
            if hasAdditionalEffect then
                local additionalEffect = {};
                additionalEffect.Damage = UnpackBits(10); --{effect[3:0],animation[5:0]}
                additionalEffect.Param = UnpackBits(17);
                additionalEffect.Message = UnpackBits(10);
                action.AdditionalEffect = additionalEffect;
            end

            local hasSpikesEffect = (UnpackBits(1) == 1);
            if hasSpikesEffect then
                local spikesEffect = {};
                spikesEffect.Damage = UnpackBits(10); --{effect[3:0],animation[5:0]}
                spikesEffect.Param = UnpackBits(14);
                spikesEffect.Message = UnpackBits(10);
                action.SpikesEffect = spikesEffect;
            end

            target.Actions:append(action);
        end
        pendingActionPacket.Targets:append(target);
    end

    if (maxLength == 0) then
        Error(string.format('Malformed action packet detected.  Type:$H%u$R User:$H%u$R Targets:$H%u$R', pendingActionPacket.Type, pendingActionPacket.UserId, #pendingActionPacket.Targets));
        pendingActionPacket.Targets = T{}; --Blank targets so that it doesn't register bad info later.
    end

    return pendingActionPacket;

end

--=============================================================================
-- event: load
-- desc: Event called when the addon is being loaded.
--=============================================================================
ashita.events.register('load', 'load_cb', function ()
    playerID = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0);
end);

--=============================================================================
-- event: unload
-- desc: Event called when the addon is being unloaded.
--=============================================================================
ashita.events.register('unload', 'unload_cb', function ()
    settings.save();
end);

--=============================================================================
-- event: packet_in
-- desc: Event called when the addon is processing incoming packets.
--=============================================================================
ashita.events.register('packet_in', 'packet_in_cb', function (e)
    --[[ Valid Arguments
        e.id                 - (ReadOnly) The id of the packet.
        e.size               - (ReadOnly) The size of the packet.
        e.data               - (ReadOnly) The data of the packet.
        e.data_raw           - The raw data pointer of the packet. (Use with FFI.)
        e.data_modified      - The modified data.
        e.data_modified_raw  - The modified raw data. (Use with FFI.)
        e.chunk_size         - The size of the full packet chunk that contained the packet.
        e.chunk_data         - The data of the full packet chunk that contained the packet.
        e.chunk_data_raw     - The raw data pointer of the full packet chunk that contained the packet. (Use with FFI.)
        e.injected           - (ReadOnly) Flag that states if the packet was injected by Ashita or an addon/plugin.
        e.blocked            - Flag that states if the packet has been, or should be, blocked.
    --]]

    -- Action
    --[[ actionPacket.Type
        [1] = 'Melee attack',
        [2] = 'Ranged attack finish',
        [3] = 'Weapon Skill finish',
        [4] = 'Casting finish',
        [5] = 'Item finish',
        [6] = 'Job Ability',
        [7] = 'Weapon Skill start',
        [8] = 'Casting start',
        [9] = 'Item start',
        [11] = 'NPC TP finish',
        [12] = 'Ranged attack start',
        [13] = 'Avatar TP finish',
        [14] = 'Job Ability DNC',
        [15] = 'Job Ability RUN',
    --]]
    if e.id == 0x28 then

        -- Save a little bit of processing for packets that won't relate to SC..
        local type = ashita.bits.unpack_be(e.data_raw, 82, 4); -- byte: 0xA, bit: 0x2
        if not T{ 3, 4, 6, 11, 13, 14 }:contains(type) then
            return;
        end

        local actionPacket = ParseActionPacket(e);

        -- Only the primary target and action are parsed assuming that is all that apply
        local actor = actionPacket.UserId;
        local target = actionPacket.Targets[1];

        -- exit if target is nill due to corrupted packet
        if not target then
            return;
        end

        local targetAction = target.Actions[1];

        -- Overload packet type for pet actions (?)
        -- Prevents Weapon Bash from matching as an actionSkill
        local category = PetMessageTypes:contains(targetAction.Message) and 13 or actionPacket.Type;

        -- capture valid action skill and added effect property if there is a match
        local actionSkill = skills[category] and skills[category][bit.band(actionPacket.Id,0xFFFF)];
        local effectProperty = targetAction.AdditionalEffect and SkillPropNames[bit.band(targetAction.AdditionalEffect.Damage,0x3F)];

        --debug ===============================================================
        if chains.debug and T{ 3, 6, 13, 14 }:contains(actionPacket.Type) then
            local out = ('Type: %s -> %s, Id: %s'):fmt(actionPacket.Type, category, actionPacket.Id);
            if actionSkill then
                out = out .. (' Skill: %s'):fmt(actionSkill.en);
            end
            print(chat.header('0x28'):append(chat.error(out)));
            if targetAction then
                out = ('Action Message: %s'):fmt(targetAction.Message);
                if targetAction.AdditionalEffect then
                    out = out .. (' Effect: %s'):fmt(targetAction.AdditionalEffect.Damage);
                end
                if effectProperty then
                    out = out .. (' Property: %s'):fmt(effectProperty);
                end
            end
            print(chat.header('0x28'):append(chat.error(out)));
        end
        --=====================================================================

        -- Check for valid action skill with valid added effect propery - after first setp
        if actionSkill and effectProperty then
            local step = (targetTable[target.Id] and targetTable[target.Id].step or 1) + 1
            local delay = actionSkill and actionSkill.delay or 3
            local level = chainInfo[effectProperty].level

            -- Check for Lv.3 -> Lv.3 and bump to Lv.4 for closure
            if level == 3 and targetTable[target.Id] and targetTable[target.Id].property[1] == effectProperty then
                level = 4;
            end
            local closed = level == 4;

            targetTable[target.Id] = {
                en=actionSkill.en,
                property={effectProperty},
                ts=os.time(),
                dur=8-step+delay,
                wait=delay,
                step=step,
                closed=closed,
            };

        -- Check for valid actor skill with valid message - generic first step (excluding chainbound)
        -- Include spells when SCH Immanence or BLU Azure Lore / Chain Affinity is active
        -- Immanence and Chain Affinity buff status cleared on use
        elseif actionSkill and MessageTypes:contains(targetAction.Message) and (actionPacket.Type ~= 4 or (playerTable[actor])) then
            local delay = actionSkill and actionSkill.delay or 3
            targetTable[target.Id] = {
                en=actionSkill.en,
                property=GetAeonicProperty(actionSkill,actor),
                ts=os.time(),
                dur=7+delay,
                wait=delay,
                step=1,
            };

        -- Check for valid actor skill with chainbound message - chainbound first step
        -- Could be combined with previous first setp check
        elseif actionSkill and (targetAction.Message == 529) then
            targetTable[target.Id] = {
                en=actionSkill.en,
                property=actionSkill.skillchain,
                ts=os.time(),
                dur=9,
                wait=2,
                step=1,
                bound=targetAction.Param,
            };
        end

        -- Clear out used spell abilities
        if actionSkill and actionPacket.Type == 4 and playerTable[actor] then
            local buffID = playerTable[actor][statusID.CA] and statusID.CA or playerTable[actor][statusID.IM] and statusID.IM;
            if buffID then
                playerTable[actor][buffID] = nil;
            end
        end

        -- Capture buff information for each player
        if actionPacket.Type == 6 and ChainBuffTypes:containskey(targetAction.Param) then
            playerTable[actor] = playerTable[actor] or {};
            playerTable[actor][targetAction.Param] = os.time() + ChainBuffTypes[targetAction.Param].duration;
        end

    -- Action Message - Clear buff when getting '206 - ${target}'s ${status} effect wears off'.
    --  only works to clear local player
    elseif e.id == 0x29 and struct.unpack('H', e.data, 0x18+1) == 206 and struct.unpack('I', e.data, 8+1) == playerID then
        local effect = struct.unpack('H', e.data, 0xC+1)
        if playerTable[playerID] and playerTable[playerID][effect] then
            playerTable[playerID][effect] = nil;
        end

    -- Character Abilities (Weaponskills and BST/SMN PetSkills)
    elseif e.id == 0x0AC then --and e.data:sub(5) ~= actionTable.lastAC then
        actionTable.wepskill = T{};
        actionTable.petskill = T{};

        -- Packet contains one bit per ability to indicate if the ability is available
        -- * Byte in packet = floor(abilityID / 8) + 1
        -- * Bit in byte = abilityID % 8
        -- Logic does the following:
        -- * extract byte
        -- * shift bits right to move relavent bit to bit[0]
        -- * mask upper bits and compare to 1 (or >0)
        -- * alt equation: bit.band(bit.rshift(data:byte(math.floor(k/8)+1),(k%8)),0x01) == 1

        -- Weaponskills
        local data = e.data:sub(5);
        for k,v in pairs(skills[3]) do
            if math.floor((data:byte(math.floor(k/8)+1)%2^(k%8+1))/2^(k%8)) == 1 then
                table.insert(actionTable.wepskill, v);
            end
        end

        -- BST/SMN PetSkills - fix: skip if not BST or SMN?
        data = e.data:sub(69);
        for k,v in pairs(skills.playerPet) do
            if math.floor((data:byte(math.floor(k/8)+1)%2^(k%8+1))/2^(k%8)) == 1 then
                table.insert(actionTable.petskill, v);
            end
        end

        --actionTable.lastAC = e.data:sub(5); --dedupe?

    -- BLU spells - e.data:byte(5) == 0x10 indicates BLU, e.data:byte(6) == 0 indicates main job
    elseif e.id == 0x44 and e.data:byte(5) == 0x10 and e.data:byte(6) == 0 then -- and e.data:sub(9, 18) ~= actionTable.last44 then
        actionTable.bluskill = T{};

        --Iterate through bytes 8+1 through 27+1 - corresponds to the 20 BLU spell slots
        for x = 8+1, 27+1 do
            local match = skills[4][e.data:byte(x)+512]
            if match then
                table.insert(actionTable.bluskill, match);
            end
        end

        --actionTable.last44 = e.data:sub(9, 18); --dedupe?
    end

end);

--=============================================================================
-- event: d3d_present
-- desc: Event called when the Direct3D device is presenting a scene.
--=============================================================================
ashita.events.register('d3d_present', 'present_cb', function ()

    -- Capture current time for comparison
    local now = os.time();

    -- Remove stale playerTable entries
    for pk,pv in pairs(playerTable) do
        for bk,bv in pairs(playerTable[pk]) do
            if now > bv then
                playerTable[pk][bk] = nil;
            end
        end
        if table.length(pv) == 0 then
            playerTable[pk] = nil;
        end
    end

    -- Remove stale targetTable entries
    for k,v in pairs(targetTable) do
        if v.ts and now-v.ts > v.dur then
            targetTable[k] = nil;
        end
    end

    -- UI
    local targetId = AshitaCore:GetMemoryManager():GetTarget():GetServerId(0);
    local render = targetId ~= nil and targetTable[targetId] and targetTable[targetId].dur-(now-targetTable[targetId].ts) > 0;

    if render or chains.visible or chains.position then

        local flags = bit.bor(
            ImGuiWindowFlags_NoDecoration,
            ImGuiWindowFlags_AlwaysAutoResize,
            ImGuiWindowFlags_NoSavedSettings,
            ImGuiWindowFlags_NoFocusOnAppearing,
            ImGuiWindowFlags_NoNav)

        imgui.SetNextWindowBgAlpha(0.8)
        imgui.SetNextWindowSize({ 350, -1 }, ImGuiCond_Always)
        imgui.SetNextWindowSizeConstraints({ -1, -1 }, { FLT_MAX, FLT_MAX })

        if chains.position then
            imgui.SetNextWindowPos({ chains.position.x, chains.position.y }, ImGuiCond_Always, { 0, 0 });
        else
            imgui.SetNextWindowPos({ chains.settings.position_x, chains.settings.position_y }, ImGuiCond_Appearing, { 0, 0 });
        end

        if (imgui.Begin('chains', true, flags)) then

            if render then
                local timediff = now-targetTable[targetId].ts;
                local timer = targetTable[targetId].dur-timediff;

                -- Timer
                if not targetTable[targetId].closed then
                    if timediff < targetTable[targetId].wait then
                        imgui.TextColored({ 1.0, 0.0, 0.0, 1.0 },('Wait  %d'):fmt(targetTable[targetId].wait-timediff));
                    else
                        imgui.TextColored({ 0.0, 1.0, 0.0, 1.0 },('Go!   %d'):fmt(timer));
                    end
                else
                    imgui.Text(('Burst %d'):fmt(timer));
                end

                -- Step, active properties and burst element
                imgui.Separator();
                imgui.Text(('Step: %d >> %s'):fmt(targetTable[targetId].step, targetTable[targetId].en));
                imgui.Text('[');
                imgui.SameLine();
                if targetTable[targetId].bound then
                    imgui.Text(('Chainbound Lv.%d'):fmt(targetTable[targetId].bound));
                else
                    for k,v in pairs(targetTable[targetId].property) do
                        if k > 1 then
                            imgui.SameLine(0,0);
                            imgui.Text(',');
                            imgui.SameLine();
                        end
                        imgui.TextColored(GetPropertyColor(v),v);
                    end
                end
                imgui.SameLine();
                imgui.Text(']');
                if targetTable[targetId].step > 1 then
                    imgui.SameLine();
                    imgui.Text(' (');
                    imgui.SameLine();
                    for k,v in pairs(chainInfo[targetTable[targetId].property[1]].burst) do
                        if k > 1 then
                            imgui.SameLine(0,0);
                            imgui.Text(',');
                            imgui.SameLine();
                        end
                        imgui.TextColored(GetPropertyColor(v),v);
                    end
                    imgui.SameLine();
                    imgui.Text(')');
                end

                -- Available skillchains
                imgui.Separator();
                if not targetTable[targetId].closed then
                    local skillchains = GetSkillchains(targetTable[targetId]);
                    for _,v in pairs(skillchains) do
                        imgui.Text(v.outText);
                        imgui.SameLine();
                        imgui.TextColored(GetPropertyColor(v.outProp), v.outProp);
                    end
                end
            elseif chains.visible then
                imgui.Text('');
                imgui.Text('                 --- Chains ---                 ');
                imgui.Text('         Click and drag to move display         ');
                imgui.Text('');
            end

            if chains.position then
                chains.position = nil;
            end

            -- store current window position
            chains.settings.position_x, chains.settings.position_y = imgui.GetWindowPos();
        end
        imgui.End();
    end

end);

--=============================================================================
-- event: command
-- desc: Event called when the addon is processing a command.
--=============================================================================
ashita.events.register('command', 'command_cb', function (e)
    --[[ Valid Arguments
        e.mode       - (ReadOnly) The mode of the command.
        e.command    - (ReadOnly) The raw command string.
        e.injected   - (ReadOnly) Flag that states if the command was injected by Ashita or an addon/plugin.
        e.blocked    - Flag that states if the command has been, or should be, blocked.
    --]]

    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/chains')) then
        return;
    end

    -- Block all related commands..
    e.blocked = true;

    --========================================================================
    -- Debug
    --========================================================================
    if (#args == 2) and (args[2] == 'debug') then
        chains.debug = not chains.debug;
        print(chat.header(addon.name):append(chat.message('%s: %s'):fmt(args[2], chains.debug and 'on' or 'off')));
    end

    --========================================================================
    -- Settings
    --========================================================================
    if (#args == 2) and chains.settings.display:containskey(args[2]) then
        chains.settings.display[args[2]] = not chains.settings.display[args[2]];
        local outText = '%sskill: %s'
        if args[2] == 'color' then
            outText = '%s: %s'
        end
        print(chat.header(addon.name):append(chat.message(outText):fmt(args[2], chains.settings.display[args[2]] and 'on' or 'off')));
    end

    --========================================================================
    -- Window management
    --========================================================================
    if (#args == 2) and (args[2] == 'visible') then
        chains.visible = not chains.visible;
    end

    if (#args == 4) and (args[2] == 'move') then
        chains.position = {
            x = args[3]:number(),
            y = args[4]:number(),
        };
        print(chat.header(addon.name):append(chat.message('Window position set to x: %s, y: %s'):fmt(chains.position.x, chains.position.y)));
    end

end);