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

require('common');
local chat = require('chat');
local ffi = require('ffi');

-- FFI Prototypes
ffi.cdef[[
    /**
     * Extended equip packet sender. Used for BLU spells, PUP attachments, etc.
     *
     * @param {uint8_t} isSubJob - Flag if the used job is currently subbed or not. (ie. If using BLU, is BLU subbed?)
     * @param {uint16_t} jobType - Flag used for the job packet type. (BLU = 0x1000, PUP = 0x1200)
     * @param {uint16_t} index - The index of the slot being manipulated. (ie. The BLU spell slot.)
     * @param {uint8_t} id - The id of the spell, attachment, etc. being set. (BLU spells are id - 512.)
     * @return {uint8_t} 1 on success, 0 otherwise.
     * @note
     *  This calls the in-game function that is used to send the 0x102 packets.
     */
    typedef uint8_t (__cdecl *equipex_t)(uint8_t isSubJob, uint16_t jobType, uint16_t index, uint8_t id);

    // Packet: 0x0102 - Extended Equip (Client To Server)
    typedef struct packet_equipex_c2s_t {
        uint16_t    IdSize;             /* Packet id and size. */
        uint16_t    Sync;               /* Packet sync count. */
        uint8_t     SpellId;            /* If setting a spell, this is set to the spell id being placed in a 'Spells' entry. If unsetting, it is set to 0. */
        uint8_t     Unknown0000;        /* Forced to 0 by the client. */
        uint16_t    Unknown0001;        /* Unused. */

        /**
         * The following data is job specific, this is how it is defined for BLU.
         */

        uint8_t     JobId;              /* Set to 0x10, BLU's job id. Set to 0x12, PUP's job id. */
        uint8_t     IsSubJob;           /* Flag set if BLU is currently the players sub job. */
        uint16_t    Unknown0002;        /* Unused. (Padding) */
        uint8_t     Spells[20];         /* Array of the BLU spell slots. PUP: [1]=head, [2]=frame, [3-14]=attachments, [15-20]=unused */
        uint8_t     Unknown0003[132];   /* Unused. */
    } packet_equipex_c2s_t;
]];

-- Blue Mage Helper Library
local pup = T{
    offset  = ffi.cast('uint32_t*', ashita.memory.find('FFXiMain.dll', 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0)),
    equipex = ffi.cast('equipex_t', ashita.memory.find('FFXiMain.dll', 0, '8B0D????????81EC9C00000085C95356570F??????????8B', 0, 0)),

    -- Memory offsets for PUP head/frame and attachments
    equipOffset  = 0x2000, -- head/frame
    attachOffset = 0x2100, -- attachments

    -- Toggle to enable debug prints
    debug = false,

    --[[
    Packet Sender Mode

    Sets the mode that will be used when queueing and sending packets by pupsets.

        safe - Uses the games actual functions to rate limit and send the packet properly.
        fast - Uses custom injected packets with custom rate limiting to bypass the internal client buffer limit.
    --]]
    mode = 'safe',

    -- The delay between packet sends when loading a attachment set. (If safe mode is on, 1.0 is forced.)
    delay = 0.65,
};

--[[
* Returns if the players main job is PUP.
*
* @return {boolean} True if PUP main, false otherwise.
--]]
function pup.is_pup_main()
    return AshitaCore:GetMemoryManager():GetPlayer():GetMainJob() == 18;
end

--[[
* Returns if the players sub job is PUP.
*
* @return {boolean} True if PUP sub, false otherwise.
--]]
function pup.is_pup_sub()
    return AshitaCore:GetMemoryManager():GetPlayer():GetSubJob() == 18;
end

--[[
* Returns if the players main or sub job is PUP. Prints error if false.
*
* @return {boolean} True if PUP main or sub, false otherwise.
--]]
function pup.is_pup_cmd_ok(cmd)
    if (not pup.is_pup_main() and not pup.is_pup_sub()) then
        print(chat.header(addon.name):append(chat.error('Must be PUP main or sub to use /pupset ' .. cmd .. '!')));
        return false;
    else
        return true;
    end
end

--[[
* Returns the raw buffer used in PUP attachment packets.
*
* @return {number} The current PUP raw buffer pointer.
* @note
*   On private servers, there is a rare chance this buffer is not properly updated immediately until you open an
*   equipment menu or open the PUP set attachments window. Because of this, you may send a bad job id for the packets
*   that rely on this buffers data if used directly.
--]]
function pup.get_pup_buffer_ptr()
    local ptr = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'));
    if (ptr == 0) then
        return 0;
    end
    ptr = ashita.memory.read_uint32(ptr);
    if (ptr == 0) then
        return 0;
    end
    return ptr + pup.offset[0] + (pup.is_pup_main() and 0x00 or 0x9C);
end

--[[
* Returns the table of current set PUP attachments.
*
* @return {table} The current set PUP attachments.
--]]
function pup.get_attachments()
    local ptr = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'));
    if (ptr == 0) then
        return T{ };
    end
    ptr = ashita.memory.read_uint32(ptr);
    if (ptr == 0) then
        return T{ };
    end
    return T(ashita.memory.read_array((ptr + pup.offset[0]) + (pup.is_pup_main() and 0x04 or 0xA0), 0xE));
end

--[[
* Returns the table of current set PUP attachments names.
*
* @return {table} The current set PUP attachments names.
--]]
function pup.get_attachments_names()
    local data = pup.get_attachments();
    for k, v in pairs(data) do
        if (k < 3) then -- head and frame
            data[k] = AshitaCore:GetResourceManager():GetItemById(v + pup.equipOffset);
        else -- attachment
            data[k] = AshitaCore:GetResourceManager():GetItemById(v + pup.attachOffset);
        end
        if (data[k] ~= nil and data[k].Name[1] ~= '.') then
            data[k] = data[k].Name[1];
        else
            data[k] = '';
        end
    end
    return data;
end

--[[
* Resets all of the players current set PUP attachments. (safe)
*
* Uses the in-game packet queue to properly queue a reset packet.
--]]
local function safe_reset_all_attachments()
    AshitaCore:GetPacketManager():QueuePacket(0x102, 0xA4, 0x00, 0x00, 0x00, function (ptr)
        local p = ffi.cast('uint8_t*', ptr);
        ffi.fill(p + 0x04, 0xA0);
        ffi.copy(p + 0x08, ffi.cast('uint8_t*', pup.get_pup_buffer_ptr()), 0x9C);
        ffi.fill(p + 0x0C, 0x2); -- zero out head and frame IDs
    end);
end

--[[
* Sets a PUP attachment for the give slot index. (safe)
*
* @param {number} index - The slot index to set. (1 to 10)
* @param {number} id - The attachment id to set. (0 if unsetting.)
*
* Uses actual client function used to set PUP attachments to safely and properly queue the packet.
--]]
local function safe_set_attachment(index, id)
    pup.equipex(pup.is_pup_main() == true and 0 or 1, 0x1200, index - 1, id);
end

--[[
* Queues the packet required to unset all PUP attachments.
--]]
function pup.reset_all_attachments()
    safe_reset_all_attachments();
end

--[[
* Queues the packet required to set a PUP attachment. (Or unset.)
*
* @param {number} index - The slot index to set.
* @param {number} id - The attachment id to set. (0 if unsetting.)
--]]
function pup.set_attachment(index, id)
    if (index <= 0 or index > 14) then
        print(chat.header(addon.name):append(chat.error('Failed to set attachment; invalid index given. (Params - Index: %d, Id: %d)')):fmt(index, id));
        return;
    end

    -- Check if the attachment is set elsewhere already..
    local attachments = pup.get_attachments();
    local equip = attachments:slice(1,2);
    local attach = attachments:slice(3,12);
    if (id ~= 0 and index < 3 and equip:hasval(id)) then
        return;
    elseif (id ~= 0 and index > 2 and attach:hasval(id)) then
        print(chat.header(addon.name):append(chat.error('Failed to set attachment; attachment is already assigned. (Params - Index: %d, Id: %d)')):fmt(index, id));
        return;
    end

    -- Check if the attachment is being unset and has a attachment in the desired slot..
    local attachment = attachments[index];
    if (id == 0 and (attachment == nil or attachment == 0)) then
        return;
    end

    -- Set the attachment..
    safe_set_attachment(index, id);
end

--[[
* Sets the given slot index to the attachment matching the given name. If no name is given, the slot is unset.
*
* @param {number} index - The slot index to set the attachment into.
* @param {string|nil} name - The name of the attachment to set. (nil if unsetting attachment.)
--]]
function pup.set_attachment_by_name(index, name)
    -- Unset the attachment if no name is given..
    if (name == nil or name == '') then
        pup.set_attachment(index, 0);
        return;
    end

    -- Obtain the attachment resource info..
    local id, offset, base, range = nil, 0, 0, 0;
    if (index == 1) then -- head
        offset, base, range = pup.equipOffset, 1, 7;
    elseif (index == 2) then -- frame
        offset, base, range = pup.equipOffset, 32, 8;
    else -- attachment
        offset, base, range = pup.attachOffset, 1, 254;
    end
    for i = base, base+range-1 do
        local item = AshitaCore:GetResourceManager():GetItemById(offset + i);
        if( item ~= nil and item.Name[1] == name ) then
            id = i;
        end
    end
    if (id == nil) then
        print(chat.header(addon.name):append(chat.error('Failed to set attachment; invalid attachment name given. (Params - Index: %d, Name: %s)')):fmt(index, name));
        return;
    end

    -- Set the attachment..
    pup.set_attachment(index, id);
end

-- Return the library table..
return pup;
