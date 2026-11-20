local function GetRealmNames()
  if RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
    return {Journalator.Utilities.GetRegionalRulesetName() or GetRealmName()}
  else
    local connected = GetAutoCompleteRealms()
    if #connected > 0 then
      return connected
    else
      return { GetNormalizedRealmName() }
    end
  end
end

local function ApplyToAssociatedRealms(key, forEach, startingValue)
  local result = startingValue
  for _, realm in ipairs(GetRealmNames()) do
    local realmData = Journalator.Statistics.GetByNormalizedRealmName(key, realm)
    if realmData ~= nil then
      result = forEach(realmData, result)
    end
  end
  return result
end

function Journalator.API.v1.GetRealmFailureCountByItemName(callerID, itemName)
  Journalator.API.CheckID(callerID)
  if type(itemName) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmFailureCountByItemName(string, string)")
  end

  return ApplyToAssociatedRealms(itemName, function(realmData, value)
    return value + realmData.failures
  end, 0)
end

function Journalator.API.v1.GetRealmSuccessCountByItemName(callerID, itemName)
  assert(type(callerID) == "string")
  if type(itemName) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmSuccessCountByItemName(string, string)")
  end

  return ApplyToAssociatedRealms(itemName, function(realmData, value)
    return value + realmData.successes
  end, 0)
end

function Journalator.API.v1.GetRealmLastSoldByItemName(callerID, itemName)
  assert(type(callerID) == "string")
  if type(itemName) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmLastSoldByItemName(string, string)")
  end

  return ApplyToAssociatedRealms(itemName, function(realmData, value)
    if realmData.lastSold ~= nil and value.time < realmData.lastSold.time then
      return { sold = realmData.lastSold.value, time = realmData.lastSold.time }
    else
      return value
    end
  end, {sold = nil, time = 0}).sold
end

local function ApplyLastBoughtToKey(key)
  return ApplyToAssociatedRealms(key, function(realmData, value)
    if realmData.lastBought ~= nil and value.time < realmData.lastBought.time then
      return { bought = realmData.lastBought.value, time = realmData.lastBought.time }
    else
      return value
    end
  end, {bought = nil, time = 0}).bought
end

function Journalator.API.v1.GetRealmLastBoughtByItemName(callerID, itemName)
  assert(type(callerID) == "string")
  if type(itemName) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmLastBoughtByItemName(string, string)")
  end

  return ApplyLastBoughtToKey(itemName)
end

function Journalator.API.v1.GetRealmLastBoughtByItemLink(callerID, itemLink)
  assert(type(callerID) == "string")
  if type(itemLink) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmLastBoughtByItemLink(string, string)")
  end

  local dbKey
  Auctionator.Utilities.DBKeyFromLink(itemLink, function(dbKeys)
    dbKey = dbKeys[1]
  end)
  if dbKey == nil then
    Auctionator.Utilities.BasicDBKeyFromLink(itemLink)
  end

  return ApplyLastBoughtToKey(dbKey)
end

local function ApplyMeanBoughtToKey(key)
  local details = ApplyToAssociatedRealms(key, function(realmData, value)
    return {total = value.total + realmData.totalBought.value, count = value.count + realmData.totalBought.count}
  end, {total = 0, count = 0})

  if details.count ~= 0 then
    return math.floor(details.total / details.count)
  else
    return nil
  end
end

function Journalator.API.v1.GetRealmMeanBoughtByItemName(callerID, itemName)
  assert(type(callerID) == "string")
  if type(itemName) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmMeanBoughtByItemName(string, string)")
  end

  return ApplyMeanBoughtToKey(itemName)
end

function Journalator.API.v1.GetRealmMeanBoughtByItemLink(callerID, itemLink)
  assert(type(callerID) == "string")
  if type(itemLink) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmMeanBoughtByItemLink(string, string)")
  end

  local dbKey
  Auctionator.Utilities.DBKeyFromLink(itemLink, function(dbKeys)
    dbKey = dbKeys[1]
  end)
  if dbKey == nil then
    Auctionator.Utilities.BasicDBKeyFromLink(itemLink)
  end

  return ApplyMeanBoughtToKey(dbKey)
end

local function ApplyMinBoughtToKey(key)
  return ApplyToAssociatedRealms(key, function(realmData, value)
    if value == nil then
      return realmData.minBought
    elseif realmData.minBought ~= nil then
      return math.min(realmData.minBought, value)
    else
      return value
    end
  end, nil)
end

function Journalator.API.v1.GetRealmMinBoughtByItemName(callerID, itemName)
  assert(type(callerID) == "string")
  if type(itemName) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmMinBoughtByItemName(string, string)")
  end

  return ApplyMinBoughtToKey(itemName)
end

function Journalator.API.v1.GetRealmMinBoughtByItemLink(callerID, itemLink)
  assert(type(callerID) == "string")
  if type(itemLink) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmMinBoughtByItemLink(string, string)")
  end

  local dbKey
  Auctionator.Utilities.DBKeyFromLink(itemLink, function(dbKeys)
    dbKey = dbKeys[1]
  end)
  if dbKey == nil then
    Auctionator.Utilities.BasicDBKeyFromLink(itemLink)
  end

  return ApplyMinBoughtToKey(dbKey)
end

local function ApplyMaxBoughtToKey(key)
  return ApplyToAssociatedRealms(key, function(realmData, value)
    if value == nil then
      return realmData.maxBought
    elseif realmData.maxBought ~= nil then
      return math.max(realmData.maxBought, value)
    else
      return value
    end
  end, nil)
end

function Journalator.API.v1.GetRealmMaxBoughtByItemName(callerID, itemName)
  assert(type(callerID) == "string")
  if type(itemName) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmMaxBoughtByItemName(string, string)")
  end

  return ApplyMaxBoughtToKey(itemName)
end

function Journalator.API.v1.GetRealmMaxBoughtByItemLink(callerID, itemLink)
  assert(type(callerID) == "string")
  if type(itemLink) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmMaxBoughtByItemLink(string, string)")
  end

  local dbKey
  Auctionator.Utilities.DBKeyFromLink(itemLink, function(dbKeys)
    dbKey = dbKeys[1]
  end)
  if dbKey == nil then
    Auctionator.Utilities.BasicDBKeyFromLink(itemLink)
  end

  return ApplyMaxBoughtToKey(dbKey)
end

function Journalator.API.v1.GetRealmMeanSoldByItemName(callerID, itemName)
  assert(type(callerID) == "string")
  if type(itemName) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmMeanSoldByItemName(string, string)")
  end

  local details = ApplyToAssociatedRealms(itemName, function(realmData, value)
    return {total = value.total + realmData.totalSold.value, count = value.count + realmData.totalSold.count}
  end, {total = 0, count = 0})

  if details.count ~= 0 then
    return math.floor(details.total / details.count)
  else
    return nil
  end
end

function Journalator.API.v1.GetRealmMinSoldByItemName(callerID, itemName)
  assert(type(callerID) == "string")
  if type(itemName) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmMinSoldByItemName(string, string)")
  end

  return ApplyToAssociatedRealms(itemName, function(realmData, value)
    if value == nil then
      return realmData.minSold
    elseif realmData.minSold ~= nil then
      return math.min(realmData.minSold, value)
    else
      return value
    end
  end, nil)
end

function Journalator.API.v1.GetRealmMaxSoldByItemName(callerID, itemName)
  assert(type(callerID) == "string")
  if type(itemName) ~= "string" then
    Journalator.API.ComposeError(callerID, "Usage Journalator.API.v1.GetRealmMaxSoldByItemName(string, string)")
  end

  return ApplyToAssociatedRealms(itemName, function(realmData, value)
    if value == nil then
      return realmData.maxSold
    elseif realmData.maxSold ~= nil then
      return math.max(realmData.maxSold, value)
    else
      return value
    end
  end, nil)
end
