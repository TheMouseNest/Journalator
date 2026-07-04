Journalator.Tooltips = {}

local function GetSaleRate(itemName)
  local successes = Journalator.API.v1.GetRealmSuccessCountByItemName(JOURNALATOR_L_JOURNALATOR, itemName)
  local failures = Journalator.API.v1.GetRealmFailureCountByItemName(JOURNALATOR_L_JOURNALATOR, itemName)

  if successes == 0 and failures == 0 then
    return AUCTIONATOR_L_UNKNOWN
  else
    return Journalator.Utilities.PrettyPercentage(
      successes / (failures + successes) * 100
    )
  end
end

local function GetFailureCount(itemName)
  return tostring(Journalator.API.v1.GetRealmFailureCountByItemName(JOURNALATOR_L_JOURNALATOR, itemName))
end

local function GetSuccessCount(itemName)
  return tostring(Journalator.API.v1.GetRealmSuccessCountByItemName(JOURNALATOR_L_JOURNALATOR, itemName))
end

local function GetLastSold(itemName)
  return Journalator.API.v1.GetRealmLastSoldByItemName(JOURNALATOR_L_JOURNALATOR, itemName)
end

local function GetLastBought(itemName, itemLink)
  if itemLink ~= nil then
    return Journalator.API.v1.GetRealmLastBoughtByItemLink(JOURNALATOR_L_JOURNALATOR, itemLink)
  else
    return Journalator.API.v1.GetRealmLastBoughtByItemName(JOURNALATOR_L_JOURNALATOR, itemName)
  end
end

local function GetBoughtStats(itemName, itemLink)
  local result
  if itemLink ~= nil then
    result = {
      min = Journalator.API.v1.GetRealmMinBoughtByItemLink(JOURNALATOR_L_JOURNALATOR, itemLink),
      max = Journalator.API.v1.GetRealmMaxBoughtByItemLink(JOURNALATOR_L_JOURNALATOR, itemLink),
      mean = Journalator.API.v1.GetRealmMeanBoughtByItemLink(JOURNALATOR_L_JOURNALATOR, itemLink),
    }
  else
    result = {
      min = Journalator.API.v1.GetRealmMinBoughtByItemName(JOURNALATOR_L_JOURNALATOR, itemName),
      max = Journalator.API.v1.GetRealmMaxBoughtByItemName(JOURNALATOR_L_JOURNALATOR, itemName),
      mean = Journalator.API.v1.GetRealmMeanBoughtByItemName(JOURNALATOR_L_JOURNALATOR, itemName),
    }
  end

  if result.min == nil or result.max == nil or result.mean == nil then
    return nil
  end
  return result
end

local function GetSoldStats(itemName, itemLink)
  local result = {
    min = Journalator.API.v1.GetRealmMinSoldByItemName(JOURNALATOR_L_JOURNALATOR, itemName),
    max = Journalator.API.v1.GetRealmMaxSoldByItemName(JOURNALATOR_L_JOURNALATOR, itemName),
    mean = Journalator.API.v1.GetRealmMeanSoldByItemName(JOURNALATOR_L_JOURNALATOR, itemName),
  }
  if result.min == nil or result.max == nil or result.mean == nil then
    return nil
  end
  return result
end

function Journalator.Tooltips.AnyEnabled()
  return JOURNALATOR_STATISTICS ~= nil and (
    Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_SALE_RATE) or
    Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_FAILURES) or
    Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_LAST_SOLD) or
    Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_LAST_BOUGHT)
    )
end

function Journalator.Tooltips.GetSalesInfo(itemName, itemLink)
  local salesRate, successString, failedString, lastSold, lastBought, boughtStats, soldStats

  if Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_SALE_RATE) then
    salesRate = GetSaleRate(itemName)
  end

  if Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_SUCCESSES) then
    successString = GetSuccessCount(itemName)
  end

  if Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_FAILURES) then
    failedString = GetFailureCount(itemName)
  end

  if Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_LAST_SOLD) then
    lastSold = GetLastSold(itemName)
  end

  if Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_LAST_BOUGHT) then
    lastBought = GetLastBought(itemName, itemLink)
  end

  if Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_SOLD_STATS) then
    soldStats = GetSoldStats(itemName)
  end

  if Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_BOUGHT_STATS) then
    boughtStats = GetBoughtStats(itemName, itemLink)
  end

  return salesRate, successString, failedString, lastSold, lastBought, boughtStats, soldStats
end
