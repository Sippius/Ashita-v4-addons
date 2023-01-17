--[[
* Pupsets is based on the blusets addon delivered as part of Ashita.
* It has been modified to provide similar functionality for pupetmaster.
*
* Pupsets is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Pupsets is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with Ashita.  If not, see <https://www.gnu.org/licenses/>.
--]]

addon.name      = 'pupsets';
addon.author    = 'sippius - blusets(atom0s)/pupsets-v3(DivByZero)';
addon.version   = '1.1';
addon.desc      = 'Manage pup attachments easily with slash commands.';


require('common');
local pup = require('pup');
local chat = require('chat');

--[[
* Prints the addon help information.
*
* @param {boolean} isError - Flag if this function was invoked due to an error.
--]]
local function print_help(isError)
    -- Print the help header..
    if (isError) then
        print(chat.header(addon.name):append(chat.error('Invalid command syntax for command: ')):append(chat.success('/' .. addon.name)));
    else
        print(chat.header(addon.name):append(chat.message('Available commands:')));
    end

    local cmds = T{
        { '/pupsets help', 'Shows the addon help.' },
        { '/pupsets list', 'Lists all available attachment list files.' },
        { '/pupsets load <file>', 'Loads the PUP attachments from the given attachment list file.' },
        { '/pupsets save <file>', 'Saves the current set PUP attachments to the given attachment list file.' },
        { '/pupsets delete <file>', 'Deletes the given attachment list file.' },
        { '/pupsets (clear | reset | unset)', 'Unsets all currently set PUP attachments.' },
        { '/pupsets set <slot> <attachment>', 'Sets the given slot to the given PUP attachment by its id.' },
        { '/pupsets setn <slot> <attachment>', 'Sets the given slot to the given PUP attachment by its name.' },
        { '/pupsets delay <amount>', 'Sets the delay, in seconds, between packets that PupSets will use when loading sets. (If safe mode is on, minimum is 1 second.)' },
    };

    -- Print the command list..
    cmds:ieach(function (v)
        print(chat.header(addon.name):append(chat.error('Usage: ')):append(chat.message(v[1]):append(' - ')):append(chat.color1(6, v[2])));
    end);
end

--[[
* event: load
* desc : Event called when the addon is being loaded.
--]]
ashita.events.register('load', 'load_cb', function ()
    -- Ensure the configuration folder exists..
    local path = ('%s\\config\\addons\\%s\\'):fmt(AshitaCore:GetInstallPath(), 'pupsets');
    if (not ashita.fs.exists(path)) then
        ashita.fs.create_dir(path);
    end
end);

--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command', 'command_cb', function (e)
    -- Parse the command arguments..
    local args = e.command:args();
    if (#args == 0 or not args[1]:any('/pupsets', '/pupset', '/ps')) then
        return;
    end

    -- Block all related commands..
    e.blocked = true;

    -- Handle: /pupsets help - Shows the addon help.
    if (#args >= 2 and args[2]:any('help')) then
        print_help(false);
        return;
    end

    -- Handle: /pupsets list - Lists all available attachment list files.
    if (#args >= 2 and args[2]:any('list')) then
        local path = ('%s\\config\\addons\\%s\\'):fmt(AshitaCore:GetInstallPath(), 'pupsets');
        local files = ashita.fs.get_dir(path, '.*.txt', true);
        if (files ~= nil and #files > 0) then
            T(files):each(function (v)
                print(chat.header(addon.name):append(chat.message('Found attachment set file: ')):append(chat.success(v:gsub('.txt', ''))));
            end);
            return;
        end

        print(chat.header(addon.name):append(chat.message('No saved attachment lists found.')));
        return;
    end

    -- Handle: /pupsets load <file> - Loads the PUP attachments from the given attachment list file.
    if (#args >= 3 and args[2]:any('load')) then

        -- Check for PUP main/sub..
        if (not pup.is_pup_cmd_ok(args[2])) then
            return;
        end

        local name = args:concat(' ', 3):gsub('.txt', ''):trim();
        local path = ('%s\\config\\addons\\%s\\'):fmt(AshitaCore:GetInstallPath(), 'pupsets');

        -- Check for active automation..
        local myIndex = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
        local petIndex = AshitaCore:GetMemoryManager():GetEntity():GetPetTargetIndex(myIndex);
        if (petIndex ~= 0) then
            print(chat.header(addon.name):append(chat.error('Must deactivate automation before changing attachemnts!')));
            return;
        end

        -- Check if the file exists..
        if (not ashita.fs.exists(path:append(name:append('.txt')))) then
            print(chat.header(addon.name):append(chat.error('Failed to load attachment list; file does not exist: ')):append(chat.warning(name)));
            return;
        end

        -- Load the attachment file for reading..
        local f = io.open(path:append(name:append('.txt')), 'r');
        if (f == nil) then
            print(chat.header(addon.name):append(chat.error('Failed to open attachment list file for reading: ')):append(chat.warning(name)));
            return;
        end

        -- Read the attachment file lines..
        local attachments = T{ };
        for line in f:lines() do
            attachments:append(line);
        end

        f:close();

        if pup.debug then
            for i, v in pairs(attachments) do
                print(chat.header(addon.name):append(chat.message('[' .. i .. ']: ')):append(chat.success(v)));
            end
        end

        -- Determine the delay to be used while setting attachments..
        local delay = pup.delay;
        if (delay < 1 and pup.mode == 'safe') then
            delay = 1;
        end

        -- Apply the attachment list..
        ashita.tasks.once(1, (function (d, lst)
            -- Reset the current attachments first..
            pup.reset_all_attachments();
            coroutine.sleep(d);

            -- Set each attachment in the attachment list..
            lst:each(function (v, k)
                pup.set_attachment_by_name(k, v);
                coroutine.sleep(d);
            end);

            print(chat.header(addon.name):append(chat.message('Finished setting attachmentss set.')));
        end):bindn(delay, attachments));

        print(chat.header(addon.name):append(chat.message('Setting from attachment set; please wait..')));
        return;
    end

    -- Handle: /pupsets save <file> - Saves the current set PUP attachments to the given attachment list file.
    if (#args >= 3 and args[2]:any('save')) then

        if (not pup.is_pup_cmd_ok(args[2])) then
            return;
        end

        local attachments = pup.get_attachments_names();

        if pup.debug then
            for i, v in pairs(attachments) do
                print(chat.header(addon.name):append(chat.message('[' .. i .. ']: ')):append(chat.success(v)));
            end
        end

        local name = args:concat(' ', 3):gsub('.txt', ''):trim();
        local path = ('%s\\config\\addons\\%s\\%s.txt'):fmt(AshitaCore:GetInstallPath(), 'pupsets', name);
        local f = io.open(path, 'w+');
        if (f == nil) then
            print(chat.header(addon.name):append(chat.error('Failed to open attachment list file for writing.')));
            return;
        end
        f:write(attachments:concat('\n'));
        f:close();

        print(chat.header(addon.name):append(chat.message('Saved attachment list to: ')):append(chat.success(name)));
        return;
    end

    -- Handle: /pupsets delete <file> - Deletes the given attachment list file.
    if (#args >= 3 and args[2]:any('delete')) then
        local name = args:concat(' ', 3):gsub('.txt', ''):trim();
        local path = ('%s\\config\\addons\\%s\\'):fmt(AshitaCore:GetInstallPath(), 'pupsets');

        if (not ashita.fs.exists(path:append(name:append('.txt')))) then
            print(chat.header(addon.name):append(chat.error('Failed to delete attachment list; file does not exist: ')):append(chat.warning(name)));
            return;
        end

        ashita.fs.remove(path:append(name:append('.txt')));

        print(chat.header(addon.name):append(chat.message('Deleted attachment list file: ')):append(chat.success(name)));
        return;
    end

    -- Handle: /pupsets (clear | reset | unset) - Unsets all currently set PUP attachments.
    if (#args >= 2 and args[2]:any('clear', 'reset', 'unset')) then

        -- Check for PUP main/sub..
        if (not pup.is_pup_cmd_ok(args[2])) then
            return;
        end

        pup.reset_all_attachments();

        print(chat.header(addon.name):append(chat.message('Attachments reset.')));
        return;
    end

    -- Handle: /pupsets set <slot> <attachment> - Sets the given slot to the given PUP attachment by its id.
    if (#args >= 4 and args[2]:any('set')) then

        -- Check for PUP main/sub..
        if (not pup.is_pup_cmd_ok(args[2])) then
            return;
        end

        pup.set_attachment(args[3]:num(), args[4]:num_or(0));
        return;
    end

    -- Handle: /pupsets setn <slot> <attachment> - Sets the given slot to the given PUP attachment by its name.
    if (#args >= 4 and args[2]:any('setn')) then

        -- Check for PUP main/sub..
        if (not pup.is_pup_cmd_ok(args[2])) then
            return;
        end

        pup.set_attachment_by_name(args[3]:num(), args:concat(' ', 4));
        return;
    end

    -- Handle: /pupsets delay <amount> - Sets the delay, in seconds, between packets that PupSets will use when loading sets. (If safe mode is on, minimum is 1 second.)
    if (#args >= 3 and args[2]:any('delay')) then
        pup.delay = args[3]:num_or(1);
        if (pup.delay <= 0) then
            pup.delay = 1;
        end

        print(chat.header(addon.name):append(chat.message('PupSets packet delay set to: ')):append(chat.success(pup.delay)));
        return;
    end

    -- Unhandled: Print help information..
    print_help(true);
end);
