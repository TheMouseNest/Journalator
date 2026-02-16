local FULFILLING_DATA_PROVIDER_LAYOUT ={
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_TYPE,
    headerParameters = { "orderType" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "orderType" },
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_GUILD,
    headerParameters = { "guildName" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "guildName" },
    defaultHide = true,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_IS_RECRAFT,
    headerParameters = { "isRecraftPretty" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "isRecraftPretty" },
    defaultHide = true,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_PROFESSION,
    headerParameters = { "profession" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "profession" },
    defaultHide = true,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = AUCTIONATOR_L_NAME,
    headerParameters = { "itemName" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "itemNamePretty" },
    width = 350,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_IN,
    headerParameters = { "moneyIn" },
    cellTemplate = "AuctionatorPriceCellTemplate",
    cellParameters = { "moneyIn" },
    width = 150,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_CUSTOMER_NOTE,
    headerParameters = { "customerNote" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "customerNote" },
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_CRAFTER_NOTE,
    headerParameters = { "crafterNote" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "crafterNote" },
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_PLAYER,
    headerParameters = { "otherPlayer" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "otherPlayer" }
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_CRAFTER,
    headerParameters = { "sourceCharacter" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "sourceCharacter" },
    defaultHide = true,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_TIME_ELAPSED,
    headerParameters = { "rawDay" },
    cellTemplate = "JournalatorTimeCellTemplate",
    cellParameters = { "rawDay" }
  },
}

local function GetProfessionName(recipeID)
  local _, _, skillLineID = C_TradeSkillUI.GetTradeSkillLineForRecipe(recipeID)
  return C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID).professionName
end

JournalatorCraftingOrdersFulfillingDataProviderMixin = CreateFromMixins(JournalatorDisplayDataProviderMixin)

function JournalatorCraftingOrdersFulfillingDataProviderMixin:Refresh()
  if Auctionator.Constants.IsClassic then
    -- Nothing to do, no crafting orders
    return
  end

  self.onPreserveScroll()
  self:Reset()

  local TYPES_TO_TYPE_STRING = {
    [Enum.CraftingOrderType.Public] = JOURNALATOR_L_PUBLIC,
    [Enum.CraftingOrderType.Guild] = JOURNALATOR_L_GUILD,
    [Enum.CraftingOrderType.Personal] = JOURNALATOR_L_PERSONAL,
    [Enum.CraftingOrderType.Npc] = JOURNALATOR_L_PATRON,
  }

  local results = {}
  for index, item in ipairs(Journalator.Archiving.GetRange(self:GetTimeForRange(), "Fulfilling")) do
    local filterItem = {
      itemName = item.itemName,
      time = item.time,
      source = item.source,
      playerCheck = item.playerName,
      playerName = item.playerName,
    }
    if self:Filter(filterItem) then
      local processedItem = {
        orderType = TYPES_TO_TYPE_STRING[item.orderType],
        profession = GetProfessionName(item.recipeID),
        searchTerm = item.itemName,
        itemName = item.itemName,
        itemNamePretty = item.itemName,
        moneyIn = item.tipAmount - item.consortiumCut,
        rawDay = item.time,
        itemLink = item.itemLink,
        guildName = item.guildName or "",
        customerNote = item.customerNote,
        crafterNote = item.crafterNote,
        craftAttempts = item.craftAttempts,
        otherPlayer = Journalator.Utilities.AddRealmToPlayerName(item.playerName, item.source),
        sourceCharacter = Journalator.Utilities.AddRealmToPlayerName(item.source.character, item.source),
        customerReagents = item.customerReagents,
        crafterReagents = item.crafterReagents,
        isRecraft = item.isRecraft,
        isRecraftPretty = item.isRecraft and AUCTIONATOR_L_UNDERCUT_YES or AUCTIONATOR_L_UNDERCUT_NO,
        recraftItemLink = item.recraftItemLink,
        index = index,
        value = item.tipAmount - item.consortiumCut,
        selected = self:IsSelected(index),
      }

      if processedItem.itemLink ~= nil then
        processedItem.itemName = Journalator.Utilities.AddTierToBasicName(processedItem.itemName, processedItem.itemLink)
        processedItem.itemNamePretty = Journalator.Utilities.AddQualityIconToItemName(processedItem.itemNamePretty, processedItem.itemLink)
        processedItem.itemNamePretty = Journalator.ApplyQualityColor(processedItem.itemNamePretty, processedItem.itemLink)
      end
      table.insert(results, processedItem)
    end
  end
  self:AppendEntries(results, true)
end

function JournalatorCraftingOrdersFulfillingDataProviderMixin:GetTableLayout()
  return FULFILLING_DATA_PROVIDER_LAYOUT
end

local COMPARATORS = {
  orderType = Auctionator.Utilities.StringComparator,
  guildName = Auctionator.Utilities.StringComparator,
  profession = Auctionator.Utilities.StringComparator,
  isRecraftPretty = Auctionator.Utilities.StringComparator,
  itemName = Auctionator.Utilities.StringComparator,
  moneyIn = Auctionator.Utilities.NumberComparator,
  customerNote = Auctionator.Utilities.StringComparator,
  crafterNote = Auctionator.Utilities.StringComparator,
  otherPlayer = Auctionator.Utilities.StringComparator,
  sourceCharacter = Auctionator.Utilities.StringComparator,
  rawDay = Auctionator.Utilities.NumberComparator,
}

function JournalatorCraftingOrdersFulfillingDataProviderMixin:Sort(fieldName, sortDirection)
  local comparator = COMPARATORS[fieldName](sortDirection, fieldName)

  table.sort(self.results, function(left, right)
    return comparator(left, right)
  end)

  self:SetDirty()
end

Journalator.Config.Create("COLUMNS_FULFILLING", "columns_fulfilling", {})

function JournalatorCraftingOrdersFulfillingDataProviderMixin:GetColumnHideStates()
  return Journalator.Config.Get(Journalator.Config.Options.COLUMNS_FULFILLING)
end

function JournalatorCraftingOrdersFulfillingDataProviderMixin:GetRowTemplate()
  return "JournalatorLogViewCraftingOrdersRowTemplate"
end
