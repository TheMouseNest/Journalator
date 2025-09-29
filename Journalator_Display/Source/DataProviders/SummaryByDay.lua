local SUMMARY_DATA_PROVIDER_LAYOUT ={
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = AUCTIONATOR_L_DATE,
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

JournalatorSummaryByDayDataProviderMixin = CreateFromMixins(JournalatorDisplayDataProviderMixin)

function JournalatorSummaryByDayDataProviderMixin:Refresh()
  self.onPreserveScroll()
  self:Reset()

  local startTime = self:GetTimeForRange()
  local untilDailyReset = C_DateAndTime.GetSecondsUntilDailyReset()
  local secondsInDay = 24 * 60 * 60
  local dayStart = time() + untilDailyReset - secondsInDay

  local results = {}

  while dayStart >= JOURNALATOR_ARCHIVE_TIMES[1] and dayStart >= startTime do
    local _, incoming, outgoing = Journalator.GetProfit(dayStart, dayStart + secondsInDay, function(item)
      return self:Filter(item)
    end)
    if incoming ~= 0 or outgoing ~= 0 then
      table.insert(results, {
        itemName = Auctionator.Utilities.PrettyDate(dayStart),
        moneyIn = incoming,
        moneyOut = -outgoing,
        profit = incoming - outgoing,
      })
    end

    dayStart = dayStart - secondsInDay
  end

  self:AppendEntries(results, true)
end

function JournalatorSummaryByDayDataProviderMixin:GetTableLayout()
  return SUMMARY_DATA_PROVIDER_LAYOUT
end

local COMPARATORS = {
  itemName = Auctionator.Utilities.StringComparator,
  moneyIn = Auctionator.Utilities.NumberComparator,
  moneyOut = Auctionator.Utilities.NumberComparator,
}

function JournalatorSummaryByDayDataProviderMixin:Sort(fieldName, sortDirection)
  local comparator = COMPARATORS[fieldName](sortDirection, fieldName)

  table.sort(self.results, function(left, right)
    return comparator(left, right)
  end)

  self:SetDirty()
end

Journalator.Config.Create("COLUMNS_SUMMARY_BY_DAY", "columns_summary_by_day", {})

function JournalatorSummaryByDayDataProviderMixin:GetColumnHideStates()
  return Journalator.Config.Get(Journalator.Config.Options.COLUMNS_SUMMARY_BY_DAY)
end

function JournalatorSummaryByDayDataProviderMixin:GetRowTemplate()
  return "AuctionatorResultsRowTemplate"
end
