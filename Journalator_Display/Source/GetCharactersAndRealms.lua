local function SearchLog(log, cache, fromTime)
  for _, item in ipairs(log) do
    if item.source ~= nil and item.time >= fromTime then
      local realm = Journalator.Utilities.NormalizeRealmName(item.source.realm)
      if not cache[realm] then
        cache[realm] = {}
      end
      cache[realm][item.source.character] = true
    end
  end
end

function Journalator.GetCharactersAndRealms(fromTime)
  local cache = {}

  SearchLog(Journalator.Archiving.GetRange(fromTime, "Invoices"), cache, fromTime)
  SearchLog(Journalator.Archiving.GetRange(fromTime, "Posting"), cache, fromTime)
  SearchLog(Journalator.Archiving.GetRange(fromTime, "Failures"), cache, fromTime)
  SearchLog(Journalator.Archiving.GetRange(fromTime, "Vendoring"), cache, fromTime)
  SearchLog(Journalator.Archiving.GetRange(fromTime, "VendorRepairs"), cache, fromTime)
  SearchLog(Journalator.Archiving.GetRange(fromTime, "Fulfilling"), cache, fromTime)
  SearchLog(Journalator.Archiving.GetRange(fromTime, "CraftingOrdersPlaced"), cache, fromTime)
  SearchLog(Journalator.Archiving.GetRange(fromTime, "Questing"), cache, fromTime)
  SearchLog(Journalator.Archiving.GetRange(fromTime, "TradingPostVendoring"), cache, fromTime)
  SearchLog(Journalator.Archiving.GetRange(fromTime, "LootContainers"), cache, fromTime)
  SearchLog(Journalator.Archiving.GetRange(fromTime, "BasicMailReceived"), cache, fromTime)
  SearchLog(Journalator.Archiving.GetRange(fromTime, "BasicMailSent"), cache, fromTime)
  SearchLog(Journalator.Archiving.GetRange(fromTime, "Trades"), cache, fromTime)

  return cache
end
