--[[
    TODO: Multi-user sync
    TODO: Customizable minimum rank for trial/raiders
    TODO: Customizable "trusted" rank for multi-user
    TODO: Customizable minimum rarity
--]]


local AddonPrefix = "RaidAttend";

local RARITY_POOR = 0
local RARITY_COMMON = 1
local RARITY_UNCOMMON = 2
local RARITY_RARE = 3
local RARITY_EPIC = 4
local RARITY_LEGENDARY = 5


function LootInfo(itemString)
    local _, itemId = strsplit(":", itemString)
    local itemName, _, itemRarity = GetItemInfo(itemId)
    return itemId, itemName, itemRarity
end

function GetOnlineGuildRoster()
    GuildRoster() -- According to docs this is to ensure the correct guild roster info is retrieved.
    local members = {}
    members.names = {}
    local numTotalMembers = GetNumGuildMembers();
    for i = 1, numTotalMembers do
        local name, rank, rankIndex, level, class, zone, _, _, isOnline = GetGuildRosterInfo(i)
        if isOnline then
            local member = {
                name = name,
                rank = rank,
                rankIndex = rankIndex,
                level = level,
                class = class,
                zone = zone,
            }
            table.insert(members, member)
            members.names[name] = member
        end
    end
    return members
end

function GetGuildRoster(minLevel)
    GuildRoster() -- According to docs this is to ensure the correct guild roster info is retrieved.
    local members = {}
    members.names = {}
    local numTotalMembers = GetNumGuildMembers();
    for i = 1, numTotalMembers do
        local name, rank, rankIndex, level, class = GetGuildRosterInfo(i)
        if not minLevel or level >= minLevel then
            local member = {
                name = name,
                rank = rank,
                rankIndex = rankIndex,
                level = level,
                class = class,
            }
            table.insert(members, member)
            members.names[name] = member
        end
    end
    return members
end

function GetRaidRoster()
    local roster = {}
    roster.names = {}
    for i = 1, 40 do
        local name = GetRaidRosterInfo(i)
        if name then
            table.insert(roster, name)
            roster.names[name] = 1
        end
    end
    return roster
end

function KethoEditBox_Show(text)
    -- Credits: Ketho at https://www.wowinterface.com/forums/showpost.php?p=323901&postcount=2
    if not KethoEditBox then
        local f = CreateFrame("Frame", "KethoEditBox", UIParent, "DialogBoxFrame")
        f:SetPoint("CENTER")
        f:SetSize(600, 500)
        
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\PVPFrame\\UI-Character-PVP-Highlight", -- this one is neat
            edgeSize = 16,
            insets = { left = 8, right = 6, top = 8, bottom = 8 },
        })
        f:SetBackdropBorderColor(0, .44, .87, 0.5) -- darkblue
        
        -- Movable
        f:SetMovable(true)
        f:SetClampedToScreen(true)
        f:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                self:StartMoving()
            end
        end)
        f:SetScript("OnMouseUp", f.StopMovingOrSizing)
        
        -- ScrollFrame
        local sf = CreateFrame("ScrollFrame", "KethoEditBoxScrollFrame", KethoEditBox, "UIPanelScrollFrameTemplate")
        sf:SetPoint("LEFT", 16, 0)
        sf:SetPoint("RIGHT", -32, 0)
        sf:SetPoint("TOP", 0, -16)
        sf:SetPoint("BOTTOM", KethoEditBoxButton, "TOP", 0, 0)
        
        -- EditBox
        local eb = CreateFrame("EditBox", "KethoEditBoxEditBox", KethoEditBoxScrollFrame)
        eb:SetSize(sf:GetSize())
        eb:SetMultiLine(true)
        eb:SetAutoFocus(false) -- dont automatically focus
        eb:SetFontObject("ChatFontNormal")
        eb:SetScript("OnEscapePressed", function() 
            f:Hide() 
        end)
        sf:SetScrollChild(eb)
        
        -- Resizable
        f:SetResizable(true)
        f:SetMinResize(150, 100)
        
        local rb = CreateFrame("Button", "KethoEditBoxResizeButton", KethoEditBox)
        rb:SetPoint("BOTTOMRIGHT", -6, 7)
        rb:SetSize(16, 16)
        
        rb:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        rb:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        rb:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
        
        rb:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                f:StartSizing("BOTTOMRIGHT")
                self:GetHighlightTexture():Hide() -- more noticeable
            end
        end)
        rb:SetScript("OnMouseUp", function(self, button)
            f:StopMovingOrSizing()
            self:GetHighlightTexture():Show()
            eb:SetWidth(sf:GetWidth())
        end)
        f:Show()
    end
    
    if text then
        KethoEditBoxEditBox:SetText(text)
        KethoEditBoxEditBox:HighlightText()
    end
    KethoEditBox:Show()
end

SLASH_ATTENDANCE1 = "/attend"
SLASH_ATTENDANCE2 = "/attendance"
SlashCmdList["ATTENDANCE"] = function(msg)

    local members = GetOnlineGuildRoster()
    local raid = GetRaidRoster()

    local text = "Id,Date,PlayerName,IsInGuild,IsInRaid\n"
    local today = date("%Y-%m-%d")
    local id = 1
    
    local seenMembers = {}

    for i, member in ipairs(members) do
        local name = strsplit("-", member.name)
        local isInRaid = raid.names[name]
        if not seenMembers[name] then
            seenMembers[name] = true
            text = text .. string.format("%d,%s,%s,Y,%s\n", id, today, name, isInRaid and "Y" or "N")
            id = id + 1
        end
    end
    
    -- This doesn't really check if they are actually in guild or not, it just assumes that
    -- everybody already in the seenMembers table by now is in guild so there's potentially
    -- an odd/race condition where somebody may join the guild during

    for i, member in ipairs(raid) do
        local name = strsplit("-", member)
        if not seenMembers[name] then
            seenMembers[name] = true
            text = text .. string.format("%d,%s,%s,N,Y\n", id, today, name)
            id = id + 1
        end
    end

    KethoEditBox_Show(text)
end

function DumpGuild(minLevel)
    local members = GetGuildRoster(minLevel)

    local text = "Id,Date,PlayerName,Class,Level\n"
    local today = date("%Y-%m-%d")
    local id = 1
    
    local seenMembers = {}

    for i, member in ipairs(members) do
        local name = strsplit("-", member.name)
        text = text .. string.format("%d,%s,%s,%s,%s\n", id, today, name, member.class, member.level)
        id = id + 1
    end
    
    KethoEditBox_Show(text)
end

SLASH_LOOTLOG1 = "/lootlog"
SlashCmdList["LOOTLOG"] = function(msg)
    if msg == "start" then
        RaidAttendancePerSettings.IsLogging = true
        print("Loot logging started.")
    elseif msg == "stop" then
        RaidAttendancePerSettings.IsLogging = false
        print("Loot logging stopped.")
    elseif msg == "clear" then
        RaidAttendancePerSettings.LootLog = {}
        print("Loot log cleared.")
    elseif msg == "reset" then
        RaidAttendancePerSettings.IsLogging = false
        RaidAttendancePerSettings.LootLog = {}
        print("Loot log cleared and loot logging stopped.")
    else
        RaidAttendancePerSettings.IsLogging = not RaidAttendancePerSettings.IsLogging
        if RaidAttendancePerSettings.IsLogging then
            print("Loot logging started.")
        else
            print("Loot logging stopped.")
        end
    end
end

function LootLoggerFrame_OnLoad(self)
    self:RegisterEvent("VARIABLES_LOADED")
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("CHAT_MSG_LOOT")
    self:RegisterEvent("CHAT_MSG_WHISPER")
    self:RegisterEvent("CHAT_MSG_ADDON")
end

local function LogLoot(timestamp, recipient, itemId, quantity)
    if RaidAttendancePerSettings.LootLog[recipient] == nil then
        RaidAttendancePerSettings.LootLog[recipient] = {}
    end
    local itemName, _, itemRarity = GetItemInfo(itemId)
    
    --print(timestamp, recipient, itemId, quantity)

    local found = false
    for i, elem in ipairs(RaidAttendancePerSettings.LootLog[recipient]) do
        -- 3 seconds timestamp drift is kind of weird, does server send the same guid to all clients for the loot? 
        if abs(timestamp - elem.timestamp) < 3 and itemId == elem.itemId and quantity == elem.quantity then
            --print("Item already in log: ", timestamp, recipient, itemId, quantity)
            found = true
            break
        end
    end

    if not found then
        table.insert(RaidAttendancePerSettings.LootLog[recipient], {
            timestamp = timestamp,
            itemId = itemId,
            itemName = itemName,
            itemRarity = itemRarity,
            quantity = quantity
        })
    end
    return not found
end

local function HandleMsgLoot(...)
    local text, _, _, _, recipient = ...
    if not string.match(text, "receives? loot") then
        return 
    end
    local itemLink = string.match(text,"|%x+|Hitem:.-|h.-|h|r")
    local quantity = string.match(text,"|%x+|Hitem:.-|h.-|h|rx(%d+)") or 1
    local itemString = string.match(itemLink, "item[%-?%d:]+")
    if recipient and itemLink then
        local itemId, itemName, itemRarity = LootInfo(itemString)
        local timestamp = GetServerTime()
        local syncMsg = string.format("SYNC:%s:%s:%s:%s", timestamp, recipient, itemId, quantity)
        C_ChatInfo.SendAddonMessage(AddonPrefix, syncMsg, "RAID")
        if RaidAttendancePerSettings.IsLogging and 
           (true or itemRarity >= RaidAttendancePerSettings.MinRarity) and
           LogLoot(tonumber(timestamp), recipient, tonumber(itemId), tonumber(quantity)) then
            local stat = string.format("%s looted a %s x%s", recipient, itemName, quantity)
            print(stat)
            --SendChatMessage(stat, "PARTY")
        end
    end
end

local function HandleMsgWhisper(...)
    if RaidAttendancePerSettings.IsLogging then
        local text, _, _, _, who = ...
        if text and string.sub(text, 1, 1) == "!" then
            SendChatMessage(string.format("[%s]: %s", who, text), "OFFICER")
        end
    end
end

local function HandleAddonMsg(text, channel, sender, target)
    if RaidAttendancePerSettings.IsLogging then
        local split = { strsplit(":", text) }
        if split[1] == "SYNC" then
            local _, timestamp, recipient, itemId, quantity = unpack(split)
            local itemName, _, itemRarity = GetItemInfo(itemId)
            if (true or itemRarity >= RaidAttendancePerSettings.MinRarity) and
               LogLoot(tonumber(timestamp), recipient, tonumber(itemId), tonumber(quantity)) then
                print(string.format("Received SYNC from %s: %s looted a %s x%s", sender, recipient, itemName or itemId, quantity))  
            end
            --print(timestamp, recipient, itemId, quantity)
        end
    end
end

function LootLoggerFrame_OnEvent(self, event, ...)
    if event == "CHAT_MSG_LOOT" then
        HandleMsgLoot(...)
    elseif event == "CHAT_MSG_WHISPER" then
        HandleMsgWhisper(...)
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender, target = ...
        if prefix == AddonPrefix then
            HandleAddonMsg(text, channel, sender, target)
        end
    elseif event == "VARIABLES_LOADED" then
        --RaidAttendancePerSettings = nil -- debug to reset settings
        if type(RaidAttendancePerSettings) ~= "table" then
            RaidAttendancePerSettings = {
                MinRarity = RARITY_RARE,
                IsLogging = false,
                LootLog = {}
            }
        end
    elseif event == "PLAYER_LOGIN" then
        C_ChatInfo.RegisterAddonMessagePrefix(AddonPrefix)
    elseif event == "PLAYER_ENTERING_WORLD" then
        --
    end
end

SLASH_LOOTDUMP1 = "/lootdump"
SlashCmdList["LOOTDUMP"] = function(msg)
    local text = "Id,PlayerName,ServerTime,ItemId,ItemName,Quantity\n"
    local index = 1
    for who, loot in pairs(RaidAttendancePerSettings.LootLog) do
        for i, value in ipairs(loot) do
            if value.itemId then
                local itemName = value.itemName or GetItemInfo(value.itemId) or "UNKNOWN"
                text = text .. string.format("%s,%s,%s,%s,\"%s\",%s\n", 
                                        index, 
                                        who, 
                                        value.timestamp, 
                                        value.itemId, 
                                        itemName,
                                        value.quantity)
                index = index + 1
            end
        end
    end
    KethoEditBox_Show(text)
end