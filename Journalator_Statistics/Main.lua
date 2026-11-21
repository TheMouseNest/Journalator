local STATISTICS_VERSION = 5

Journalator.Statistics = {}

local function InitializeCache()
  if JOURNALATOR_STATISTICS == nil or JOURNALATOR_STATISTICS.Version ~= STATISTICS_VERSION then
    Journalator.Archiving.LoadUpTo(0, function()
      Journalator.Statistics.ComputeFullCache()
      Journalator.Utilities.Message(JOURNALATOR_L_FINISHED_COMPUTING_STATISTICS)
    end)
  elseif not JOURNALATOR_STATISTICS.ForeverFix then
    for realm, target in pairs(JOURNALATOR_STATISTICS.RealmConversion) do
      local converted = Journalator.Utilities.NormalizeRealmName(target)
      if converted ~= target then
        JOURNALATOR_STATISTICS.RealmConversion[realm] = converted
        JOURNALATOR_STATISTICS.RealmConversion[target] = converted
      end
    end

    local new = {
      Version = STATISTICS_VERSION,
      Items = {},
      RealmConversion = {},
      ForeverFix = true,
    }
    for itemName, realmsDetails in pairs(JOURNALATOR_STATISTICS.Items) do
      local itemNew = {}
      for realm, itemDetails in pairs(realmsDetails) do
        local converted = Journalator.Utilities.NormalizeRealmName(realm)
        itemNew[converted] = itemDetails
        new.RealmConversion[converted ] = converted
      end
      new.Items[itemName] = itemNew
    end
    JOURNALATOR_STATISTICS = new
  end

  Auctionator.EventBus:Register({
    ReceiveEvent = function(_, _, newEntries)
      if JOURNALATOR_STATISTICS ~= nil then
        Journalator.Statistics.UpdateCache(newEntries)
      end
    end
  }, {
    Journalator.Events.LogsUpdated,
  })
end

local function AutoCreateCacheEntry(itemName, realm)
  if not JOURNALATOR_STATISTICS.Items[itemName] then
    JOURNALATOR_STATISTICS.Items[itemName] = {}
  end
  if not JOURNALATOR_STATISTICS.Items[itemName][realm] then
    JOURNALATOR_STATISTICS.Items[itemName][realm] = {
      failures = 0,
      successes = 0,
      lastSold = nil,
      lastBought = nil,
      totalSold = { count = 0, value = 0},
      totalBought = { count = 0, value = 0},
    }
  end
  return JOURNALATOR_STATISTICS.Items[itemName][realm]
end

local function AddSellInfo(cache, item)
  local unitPrice = item.value / item.count
  cache.successes = cache.successes + item.count
  cache.lastSold = {
    value = unitPrice,
    time = item.time
  }

  if cache.minSold == nil then
    cache.minSold = unitPrice
  else
    cache.minSold = math.min(cache.minSold, unitPrice)
  end

  if cache.maxSold == nil then
    cache.maxSold = unitPrice
  else
    cache.maxSold = math.max(cache.maxSold, unitPrice)
  end

  cache.totalSold.count = cache.totalSold.count + item.count
  cache.totalSold.value = cache.totalSold.value + item.value
end

local function AddBuyInfo(cache, item)
  local unitPrice = item.value / item.count
  if not cache.lastBought or cache.lastBought.time < item.time then
    cache.lastBought = {
      value = unitPrice,
      time = item.time
    }
  end

  if cache.minBought == nil then
    cache.minBought = unitPrice
  else
    cache.minBought = math.min(cache.minBought, unitPrice)
  end

  if cache.maxBought == nil then
    cache.maxBought = unitPrice
  else
    cache.maxBought = math.max(cache.maxBought, unitPrice)
  end

  cache.totalBought.count = cache.totalBought.count + item.count
  cache.totalBought.value = cache.totalBought.value + item.value
end

function Journalator.Statistics.UpdateCache(newEntries)
  for key, entries in pairs(newEntries) do
    if key == "Invoices" then
      for _, item in ipairs(entries) do
        if item.invoiceType == "seller" then
          AddSellInfo(AutoCreateCacheEntry(item.itemName, item.source.realm), item)

        elseif item.invoiceType == "buyer" then
          -- Store item id specific entry for items purchased in addition to
          -- name only entry so that different DF quality items show the right
          -- last bought price
          Auctionator.Utilities.DBKeyFromLink(item.itemLink, function(dbKeys)
            for _, key in ipairs(dbKeys) do
              AddBuyInfo(AutoCreateCacheEntry(key, item.source.realm), item)
            end
          end)

          -- Store by item name so that the API works and battle pets get last
          -- bought prices
          AddBuyInfo(AutoCreateCacheEntry(item.itemName, item.source.realm), item)
        end
        JOURNALATOR_STATISTICS.RealmConversion[Journalator.Utilities.NormalizeRealmName(item.source.realm)] = item.source.realm
      end

    elseif key == "Failures" then
      for _, item in ipairs(entries) do
        local cache = AutoCreateCacheEntry(item.itemName, item.source.realm)
        cache.failures = cache.failures + item.count
        JOURNALATOR_STATISTICS.RealmConversion[Journalator.Utilities.NormalizeRealmName(item.source.realm)] = item.source.realm
      end
    end
  end
end

local function reverseArray(array)
  local result = {}
  for index = #array, 1, -1 do
    table.insert(result, array[index])
  end

  return result
end
function Journalator.Statistics.ComputeFullCache()
  JOURNALATOR_STATISTICS = {
    Version = STATISTICS_VERSION,
    Items = {},
    RealmConversion = {},
    ForeverFix = true,
  }

  Journalator.Statistics.UpdateCache({
    Invoices = reverseArray(Journalator.Archiving.GetRange(0, "Invoices")),
    Failures = reverseArray(Journalator.Archiving.GetRange(0, "Failures")),
  })
end

function Journalator.Statistics.GetByNormalizedRealmName(itemName, normalizedRealmName)
  if JOURNALATOR_STATISTICS.Items[itemName] ~= nil then
    return JOURNALATOR_STATISTICS.Items[itemName][JOURNALATOR_STATISTICS.RealmConversion[normalizedRealmName]]
  else
    return nil
  end
end

local CORE_EVENTS = {
  "ADDON_LOADED",
}
local coreFrame = CreateFrame("Frame")

FrameUtil.RegisterFrameForEvents(coreFrame, CORE_EVENTS)
coreFrame:SetScript("OnEvent", function(self, eventName, name)
  if eventName == "ADDON_LOADED" and name == "Journalator_Statistics" then
    self:UnregisterEvent("ADDON_LOADED")
    InitializeCache()
  end
end)
