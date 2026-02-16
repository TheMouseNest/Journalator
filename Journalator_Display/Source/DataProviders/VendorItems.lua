local VENDORING_DATA_PROVIDER_LAYOUT ={
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = AUCTIONATOR_L_NAME,
    headerParameters = { "itemName" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "itemNamePretty" },
    width = 300,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_IN,
    headerParameters = { "moneyIn" },
    cellTemplate = "JournalatorPriceCellTemplate",
    cellParameters = { "moneyIn" }
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_OUT,
    headerParameters = { "moneyOut" },
    cellTemplate = "JournalatorPriceCellTemplate",
    cellParameters = { "moneyOut" }
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = AUCTIONATOR_L_UNIT_PRICE,
    headerParameters = { "unitPrice" },
    cellTemplate = "AuctionatorPriceCellTemplate",
    cellParameters = { "unitPrice" }
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_SOURCE,
    headerParameters = { "sourceCharacter" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "sourceCharacter" },
    defaultHide = true,
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = AUCTIONATOR_L_QUANTITY,
    headerParameters = { "count" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "count" },
    width = 100
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_TIME_ELAPSED,
    headerParameters = { "rawDay" },
    cellTemplate = "JournalatorTimeCellTemplate",
    cellParameters = { "rawDay" }
  },
}

JournalatorVendorItemsDataProviderMixin = CreateFromMixins(JournalatorDisplayDataProviderMixin)

local JUNK_COLOR = "ff9d9d9d"
local function IsNotJunk(itemLink)
  return Auctionator.Utilities.GetQualityColorFromLink(itemLink) ~= JUNK_COLOR
end

function JournalatorVendorItemsDataProviderMixin:Refresh()
  self.onPreserveScroll()
  self:Reset()
  local results = {}
  -- Used to group junk as one item (when the option is on), to avoid filling up
  -- the view with junk items.
  local junkValue = 0
  for index, item in ipairs(Journalator.Archiving.GetRange(self:GetTimeForRange(), "Vendoring")) do
    if self:Filter(item) then
      local moneyIn = 0
      local moneyOut = 0

      if item.vendorType == "sell" then
        moneyIn = item.unitPrice * item.count
      else
        moneyOut = -item.unitPrice * item.count
      end

      -- If not junk or the group junk option is off, include normally
      if not Journalator.Config.Get(Journalator.Config.Options.VENDORING_GROUP_JUNK) or
         IsNotJunk(item.itemLink) then

        local itemNamePretty = item.itemName
        itemNamePretty = Journalator.Utilities.AddQualityIconToItemName(itemNamePretty, item.itemLink)
        itemNamePretty = Journalator.ApplyQualityColor(itemNamePretty, item.itemLink)
        table.insert(results, {
          searchTerm = item.itemName,
          itemName = Journalator.Utilities.AddTierToBasicName(item.itemName, item.itemLink),
          itemNamePretty = itemNamePretty,
          moneyIn = moneyIn,
          moneyOut = moneyOut,
          count = item.count,
          unitPrice = item.unitPrice,
          currencies = item.currencies or {},
          items = item.items or {},
          rawDay = item.time,
          itemLink = item.itemLink,
          sourceCharacter = Journalator.Utilities.AddRealmToPlayerName(item.source.character, item.source),
          index = index,
          value = moneyIn + moneyOut,
          selected = self:IsSelected(index),
        })
      else
        junkValue = junkValue + moneyIn + moneyOut
      end
    end
  end

  -- Create junk group item, without any normal details like a date or source.
  if junkValue ~= 0 and Journalator.Config.Get(Journalator.Config.Options.VENDORING_GROUP_JUNK) then
    local moneyIn = 0
    local moneyOut = 0
    if junkValue > 0 then
      moneyIn = junkValue
    else
      moneyOut = junkValue
    end

    table.insert(results, 1, {
      itemName = JOURNALATOR_L_JUNK,
      itemNamePretty = "|c"..JUNK_COLOR .. JOURNALATOR_L_JUNK .. "|r",
      moneyIn = moneyIn,
      moneyOut = moneyOut,
      count = 1,
      unitPrice = math.abs(junkValue),
      rawDay = time(),
      itemLink = nil,
      sourceCharacter = "",
    })
  end
  self:AppendEntries(results, true)
end

function JournalatorVendorItemsDataProviderMixin:GetTableLayout()
  return VENDORING_DATA_PROVIDER_LAYOUT
end

local COMPARATORS = {
  itemName = Auctionator.Utilities.StringComparator,
  sourceCharacter = Auctionator.Utilities.StringComparator,
  moneyIn = Auctionator.Utilities.NumberComparator,
  moneyOut = Auctionator.Utilities.NumberComparator,
  unitPrice = Auctionator.Utilities.NumberComparator,
  count = Auctionator.Utilities.NumberComparator,
  rawDay = Auctionator.Utilities.NumberComparator,
}

function JournalatorVendorItemsDataProviderMixin:Sort(fieldName, sortDirection)
  local comparator = COMPARATORS[fieldName](sortDirection, fieldName)

  table.sort(self.results, function(left, right)
    return comparator(left, right)
  end)

  self:SetDirty()
end

Journalator.Config.Create("COLUMNS_VENDORING", "columns_vendoring", {})

function JournalatorVendorItemsDataProviderMixin:GetColumnHideStates()
  return Journalator.Config.Get(Journalator.Config.Options.COLUMNS_VENDORING)
end

function JournalatorVendorItemsDataProviderMixin:GetRowTemplate()
  return "JournalatorLogViewVendoringRowTemplate"
end
