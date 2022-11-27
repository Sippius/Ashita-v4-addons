--[[
 *  The MIT License (MIT)
 *
 *  Copyright (c) 2014 MalRD
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to
 *  deal in the Software without restriction, including without limitation the
 *  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 *  sell copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
]]--

addon.author   = 'MalRD, zombie343, sippius(v4)';
addon.name     = 'Find';
addon.version  = '3.1.0';

require('common');
local slips = require('slips');

local STORAGES = {
    [1] = { id=0, name='Inventory' },
    [2] = { id=1, name='Safe' },
    [3] = { id=2, name='Storage' },
    [4] = { id=3, name='Temporary' },
    [5] = { id=4, name='Locker' },
    [6] = { id=5, name='Satchel' },
    [7] = { id=6, name='Sack' },
    [8] = { id=7, name='Case' },
    [9] = { id=8, name='Wardrobe' },
    [10]= { id=9, name='Safe 2' },
    [11]= { id=10, name='Wardrobe 2' },
    [12]= { id=11, name='Wardrobe 3' },
    [13]= { id=12, name='Wardrobe 4' },
    [14]= { id=13, name='Wardrobe 5' },
    [15]= { id=14, name='Wardrobe 6' },
    [16]= { id=15, name='Wardrobe 7' },
    [17]= { id=16, name='Wardrobe 8' }
};

local default_config =
{
    language    =   1
};
local config = default_config;
local inventory = AshitaCore:GetMemoryManager():GetInventory();
local resources = AshitaCore:GetResourceManager();
local MINSLIP = 1;
local MAXSLIP = #slips.ids;

-------------------------------------------------------------------------------
--Returns the real ID and name for the given inventory storage index.        --
-------------------------------------------------------------------------------
local function getStorage(storageIndex)
    return STORAGES[storageIndex].id, STORAGES[storageIndex].name;
end

-------------------------------------------------------------------------------
ashita.events.register('load', 'load_cb', function()
end );

-------------------------------------------------------------------------------
ashita.events.register('unload', 'unload_cb', function()
end );

-------------------------------------------------------------------------------
-- func : printf
-- desc : Because printing without formatting is for the birds.
-------------------------------------------------------------------------------
function printf(s,...)
    print(s:format(...));
end;

-------------------------------------------------------------------------------
-- func: find
-- desc: Attempts to match the supplied cleanString to the supplied item.
-- args: item               -> the item being matched against.
--       cleanString        -> the cleaned string being searched for.
--       useDescription     -> true if the item description should be searched.
-- returns: true if a match is found, otherwise false.
-------------------------------------------------------------------------------
local function find(item, cleanString, useDescription)
    if (item == nil) then return false end;
    if (cleanString == nil) then return false end;

    if (string.lower(item.Name[config.language]):contains(cleanString)) then
        return true;
    elseif (item.LogNameSingular[config.language] ~= nil and string.lower(item.LogNameSingular[config.language]):contains(cleanString)) then
        return true;
    elseif (item.LogNamePlural[config.language] ~= nil and string.lower(item.LogNamePlural[config.language]):contains(cleanString)) then
        return true;
    elseif (useDescription and item.Description ~= nil and item.Description[config.language] ~= nil) then
        return (string.lower(item.Description[config.language]):contains(cleanString));
    end

    return false;
end

-------------------------------------------------------------------------------
-- func: search
-- desc: Searches the player's inventory for an item that matches the supplied
--       string.
-- args: searchString       -> the string that is being searched for.
--       useDescription     -> true if the item description should be searched.
-------------------------------------------------------------------------------
local function search(searchString, useDescription)
    if (searchString == nil) then return; end
    local cleanString = AshitaCore:GetChatManager():ParseAutoTranslate(searchString, false);

    if (cleanString == nil) then return; end
    cleanString = string.lower(cleanString);

    printf("\30\08Finding \"%s\"...", cleanString);
    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    local resources = AshitaCore:GetResourceManager();

    local found = { };
    local result = { };
    local storageSlips = { };

    for k,v in ipairs(STORAGES) do
        local foundCount = 1;
        for j = 0, inventory:GetContainerCountMax(v.id), 1 do
            local itemEntry = inventory:GetContainerItem(v.id, j);
            if (itemEntry.Id ~= 0 and itemEntry.Id ~= 65535) then
                local item = resources:GetItemById(itemEntry.Id);

                if (item ~= nil) then
                    if (find(item, cleanString, useDescription)) then
                        quantity = 1;
                        if (itemEntry.Count ~= nil and item.StackSize > 1) then
                            quantity = itemEntry.Count;
                        end

                        if result[k] == nil then
                            result[k] = { };
                            found[k] = { };
                        end

                        if found[k][itemEntry.Id] == nil then
                            found[k][itemEntry.Id] = foundCount;
                            result[k][foundCount] = { name = item.Name[config.language], count = 0 };
                            foundCount = foundCount + 1;
                        end

                        result[k][found[k][itemEntry.Id]].count = result[k][found[k][itemEntry.Id]].count + quantity;
                    end

                    if find(item, 'storage slip ', false) then
                        storageSlips[#storageSlips + 1] = {item, itemEntry};
                    end
                end
            end
        end
    end

    local total = 0;
    for k,v in ipairs(STORAGES) do
        if result[k] ~= nil then
            storageID, storageName = getStorage(k);
            for _,item in ipairs(result[k]) do
                quantity = '';
                if item.count > 1 then
                    quantity = string.format('[%d]', item.count)
                end
                printf('%s: %s %s', storageName, item.name, quantity);
                total = total + item.count;
            end
        end
    end

    for k,v in ipairs(storageSlips) do
        local slip = resources:GetItemById(v[1].Id);
        local slipItems = slips.items[v[1].Id];
        local extra = v[2].Extra;

        for i,slipItemID in ipairs(slipItems) do
            local slipItem = resources:GetItemById(slipItemID);
            if (find(slipItem, cleanString, useDescription)) then
                local byte = struct.unpack('B',extra,math.floor((i - 1) / 8)+1);
                if byte < 0 then
                    byte = byte + 256;
                end

                if (hasBit(byte, bit((i - 1) % 8 + 1))) then
                    printf('%s: %s', slip.Name[config.language], slipItem.Name[config.language]);
                    total = total + 1;
                end
            end
        end
    end

    printf('\30\08Found %d matching items.', total);
end

-------------------------------------------------------------------------------
function bit(p)
    return 2 ^ (p - 1);
 end

-------------------------------------------------------------------------------
function hasBit(x, p)
    return x % (p + p) >= p;
end

local function findinslip(searchslip, item)
    if (item == nil) then
        return nil,nil
    end;

    if searchslip == 0 then
        for k,v in pairs(slips.items) do
            local slip = resources:GetItemById(k);
            for x = 1, #v do
                if item.Id == v[x] then
                    local slipItem = resources:GetItemById(item.Id);
                    --printf('%s: %s', slip.Name[config.language], slipItem.Name[config.language]);
                    return slip.Name[config.language], slipItem.Name[config.language];
                end
            end
        end
    elseif searchslip >= MINSLIP and searchslip <= MAXSLIP then
        local slip = resources:GetItemById(slips.ids[searchslip]);
        for x = 1, #slips.items[slips.ids[searchslip]] do
            if item.Id == slips.items[slips.ids[searchslip]][x] then
                local slipItem = resources:GetItemById(item.Id);
                --printf('%s: %s', slip.Name[config.language], slipItem.Name[config.language]);
                return slip.Name[config.language], slipItem.Name[config.language];
            end
        end
    else
        printf('\30\08Please enter a valid storage slip between %i and %i, inclusive.', MINSLIP, MAXSLIP);
    end
    return nil,nil;
end


-------------------------------------------------------------------------------
local function getFindArgs(cmd)
    if (not cmd:find('/find', 1, true)) then return nil; end

    local indexOf = cmd:find(' ', 1, true);
    if (cmd:find('/findslips', 1, true) or cmd:find('/finddupes', 1, true)) and indexOf == nil then
        cmdTable =     {
            [1] = cmd
        };
        return cmdTable;
    end

    --Specific /findxyz command inputs that require second argument but don't have one specified
    if indexOf == nil then
        return nil;
    end

    --All other inputs that have /find and a space " ", return both words:
    cmdTable =     {
        [1] = cmd:sub(1,indexOf-1),
        [2] = cmd:sub(indexOf+1),
    };

    return cmdTable;
end

-------------------------------------------------------------------------------
-- func: printslips
-- desc: Searches the player's inventory for any items that can be stored in
--       storage slips.
--
-- args: searchslip     -> Indicates search all slips (0) OR specifies slip to
--                         search for (1-27 index into slip_data:slip.items[])
-------------------------------------------------------------------------------
local function printslips(searchslip)

    local found = { };
    local foundSlip, foundItem;
    local result = { };
    local keyset = {};

    if searchslip == 0 then
        printf('\30\08Searching for any items that can be stored on any storage slips...');
    elseif searchslip >= MINSLIP and searchslip <= MAXSLIP then
        printf('\30\08Searching for any items that can be stored on Storage Slip #%i...', searchslip);
    else
        printf('\30\08Please enter a valid storage slip between %i and %i, inclusive.', MINSLIP, MAXSLIP);
        return;
    end

    for k,v in ipairs(STORAGES) do
        for j = 0, inventory:GetContainerCountMax(v.id), 1 do
            local itemEntry = inventory:GetContainerItem(v.id, j);
            if (itemEntry.Id ~= 0 and itemEntry.Id ~= 65535) then
                local item = resources:GetItemById(itemEntry.Id);
                if (item ~= nil) then
                    --printf('%s: %s', item.Name[config.language], itemEntry.Id)
                    foundSlip,foundItem = findinslip(searchslip, itemEntry)
                    if (foundSlip ~= nil) then
                        --keyset[#keyset+1] = foundSlip
                        --printf('%s: %s', foundSlip, foundItem)
                        --result[foundSlip] = foundItem;
                        --table.insert(found, foundItem)
                        if result[foundSlip] == nil then
                            result[foundSlip] = {}
                            table.insert(result[foundSlip], foundItem);
                            keyset[#keyset+1] = foundSlip
                            --result[foundSlip][itemEntry] = {};
                        else
                            table.insert(result[foundSlip], foundItem);
                            --result[foundSlip].itemEntry = item.Name
                        end
                    end
                end
            end
        end
    end

    --table.sort()
    local keysize = #keyset;
    local resultsize = 0;
    if keysize > 0 then
        table.sort(keyset)
        for slipIndex=1, keysize, 1 do
            for _,item in pairs(result[keyset[slipIndex]]) do
                printf('%s: %s', keyset[slipIndex],item);
                resultsize = resultsize + 1;
            end
        end
        if searchslip == 0 then
            printf("\30\08Found %i occurrence(s) of storable items in %i slips.", resultsize, keysize);
        else
            printf("\30\08Found %i occurrence(s) of storable items in storage slip #%i.", resultsize, searchslip);
        end
    else
        printf('\30\08No slip-storable items found.');
    end
end

-------------------------------------------------------------------------------
-- func: printdupes
-- desc: Searches the player's inventory for items that occupy more than one
--       inventory slot. (Note, stacks or single items will both count as 1.
--       Therefore, 2 stacks of 99 HP-Bayld will have a count of 2.)
--
-- args: none
--
-------------------------------------------------------------------------------
local function printdupes()

    local result = { };
    local dupes = {};
    local resultsize = 0;
    local dupesize = 0;

    printf('\30\08Searching for duplicate items...');
    for k,v in ipairs(STORAGES) do
        for j = 0, inventory:GetContainerCountMax(v.id), 1 do
            local itemEntry = inventory:GetContainerItem(v.id, j);
            if (itemEntry.Id ~= 0 and itemEntry.Id ~= 65535) then
                local item = resources:GetItemById(itemEntry.Id);
                if (item ~= nil) then
                        if result[item.Id] == nil then
                            result[item.Id] = 1;
                        else
                            cnt = result[item.Id] + 1
                            result[item.Id] = cnt;
                            if cnt == 2 then
                                resultsize = resultsize + 1;
                            end
                        end
                        --printf('(itemName)=%s: (itemID):%s, (result[itemID]):%s', item.Name[config.language], item.ItemId, result[item.ItemId]);
                end
            end
        end
    end

    dupesize = 0;
        if (resultsize > 0) then
            for id,cnt in pairs(result) do
                if ( tonumber(cnt) > 1 ) then
                    --printf('I %s: %d', id, cnt);
                    local dupeitem = resources:GetItemById(id);
                    dupes[id] = { name = dupeitem.Name[config.language], count=cnt };
                    dupesize = dupesize + 1;
                end
            end
        end

        if (dupesize > 0) then
            for k,v in pairs(dupes) do
                printf('%s: %d', v.name, v.count);
            end
            printf("\30\08Found %i occurrence(s) of duplicate items.", dupesize);
        else
            printf('\30\08No duplicate items found.');
            return true;
        end

end

-------------------------------------------------------------------------------
ashita.events.register('command', 'command_cb', function(e)
    local args = getFindArgs(e.command);
    if (args == nil) then return false; end

    if (args[1]:lower() == '/find' and #args <= 2) then
        search(args[2]:lower(), false);
        return true;
    elseif (args[1]:lower() == '/findmore' and #args <= 2) then
        search(args[2]:lower(), true);
        return true;
    elseif (args[1]:lower() == '/finddupes' and #args <= 1) then
        printdupes();
        return true;
    elseif (args[1]:lower() == '/findslips' and #args <= 2) then
        if #args >= 2 then
            searchslip = tonumber(args[2]:lower());
            if not searchslip then
                printf('\30\08Please enter a valid storage slip between %i and %i, inclusive.', MINSLIP, MAXSLIP);
                return false;
            else
                printslips(searchslip);
                return true;
            end
        else
            printslips(0);
        end
    end;
    return false;
end );
