local SUMMARY_DATA_PROVIDER_LAYOUT ={
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = AUCTIONATOR_L_NAME,
    headerParameters = { "itemName" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "itemName" },
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_IN,
    headerParameters = { "moneyIn" },
    cellTemplate = "JournalatorPriceCellTemplate",
    cellParameters = { "moneyIn" },
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_OUT,
    headerParameters = { "moneyOut" },
    cellTemplate = "JournalatorPriceCellTemplate",
    cellParameters = { "moneyOut" },
  },
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_PROFIT,
    headerParameters = { "profit" },
    cellTemplate = "JournalatorPriceCellTemplate",
    cellParameters = { "profit" },
    defaultHide = true,
  },
}

JournalatorSummaryByTypeDataProviderMixin = CreateFromMixins(JournalatorDisplayDataProviderMixin)

function JournalatorSummaryByTypeDataProviderMixin:Refresh()
  self.onPreserveScroll()
  self:Reset()

  local details = Journalator.GetInOut(self:GetTimeForRange(), time(), function(item)
    return self:Filter(item)
  end)

  local results = {}
  for index, item in ipairs(details) do

    if item.incoming ~= 0 or item.outgoing ~= 0 then
      table.insert(results, {
        itemName = item.name,
        moneyIn = item.incoming,
        moneyOut = -item.outgoing,
        profit = item.incoming - item.outgoing,
        tabDetails = item.tabDetails,
        index = index,
      })
    end
  end
  self:AppendEntries(results, true)
end

function JournalatorSummaryByTypeDataProviderMixin:GetTableLayout()
  return SUMMARY_DATA_PROVIDER_LAYOUT
end

local COMPARATORS = {
  itemName = Auctionator.Utilities.StringComparator,
  moneyIn = Auctionator.Utilities.NumberComparator,
  moneyOut = Auctionator.Utilities.NumberComparator,
}

function JournalatorSummaryByTypeDataProviderMixin:Sort(fieldName, sortDirection)
  local comparator = COMPARATORS[fieldName](sortDirection, fieldName)

  table.sort(self.results, function(left, right)
    return comparator(left, right)
  end)

  self:SetDirty()
end

Journalator.Config.Create("COLUMNS_SUMMARY", "columns_summary", {})

function JournalatorSummaryByTypeDataProviderMixin:GetColumnHideStates()
  return Journalator.Config.Get(Journalator.Config.Options.COLUMNS_SUMMARY)
end

function JournalatorSummaryByTypeDataProviderMixin:GetRowTemplate()
  return "JournalatorLogSummaryViewRowTemplate"
end
