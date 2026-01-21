function Journalator.ApplyQualityColor(name, link)
  return "|c" .. Auctionator.Utilities.GetQualityColorFromLink(link) .. name .. "|r"
end

function Journalator.Utilities.PrettyPercentage(value)
  return tostring(math.floor(value)) .. "%"
end

function Journalator.Utilities.GetSortedKeys(a)
  local result = {}

  for key, _ in pairs(a) do
    table.insert(result, key)
  end
  table.sort(result)

  return result
end

function Journalator.Utilities.AddRealmToPlayerName(playerName, source)
  if playerName == nil then
    return nil
  end

  if source.realm ~= Journalator.State.Source.realm and not string.match(playerName, "-") then
    return playerName .. "-" .. string.gsub(source.realm, "[ -]", "")
  else
    return playerName
  end
end

function Journalator.Utilities.GetIgnoredCharacterCheckString(playerName, source)
  if not string.match(playerName, "[-%*]") then
    return playerName .. "-" .. string.gsub(source.realm, "[ -]", "")
  else
    return playerName
  end
end

function Journalator.Utilities.UpdateRealmOnPlayerName(playerName, source)
  local currentRealm = string.gsub(Journalator.State.Source.realm, "[ -]", "")
  if string.match(playerName, currentRealm) then
    return playerName:gsub("-" .. currentRealm, "")

    -- Check for - to avoid adding a realm when the realm is already
    -- indicated. Checks for * to avoid adding a realm when the realm data is
    -- missing due to an old bug in the Trades monitor.
  elseif source.realm ~= Journalator.State.Source.realm and not string.match(playerName, "[-%*]") then
    return playerName .. "-" .. string.gsub(source.realm, "[ -]", "")

  else
    return playerName
  end
end

function Journalator.Utilities.AddQualityIconToItemName(itemName, itemLink)
  if C_TradeSkillUI == nil or C_TradeSkillUI.GetItemReagentQualityByItemInfo == nil then
    return itemName
  end

  local itemID = C_Item.GetItemInfoInstant(itemLink)
  if itemID == nil then -- pets won't have an item id from the link
    return itemName
  end

  local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
  if quality ~= nil then
    local icon = Auctionator.Utilities.GetCraftingQualityMarkup(quality)
    return AUCTION_HOUSE_CRAFTING_REAGANT_QUALITY_FORMAT:format(itemName, icon)
  else
    return itemName
  end
end

function Journalator.Utilities.AddTierToBasicName(itemName, itemLink)
  if C_TradeSkillUI == nil or C_TradeSkillUI.GetItemReagentQualityByItemInfo == nil then
    return itemName
  end

  local itemID = C_Item.GetItemInfoInstant(itemLink)
  if itemID == nil then -- pets won't have an item id from the link
    return itemName
  end

  local quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemID)
  if quality ~= nil then
    return itemName .. " " .. AUCTIONATOR_L_TIER .. " " .. quality
  else
    return itemName
  end
end

do
  local function IsGear(itemLink)
    local classType = select(6, C_Item.GetItemInfoInstant(itemLink))
    return Auctionator.Utilities.IsEquipment(classType)
  end

  function Journalator.Utilities.GetItemText(itemLink, quantity)
    local itemInfo = {C_Item.GetItemInfo(itemLink)}
    local text = Auctionator.Utilities.GetNameFromLink(itemInfo[2])

    if IsGear(itemLink) then
      text = text .. " (" .. (C_Item.GetDetailedItemLevelInfo(itemLink)) .. ")"
    end

    local qualityColor = ITEM_QUALITY_COLORS[itemInfo[3]]
    text = qualityColor.color:WrapTextInColorCode(text)

    if quantity and quantity > 1 then
      text = text .. Auctionator.Utilities.CreateCountString(quantity)
    end

    return text
  end
end

function Journalator.Utilities.GetCurrencyText(currencyID, quantity)
  local link = (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink or GetCurrencyLink)(currencyID, quantity)

  local text = Auctionator.Utilities.GetNameFromLink(link)

  local color = Auctionator.Utilities.GetQualityColorFromLink(link)
  if color ~= nil then
    text = "|c" .. color .. text .. "|r"
  end

  text = text .. Auctionator.Utilities.CreateCountString(quantity)

  return text
end

-- Removes any player-specific information on an item or pet link
function Journalator.Utilities.CleanItemLink(itemLink)
  if itemLink:find("item:") then
    -- For reference
    -- itemID : enchantID : gemID1 : gemID2 : gemID3 : gemID4
    --: suffixID : uniqueID : linkLevel : specializationID : modifiersMask : itemContext
    --: numBonusIDs[:bonusID1:bonusID2:...] : numModifiers[:modifierType1:modifierValue1:...]
    --: relic1NumBonusIDs[:relicBonusID1:relicBonusID2:...] : relic2NumBonusIDs[...] : relic3NumBonusIDs[...]
    --: crafterGUID : extraEnchantID
    --
    -- Remove the uniqueID, linkLevel, specializationID and itemContext
    -- parameters from the item link
    local cleaned = itemLink:gsub("(item:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:)[^:]*:[^:]*:[^:]*:([^:]*:)[^:]*:", "%1:::%2:")

    if string.find(cleaned, ":Player[^: ]+:") then
      cleaned = string.gsub(cleaned, ":Player[^: ]+:", "::")
    end

    return cleaned
  elseif itemLink:find("battlepet:") then
    -- For reference
    -- battlepet : speciesID : level : breedQuality : maxHealth : [power] : [speed] : [battlePetID] : [displayID]
    --
    -- Remove the power, speed, battlePetID and displayID parameters from the
    -- link
    return (itemLink:gsub("(battlepet:[^:]*:[^:]*:[^:]*)(:.-|h)?", "%1"))
  else
    return itemLink
  end
end

-- Remove any item levels, stats or battle pet levels from a link
function Journalator.Utilities.PurgeLevelsFromLink(link)
  if string.match(link, "battlepet") then
    return (string.gsub(link, ":%d+:%d+:%d+:%d+:%d+:%d+:%d+|", ":0:0:0:0:0:0:0|"))
  elseif link then
    return (string.gsub(link, "item:(%d+):.-|", "item:%1|"))
  end
end
