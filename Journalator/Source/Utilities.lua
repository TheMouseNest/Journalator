Journalator.Utilities = {}

function Journalator.Utilities.Message(message)
  print(
    INVASION_FONT_COLOR:WrapTextInColorCode("Journalator: ")
    .. message
  )
end

-- Removes slotID field from reagents entries
function Journalator.Utilities.CleanReagents(reagents)
  local result = {}
  for _, item in ipairs(reagents) do
    table.insert(result, {
      itemID = item.itemID,
      quantity = item.quantity,
    })
  end
  return result
end

function Journalator.Utilities.GetChatPattern(chatTextTemplate)
  chatTextTemplate = chatTextTemplate:gsub("(%W)", "%%%1")
  return "^" .. chatTextTemplate:gsub("%%%%s", "(.*)"):gsub("%%%%d", "(.*)") .. "$"
end

function Journalator.Utilities.CleanNumberString(numberString)
  local cleaned = numberString:gsub("%,", ""):gsub("%.", "")
  return tonumber(cleaned)
end

do
  local factionMap

  -- Converts from a faction name to the faction id. Assumes that the faction is
  -- in the player's reputation listing.
  function Journalator.Utilities.GetFactionID(factionName)
    if factionMap == nil or factionMap[factionName] == nil then
      factionMap = {}
      (C_Reputation and C_Reputation.ExpandAllFactionHeaders or ExpandAllFactionHeaders)()
      local function GetNameAndID(index)
        if C_Reputation and C_Reputation.GetFactionDataByIndex then
          local data = C_Reputation.GetFactionDataByIndex(index)
          if data then
            return data.name, data.factionID
          end
        else
          local data = {GetFactionInfo(index)}
          return data[1], data[14]
        end
      end

      for i = 1, (C_Reputation and C_Reputation.GetNumFactions or GetNumFactions)() do
        local name, id = GetNameAndID(i)
        if name ~= nil then
          factionMap[name] = id
        end
      end
    end

    return factionMap[factionName]
  end
end

do
  local currencyMap


  -- Converts from a currency name to the currency id. Assumes that the currency is
  -- in the player's currencies listing.
  function Journalator.Utilities.GetCurrencyID(currencyName)
    if C_CurrencyInfo == nil then
      return nil
    end

    -- Cache currency info
    if currencyMap == nil or currencyMap[currencyName] == nil then
      currencyMap = {}

      local GetCurrencyListSize = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize or GetCurrencyListSize
      local GetCurrencyListLink = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListLink -- exists in Wrath and Retail

      local GetCurrencyName, IsCurrencyIndexAHeader, ExpandHeader

      if Journalator.Constants.IsClassic then
        GetCurrencyName = function(index)
          return (GetCurrencyListInfo(index))
        end
        IsCurrencyIndexAHeader = function(index)
          return (select(2, GetCurrencyListInfo(index)))
        end
        ExpandHeader = function(index)
          ExpandCurrencyList(index, 1)
        end
      else
        GetCurrencyName = function(index)
          return C_CurrencyInfo.GetCurrencyListInfo(index).name
        end
        IsCurrencyIndexAHeader = function(index)
          return C_CurrencyInfo.GetCurrencyListInfo(index).isHeader
        end
        ExpandHeader = function(index)
          C_CurrencyInfo.ExpandCurrencyList(index, true)
        end
      end

      local function GetCurrencyIDFromLink(link)
        if C_CurrencyInfo.GetCurrencyIDFromLink then
          return C_CurrencyInfo.GetCurrencyIDFromLink(link)
        else -- No GetCurrencyIDFromLink function exists in Wrath
          return tonumber((link:match("|Hcurrency:(%d+)")))
        end
      end

      local index = 0
      while index < GetCurrencyListSize() do
        index = index + 1
        if IsCurrencyIndexAHeader(index) then
          ExpandHeader(index)
        else
          local link = GetCurrencyListLink(index)
          if link ~= nil then
            currencyMap[GetCurrencyName(index)] = GetCurrencyIDFromLink(link)
          end
        end
      end
    end

    return currencyMap[currencyName]
  end
end

do
  local tooltip

  function Journalator.GetTooltipLines(link)
    if not tooltip then
      tooltip = CreateFrame("GameTooltip", "JournalatorFirstLineScanningTooltip", nil, "GameTooltipTemplate")
    end

    tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    tooltip:SetHyperlink(link)
    return {
      _G["JournalatorFirstLineScanningTooltipTextLeft1"]:GetText(),
      _G["JournalatorFirstLineScanningTooltipTextLeft2"]:GetText(),
    }
  end
end

do
  local frame
  local callbacks = {}
  local function Check()
    if InCombatLockdown() then
      return
    end
    for link, list in pairs(callbacks) do
      local lines = Journalator.GetTooltipLines(link)
      if lines[1] ~= nil then
        local details = {
          name = lines[1],
          group = lines[2],
        }
        for _, c in ipairs(list) do
          c(details)
        end
        callbacks[link] = nil
      end
    end
    if next(callbacks) == nil then
      frame:SetScript("OnUpdate", nil)
    end
  end

  function Journalator.Utilities.GetNPCDetailsFromGUID(guid, callback)
    if not frame then
      frame = CreateFrame("Frame", nil, UIParent)
    end

    local link = "unit:" .. guid
    callbacks[link] = callbacks[link] or {}
    table.insert(callbacks[link], callback)

    frame:SetScript("OnUpdate", Check)
  end
end

-- Necessary workaround as Wrath and Classic Era do not have
-- C_Item.GetItemLocation
function Journalator.Utilities.GetItemLocationFromGUID(wantedItemGUID)
  for _, bagID in ipairs(Journalator.Constants.BagIDs) do
    for slot = 1, C_Container.GetContainerNumSlots(bagID) do
      local location = ItemLocation:CreateFromBagAndSlot(bagID, slot)
      if C_Item.DoesItemExist(location) then
        local itemGUID = C_Item.GetItemGUID(location)
        if itemGUID == wantedItemGUID then
          return location
        end
      end
    end
  end

  for equipmentSlot = 1, Journalator.Constants.EquipmentSlotCap do
    local location = ItemLocation:CreateFromEquipmentSlot(equipmentSlot)
    if C_Item.DoesItemExist(location) then
      local itemGUID = C_Item.GetItemGUID(location)
      if itemGUID == wantedItemGUID then
        return location
      end
    end
  end

  return nil
end

function Journalator.Utilities.NormalizeRealmName(realmName)
  return realmName:gsub("[ -]", "")
end
