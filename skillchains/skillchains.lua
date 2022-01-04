--[[
Copyright © 2017, Ivaar
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright
  notice, this list of conditions and the following disclaimer in the
  documentation and/or other materials provided with the distribution.
* Neither the name of SkillChains nor the
  names of its contributors may be used to endorse or promote products
  derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL IVAAR BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

addon.author = 'Ivaar';
addon.name = 'SkillChains';
addon.version = '1.20.08.19';

require 'common';
--require 'timer';
local skills = require('skills');
local settings = require('settings');

local jobs = T{'WAR','MNK','WHM','BLM','RDM','THF','PLD','DRK','BST','BRD','RNG','SAM','NIN','DRG','SMN','BLU','COR','PUP','DNC','SCH','GEO','RUN'};

local default = T{};
default.Show = {burst=jobs, pet=T{'BST','SMN'}, props=jobs, spell=T{'SCH','BLU'}, step=jobs, timer=jobs, weapon=jobs};
default.aeonic = false;
default.color = false;
default.display = T{};
default.display.bg = true;
default.display.bgcolor = math.d3dcolor(102, 0, 0, 0);
default.display.color = math.d3dcolor(255,255,255,255);
default.display.font = 'Consolas';
default.display.pos = T{x=0,y=500};
default.display.size = 10;

-- Skillchains Variables
local sc = T{
    zoning = false,
    config = settings.load(default),
};

--[[
* Updates the addon settings.
*
* @param {table} s - The new settings table to use for the addon settings. (Optional.)
--]]
local function update_settings(s)
    -- Update the settings table..
    if (s ~= nil) then
        sc.config = s;
    end

    -- Save the current settings..
    settings.save();
end

--[[
* Registers a callback for the settings to monitor for character switches.
--]]
settings.register('settings', 'settings_update', update_settings);

local function S(list)
    local set = {};
    for _, l in ipairs(list) do set[l] = true; end
    return set;
end

local aeonic_weapon = S{20515,20594,20695,20843,20890,20935,20977,21025,21082,21147,21485,21694,21753,22117};
local message_ids = S{2,110,161,162,185,187,317,802};
local pet_commands = S{110,317};
local buff_dur = {[163]=40,[164]=30,[470]=60};
local info = {member = {}};

local colors = {};           -- Color codes by Sammeh
colors.Light =         '|c0xFFFFFFFF|';
colors.Dark =          '|c0xFF0000CC|';
colors.Ice =           '|c0xFF00FFFF|';
colors.Water =         '|c0xFF00FFFF|';
colors.Earth =         '|c0xFF997600|';
colors.Wind =          '|c0xFF66FF66|';
colors.Fire =          '|c0xFFFF0000|';
colors.Lightning =     '|c0xFFFF00FF|';
colors.Gravitation =   '|c0xFF663300|';
colors.Fragmentation = '|c0xFFFA9CF7|';
colors.Fusion =        '|c0xFFFF6666|';
colors.Distortion =    '|c0xFF3399FF|';
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

local skillchain = {'Light','Darkness','Gravitation','Fragmentation','Distortion','Fusion','Compression','Liquefaction','Induration','Reverberation','Transfixion','Scission','Detonation','Impaction','Radiance','Umbra'};

local sc_info = {
    Radiance = {'Fire','Wind','Lightning','Light', lvl=4},
    Umbra = {'Earth','Ice','Water','Dark', lvl=4},
    Light = {'Fire','Wind','Lightning','Light', Light={4,'Light'}, aeonic={4,'Radiance'}, lvl=3},
    Darkness = {'Earth','Ice','Water','Dark', Darkness={4,'Darkness'}, aeonic={4,'Umbra'}, lvl=3},
    Gravitation = {'Earth','Dark', Distortion={3,'Darkness'}, Fragmentation={2,'Fragmentation'}, lvl=2},
    Fragmentation = {'Wind','Lightning', Fusion={3,'Light'}, Distortion={2,'Distortion'}, lvl=2},
    Distortion = {'Ice','Water', Gravitation={3,'Darkness'}, Fusion={2,'Fusion'}, lvl=2},
    Fusion = {'Fire','Light', Fragmentation={3,'Light'}, Gravitation={2,'Gravitation'}, lvl=2},
    Compression = {'Darkness', Transfixion={1,'Transfixion'}, Detonation={1,'Detonation'}, lvl=1},
    Liquefaction = {'Fire', Impaction={2,'Fusion'}, Scission={1,'Scission'}, lvl=1},
    Induration = {'Ice', Reverberation={2,'Fragmentation'}, Compression={1,'Compression'}, Impaction={1,'Impaction'}, lvl=1},
    Reverberation = {'Water', Induration={1,'Induration'}, Impaction={1,'Impaction'}, lvl=1},
    Transfixion = {'Light', Scission={2,'Distortion'}, Reverberation={1,'Reverberation'}, Compression={1,'Compression'}, lvl=1},
    Scission = {'Earth', Liquefaction={1,'Liquefaction'}, Reverberation={1,'Reverberation'}, Detonation={1,'Detonation'}, lvl=1},
    Detonation = {'Wind', Compression={2,'Gravitation'}, Scission={1,'Scission'}, lvl=1},
    Impaction = {'Lightning', Liquefaction={1,'Liquefaction'}, Detonation={1,'Detonation'}, lvl=1},
};

ashita.events.register('unload', 'unload_cb', function()
    local display = AshitaCore:GetFontManager():Get('skill_props');
    sc.config.display.pos = {x=display:GetPositionX(),y=display:GetPositionY() };
    AshitaCore:GetFontManager():Delete('skill_props');
    settings.save();
end);

local function reset()
    resonating = {};
    buffs = {[info.player] = {}};
end

local function initialize()
    setting = {};
    for k,v in pairs(sc.config.Show) do
        setting[k] = S(sc.config.Show[k])[info.job];
    end
    if setting.spell and info.job == 20 then
        info.abilities = skills[20];
    end
    reset();
end

ashita.events.register('load', 'load_cb', function()
    skill_props = AshitaCore:GetFontManager():Create('skill_props');
    skill_props:GetBackground():SetColor(sc.config.display.bgcolor);
    skill_props:GetBackground():SetVisible(sc.config.display.bg);
    skill_props:SetFontFamily(sc.config.display.font);
    skill_props:SetFontHeight(sc.config.display.size);
    skill_props:SetPositionX(sc.config.display.pos.x);
    skill_props:SetPositionY(sc.config.display.pos.y);
    --skill_props:SetVisibility(sc.config.visibility);
    skill_props:SetColor(sc.config.display.color);

    local player = AshitaCore:GetMemoryManager():GetPlayer();
    info.job = jobs[player:GetMainJob()];
    info.player = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0);
    initialize();
    if setting.weapon then
        local equip = AshitaCore:GetMemoryManager():GetInventory():GetEquippedItem(0).Index;
        info.main_bag = math.floor(equip/256);
        info.main =  math.floor(equip%256);
        update_weapon();
        info.weapon_skills = {};
        for k = 1, 239 do
            if skills[3][k] and player:HasWeaponSkill(k) then
                table.insert(info.weapon_skills, 1, skills[3][k]);
            end
        end
    end
end);

function update_weapon()
    local main_weapon = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(info.main_bag, info.main).Id;
    if main_weapon ~= 0 then
        info.aeonic = aeonic_weapon[main_weapon] or
            info.range and aeonic_weapon[AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(info.range_bag, info.range).Id];
        return;
    end
    if not check_weapon then
        check_weapon = ashita.tasks.once(10, function()
            check_weapon = nil;
            update_weapon();
        end);
    end
end

local function aeonic_am(step)
    for x = 270, 272 do
        if buffs[info.player][x] then
            return 272 - x < step;
        end
    end
    return false;
end

local function aeonic_prop(ability, actor)
    if not ability.aeonic or not info.aeonic and actor == info.player or not sc.config.aeonic and info.player ~= actor then
        return ability.skillchain;
    end
    return {ability.skillchain[1], ability.skillchain[2], ability.aeonic};
end

local function check_props(old, new)
    for k = 1, #old do
        local first = old[k]
        local combo = sc_info[first]
        for i = 1, #new do
            local second = new[i]
            local result = combo[second]
            if result then
                return unpack(result)
            end
            if #old > 3 and combo.lvl == sc_info[second].lvl then
                break
            end
        end
    end
end

local function add_skills(t, ability, active, aeonic)
    local tt = {{},{},{},{}};
    for k=1,#ability do
        local lv, prop = check_props(active, aeonic_prop(ability[k], info.player));
        if prop then
            prop = aeonic and lv == 4 and sc_info[prop].aeonic[2] or prop;
            tt[lv][#tt[lv]+1] = sc.config.color and
                string.format('%-17s>> Lv.%d %s%-14s|r',ability[k].en, lv, colors[prop], prop) or
                string.format('%-17s>> Lv.%d %-14s',ability[k].en, lv, prop);
        end
    end
    for x=4,1,-1 do
        for k=1,#tt[x] do
            t[#t+1] = tt[x][k];
        end
    end
    return t;
end

local function check_results(reson)
    local t = {};
    t = info.abilities and add_skills(t, info.abilities, reson.active) or t;
    t = info.weapon_skills and add_skills(t, info.weapon_skills, reson.active, info.aeonic and aeonic_am(reson.step)) or t;
    return table.concat(t, '\n');
end

local function colorize(t)
    local temp;
    if sc.config.color then
        temp = {};
        for k=1,#t do
            temp[k] = string.format('%s%s|r',colors[t[k]], t[k]);
        end
    end
    return table.concat(temp or t, ',');
end

ashita.events.register('d3d_endscene', 'endscene_cb', function(isRenderingBackBuffer)

    -- isRenderingBackBuffer is a flag that will be true when the game is currently rendering to the back buffer.
    -- Check for zoning..
    if (not isRenderingBackBuffer or sc.zoning) then
        return;
    end

    local targ_id = AshitaCore:GetMemoryManager():GetTarget():GetServerId(0);
    local now = os.time();
    for k,v in pairs(resonating) do
        if v.ts and now-v.ts > v.dur then
            resonating[k] = nil;
        end
    end
    if targ_id ~= nil and resonating[targ_id] and resonating[targ_id].dur-(now-resonating[targ_id].ts) > 0 then
        local timediff = now-resonating[targ_id].ts;
        local timer = resonating[targ_id].dur-timediff;
        resonating[targ_id].disp_info = resonating[targ_id].disp_info or {};
        if not resonating[targ_id].closed then
            resonating[targ_id].disp_info[1] = timediff < resonating[targ_id].wait and
                string.format('|c0xFFFF0000|Wait  %d|r', resonating[targ_id].wait-timediff) or
                string.format('|c0xFF00FF00|Go!   %d|r', timer);
        elseif setting.burst then
            resonating[targ_id].disp_info[1] = string.format('Burst %d', timer);
        else
            resonating[targ_id] = nil;
            return;
        end
        if not resonating[targ_id].disp_info[2] then
            if setting.step then
                table.insert(resonating[targ_id].disp_info, string.format('Step: %d >> %s', resonating[targ_id].step, resonating[targ_id].en));
            end
            local props = setting.props and (not resonating[targ_id].bound and colorize(resonating[targ_id].active) or string.format('Chainbound Lv.%d', resonating[targ_id].bound));
            local burst = setting.burst and resonating[targ_id].step > 1 and colorize(sc_info[resonating[targ_id].active[1]]);
            if props and burst then
                table.insert(resonating[targ_id].disp_info, string.format('[%s] (%s)', props, burst));
            elseif props then
                table.insert(resonating[targ_id].disp_info, string.format('[%s]', props));
            elseif burst then
                table.insert(resonating[targ_id].disp_info, string.format('(%s)', burst));
            end
            if not resonating[targ_id].closed then
                table.insert(resonating[targ_id].disp_info, check_results(resonating[targ_id]));
            end
        end
        skill_props:SetText(table.concat(resonating[targ_id].disp_info,'\n'));
        skill_props:SetVisible(true);
    elseif not visible then
        skill_props:SetVisible(false);
    end
end);

local function update_abilities(cat, from, to, data, pos)
    local t = {};
    for x=from,to do
        if skills[cat][x] and math.floor((data:byte(math.floor(x/8)+1)%2^(x%8+1))/2^(x%8)) == 1 then
            table.insert(t, 1, skills[cat][x]);
        end
    end
    return t;
end

local function check_buff(t, i)
    if t[i] == true or t[i] - os.time() > 0 then
        return true;
    end
    t[i] = nil;
end

local function chain_buff(t)
    local i = t[164] and 164 or t[470] and 470;
    if i and check_buff(t, i) then
        t[i] = nil;
        return true;
    end
    return t[163] and check_buff(t, 163);
end

ashita.events.register('packet_in', 'packet_in_cb', function(e)

    -- Packet: Zone Leave
    if (e.id == 0x000B) then
        --print('packet_in - 0x000B'); --debug
        sc.zoning = true;
        return;
    end

    -- Packet: Inventory Update Completed
    if (e.id == 0x001D) then
        --print('packet_in - 0x001D'); --debug
        sc.zoning = false;
        return;
    end

    if e.id == 0x0A then
        reset()
    -- Action
    elseif e.id == 0x28 then
        --print('packet_in - 0x28'); --debug
        local actor = struct.unpack('I', e.data, 6);
        local category = ashita.bits.unpack_be(e.data_raw, 82, 4);
        local param = ashita.bits.unpack_be(e.data_raw, 86, 16);
        local effect = ashita.bits.unpack_be(e.data_raw, 213, 17);
        local msg = ashita.bits.unpack_be(e.data_raw, 230, 10);
        category = pet_commands[msg] and 13 or category
        local ability = skills[category] and skills[category][param]

        if ability and (category ~= 4 or buffs[actor] and chain_buff(buffs[actor]) or ashita.bits.unpack_be(e.data_raw, 271, 1) == 1) then
            local mob = ashita.bits.unpack_be(e.data_raw, 150, 32);
            local prop = skillchain[ashita.bits.unpack_be(e.data_raw,272, 6)];
            if prop then
                local level = sc_info[prop].lvl
                local reson = resonating[mob]
                local delay = ability and ability.delay or 3
                local step = (reson and reson.step or 1) + 1

                if level == 3 and reson and ability then
                    level = check_props(reson.active, aeonic_prop(ability, actor))
                end

                local closed = step > 5 or level == 4

                resonating[mob] = {en=ability.en, active={prop}, ts=os.time(), dur=8-step+delay, wait=delay, step=step, closed=closed};
            elseif message_ids[msg] then
                local delay = ability and ability.delay or 3
                resonating[mob] = {en=ability.en, active=aeonic_prop(ability, actor), ts=os.time(), dur=7+delay, wait=delay, step=1};
            elseif msg == 529 then
                resonating[mob] = {en=ability.en, active=ability.skillchain, ts=os.time(), dur=9, wait=2, step=1, bound=effect};
            end
        elseif category == 6 and buff_dur[effect] then
            buffs[actor] = buffs[actor] or {};
            buffs[actor][effect] = buff_dur[effect] + os.time();
        end
    -- Action Message
    elseif e.id == 0x29 and struct.unpack('H', e.data, 25) == 206 and struct.unpack('I', e.data, 9) == info.player then
        --print('packet_in - 0x29'); --debug
        local effect = struct.unpack('H', e.data, 13)
        if buffs[info.player][effect] then
            buffs[info.player][effect] = nil;
        end
    -- Equip - Main
    elseif e.id == 0x50 and setting.weapon and e.data:byte(6) == 0 then
        --print('packet_in - 0x50.0'); --debug
        info.main = e.data:byte(5);
        info.main_bag = e.data:byte(7);
        update_weapon();
    -- Equip - Range
    elseif e.id == 0x50 and e.data:byte(6) == 2 then
        --print('packet_in - 0x50.2'); --debug
        info.range = e.data:byte(5);
        info.range_bag = e.data:byte(7);
        update_weapon();
    -- CP data
    elseif e.id == 0x63 and e.data:byte(5) == 9 then
        --print('packet_in - 0x63'); --debug
        local set_buff = {};
        for n=1,32 do
            local buff = struct.unpack('H', e.data, n*2+7);
            if buff_dur[buff] or buff > 269 and buff < 273 then
            --    set_buff[buff] = math.floor(struct.unpack('I', data, n*4+69)/60+1510890319.1);
                set_buff[buff] = true;
            end
        end
        buffs[info.player] = set_buff;
    --[[elseif id == 0x076 then
        local pos = 5;
        for i = 1,5 do
            local id = struct.unpack('I', data, pos);
            if id == 0 then
                if not info.member[i] then
                    break;
                end
        ]]--        buffs[info.member[i]] = nil;
        --[[        info.member[i] = nil;
            else
                info.member[i] = id;
                local set_buff = {};
                for n=0,31 do
                    local buff = data:byte(pos+16+n)+256*(math.floor(data:byte(pos+8+math.floor(n/4))/4^(n%4))%4);
                    if buff_dur[buff] then
                        set_buff[buff] = true;
                    end
                end
                buffs[id] = set_buff;
            end
            pos = pos + 48;
        end]]
    -- Character Abilities
    elseif e.id == 0x0AC and e.data:sub(5) ~= info.lastAC then
        --print('packet_in - 0x0AC'); --debug
        if setting.weapon then
            info.weapon_skills = update_abilities(3, 1, 255, e.data:sub(5));
        end
        if setting.pet then
            info.abilities = update_abilities(13, 512, 782, e.data:sub(69));
        end
        info.lastAC = e.data:sub(5);
    -- Pet Stat?
    elseif e.id == 0x44 and e.data:byte(5) == 0x10 and e.data:byte(6) == 0 and setting.spell and e.data:sub(9, 18) ~= info.last44 then
        --print('packet_in - 0x44'); --debug
        local t = {};
        for x = 9, 28 do
            if skills[4][e.data:byte(x)+512] then
               t[#t+1] = skills[4][e.data:byte(x)+512];
            end
        end
        info.abilities = t
        info.last44 = e.data:sub(9, 18);
    end
    return false;
end)

ashita.events.register('packet_out', 'packet_out_cb', function(e)
    if e.id == 0x100 and e.data:byte(5) ~= 0 then
        --print('packet_out - 0x100'); --debug
        info = {job=jobs[e.data:byte(5)] or 'MON', member=info.member, player=info.player}
        initialize();
    end
    return false;
end);

ashita.events.register('command', 'command_cb', function(e)
    local commands = e.command:args();
    if commands[1] ~= '/sc' then
        return false;
    end

    -- Block all related commands..
    e.blocked = true;

    commands[2] = commands[2] and string.lower(commands[2]);
    if commands[2] == 'move' then
        visible = not visible;
        if visible and not skill_props:GetVisible() then
            skill_props:SetText('\n          --- SkillChains ---\n\n Hold Shift+Click and drag to move display. \n\n');
            skill_props:SetVisible(true);
        elseif not visible then
            skill_props:SetVisible(false);
        end
    elseif commands[2] == 'save' then
        settings.save();
    elseif commands[2] == 'pos' then
        skill_props:SetPositionX(commands[3]:tonumber());
        skill_props:SetPositionY(commands[4]:tonumber());
    elseif sc.config.Show[commands[2]] then
        if not S(sc.config.Show[commands[2]])[info.job] then
            print(string.format('\31\167%s Error: \31\207unable to set %s on %s.',addon.name, commands[2], info.job));
            return true;
        end
        local key;
        if not setting[commands[2]] then
            table.insert(sc.config.Show[commands[2]], info.job);
        else
            for k,v in pairs(sc.config.Show[commands[2]]) do
                if v == info.job then
                    key = k;
                    table.remove(sc.config.Show[commands[2]], key);
                    break;
                end
            end
        end
        setting[commands[2]] = S(sc.config.Show[commands[2]])[info.job];
        print(string.format('\31\207%s: %s info will no%s be displayed on %s', addon.name, commands[2], key and ' longer' or 'w', info.job));--'t' or 'w'
    elseif type(sc.config[commands[2]]) == 'boolean' then
        sc.config[commands[2]] = not sc.config[commands[2]];
        print(string.format('\31\207%s: %s %s',addon.name, commands[2], sc.config[commands[2]] and 'on' or 'off'));
    elseif commands[2] == 'eval' then
        assert(loadstring(table.concat(commands, ' ', 3)))();
    else
        print(string.format('\31\207%s: valid commands\n\31\207  save, move, pos, burst, weapon, spell, pet\n\31\207  props, step, timer, color, aeonic',addon.name));
    end
    return true;
end);
