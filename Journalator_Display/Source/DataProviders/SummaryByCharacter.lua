local SUMMARY_DATA_PROVIDER_LAYOUT ={
  {
    headerTemplate = "AuctionatorStringColumnHeaderTemplate",
    headerText = JOURNALATOR_L_CHARACTER,
    headerParameters = { "character" },
    cellTemplate = "AuctionatorStringCellTemplate",
    cellParameters = { "character" },
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

JournalatorSummaryByCharacterDataProviderMixin = CreateFromMixins(JournalatorDisplayDataProviderMixin)

function JournalatorSummaryByCharacterDataProviderMixin:Refresh()
  self.onPreserveScroll()
  self:Reset()

  local startTime = self:GetTimeForRange()
  local charactersAndRealms = Journalator.GetCharactersAndRealms(startTime)

  local sortedRealms = Journalator.Utilities.GetSortedKeys(charactersAndRealms)

  local byCharacter = {}

  for _, realm in ipairs(sortedRealms) do
    local sortedCharacters = Journalator.Utilities.GetSortedKeys(charactersAndRealms[realm])
    for _, character in ipairs(sortedCharacters) do
      local profit, incoming, outgoing = Journalator.GetProfit(startTime, time(), function(item)
        if item.source.realm == realm and item.source.character == character then
          return self:Filter(item)
        end
        return false
      end)

      if incoming ~= 0 or outgoing ~= 0 then
        local sourceCharacter = Journalator.Utilities.AddRealmToPlayerName(character, {realm = realm})
        table.insert(byCharacter, {character = sourceCharacter, moneyIn = incoming, moneyOut = -outgoing, profit = incoming - outgoing})
      end
    end
  end

  self:AppendEntries(byCharacter, true)
end

function JournalatorSummaryByCharacterDataProviderMixin:GetTableLayout()
  return SUMMARY_DATA_PROVIDER_LAYOUT
end

local COMPARATORS = {
  character = Auctionator.Utilities.StringComparator,
  moneyIn = Auctionator.Utilities.NumberComparator,
  moneyOut = Auctionator.Utilities.NumberComparator,
}

function JournalatorSummaryByCharacterDataProviderMixin:Sort(fieldName, sortDirection)
  local comparator = COMPARATORS[fieldName](sortDirection, fieldName)

  table.sort(self.results, function(left, right)
    return comparator(left, right)
  end)

  self:SetDirty()
end

Journalator.Config.Create("COLUMNS_SUMMARY_BY_CHARACTER", "columns_summary_by_character", {})

function JournalatorSummaryByCharacterDataProviderMixin:GetColumnHideStates()
  return Journalator.Config.Get(Journalator.Config.Options.COLUMNS_SUMMARY_BY_CHARACTER)
end

function JournalatorSummaryByCharacterDataProviderMixin:GetRowTemplate()
  return "AuctionatorResultsRowTemplate"
end
