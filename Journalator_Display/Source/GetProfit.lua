function Journalator.GetInOut(startTime, endTime, filter)
  local result  = {}

  filter = filter or function() return true end

  local function Add(name, incoming, outgoing, tabDetails)
    table.insert(result, {name = name, incoming = incoming, outgoing = outgoing, tabDetails = tabDetails})
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_AUCTION_HOUSE) then
    local incoming = 0
    local outgoing = 0
    local invoices = Journalator.Archiving.GetRange(startTime, "Invoices")
    -- Incoming and outgoing gold from sales and purchases
    for _, item in ipairs(invoices) do
      if item.time >= startTime and item.time <= endTime then
        local filterItem = {
          itemName = item.itemName,
          time = item.time,
          source = item.source,
          playerCheck = item.playerName,
        }
        if filter(item) then
          if item.invoiceType == "seller" then
            incoming = incoming + item.value + item.deposit - item.consignment
          else
            outgoing = outgoing + item.value
          end
        end
      end
    end

    -- Lost gold from deposits
    local postings = Journalator.Archiving.GetRange(startTime, "Posting")
    for _, item in ipairs(postings) do
      if item.time >= startTime and item.time <= endTime then
        if filter(item) then
          outgoing = outgoing + item.deposit
        end
      end
    end
    Add(JOURNALATOR_L_AUCTION_HOUSE, incoming, outgoing, {root="AuctionHouse", child="Invoices"})
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_WOW_TOKENS) then
    local incoming = 0
    local outgoing = 0
    local wowTokens = Journalator.Archiving.GetRange(startTime, "WoWTokens")
    for _, item in ipairs(wowTokens) do
      if item.time >= startTime and item.time <= endTime then
        if filter(item) then
          outgoing = outgoing + (item.value or 0)
        end
      end
    end
    Add(JOURNALATOR_L_WOW_TOKENS, incoming, outgoing, {root="AuctionHouse", child="WoWTokens"})
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_CRAFTING_ORDERS) then
    local incoming = 0
    local outgoing = 0
    local fulfillings = Journalator.Archiving.GetRange(startTime, "Fulfilling")
    for _, item in ipairs(fulfillings) do
      if item.time >= startTime and item.time <= endTime then
        local filterItem = {
          itemName = item.itemName,
          time = item.time,
          source = item.source,
          playerCheck = item.playerName,
        }
        if filter(filterItem) then
          incoming = incoming + item.tipAmount - item.consortiumCut
        end
      end
    end

    local placings = Journalator.Archiving.GetRange(startTime, "Placed")
    for _, item in ipairs(placings) do
      if item.time >= startTime and item.time <= endTime then
        local filterItem = {
          itemName = item.itemName,
          time = item.time,
          source = item.source,
          playerCheck = item.crafterName,
        }
        if filter(filterItem) then
          outgoing = outgoing + item.postingFee
        end
      end
    end

    local succeeded = Journalator.Archiving.GetRange(startTime, "CraftingOrdersSucceeded")
    for _, item in ipairs(succeeded) do
      if item.recipeName ~= "" then
        local filterItem = {
          itemName = item.itemName or item.recipeName,
          time = item.time,
          source = item.source,
          playerCheck = item.crafterName,
        }
        if filterItem.time >= startTime and filterItem.time <= endTime then
          if filter(filterItem) then
            outgoing = outgoing + item.commissionPaid
          end
        end
      end
    end
    Add(JOURNALATOR_L_CRAFTING_ORDERS, incoming, outgoing, {root="CraftingOrders"})
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_QUESTING) then
    local incoming = 0
    local outgoing = 0
    local quests = Journalator.Archiving.GetRange(startTime, "Questing")
    for _, item in ipairs(quests) do
      local filterItem = {
        itemName = item.questName,
        time = item.time,
        source = item.source,
      }
      if filterItem.time >= startTime and filterItem.time <= endTime then
        if filter(filterItem) then
          incoming = incoming + item.rewardMoney
          if item.requiredMoney then
            outgoing = outgoing + item.requiredMoney
          end
        end
      end
    end
    Add(JOURNALATOR_L_QUESTING, incoming, outgoing, {root="Questing"})
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_LOOTING) then
    local incoming = 0
    local outgoing = 0
    local looting = Journalator.Archiving.GetRange(startTime, "LootContainers")
    for _, item in ipairs(looting) do
      local filterItem = {
        time = item.time,
        source = item.source,
      }
      if item.type == "item" then
        filterItem.itemName = item.name
      elseif item.type == "npc" then
        filterItem.itemName = item.name
      else
        filterItem.itemName = JOURNALATOR_L_WORLD_OBJECT
      end
      if filterItem.time >= startTime and filterItem.time <= endTime then
        if filter(filterItem) then
          incoming = incoming + item.money
        end
      end
    end
    Add(JOURNALATOR_L_LOOTING, incoming, outgoing, {root="Looting", child="BySource"})
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_VENDORING) then
    local incoming = 0
    local outgoing = 0
    local taxis = Journalator.Archiving.GetRange(startTime, "Taxis")
    for _, item in ipairs(taxis) do
      local filterItem = {
        itemName = item.zone,
        time = item.time,
        source = item.source,
      }
      if filterItem.time >= startTime and filterItem.time <= endTime then
        if filter(filterItem) then
          outgoing = outgoing + item.money
        end
      end
    end
    Add(JOURNALATOR_L_TAXIS, incoming, outgoing, {root="Vendors", child="Taxis"})
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_VENDORING) then
    local incoming = 0
    local outgoing = 0
    local vendorRepairs = Journalator.Archiving.GetRange(startTime, "VendorRepairs")
    for _, item in ipairs(vendorRepairs) do
      local filterItem = {
        itemName = "",
        time = item.time,
        source = item.source,
      }
      if filterItem.time >= startTime and filterItem.time <= endTime then
        if filter(filterItem) then
          outgoing = outgoing + item.money
        end
      end
    end
    Add(JOURNALATOR_L_REPAIRS, incoming, outgoing, {root="Vendors", child="Repairs"})
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_VENDORING) then
    local incoming = 0
    local outgoing = 0
    local trainingCosts = Journalator.Archiving.GetRange(startTime, "TrainingCosts")
    for _, item in ipairs(trainingCosts) do
      local filterItem = {
        itemName = item.item,
        time = item.time,
        source = item.source,
      }
      if filterItem.time >= startTime and filterItem.time <= endTime then
        if filter(filterItem) then
          outgoing = outgoing + item.money
        end
      end
    end
    Add(JOURNALATOR_L_TRAINERS, incoming, outgoing, {root="Vendors", child="TrainingCosts"})
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_VENDORING) then
    local incoming = 0
    local outgoing = 0
    local vendoring = Journalator.Archiving.GetRange(startTime, "Vendoring")
    for _, item in ipairs(vendoring) do
      if item.time >= startTime and item.time <= endTime then
        if filter(item) then
          if item.vendorType == "sell" then
            incoming = incoming + item.unitPrice * item.count
          else
            outgoing = outgoing + item.unitPrice * item.count
          end
        end
      end
    end
    Add(JOURNALATOR_L_VENDORING, incoming, outgoing, {root="Vendors", child="Items"})
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_BASIC_MAIL) then
    local incoming = 0
    local outgoing = 0
    local mailSent = Journalator.Archiving.GetRange(startTime, "BasicMailSent")
    for _, item in ipairs(mailSent) do
      local filterItem = {
        itemName = item.subject,
        time = item.time,
        source = item.source,
        playerCheck = item.recipient,
      }
      if filterItem.time >= startTime and filterItem.time <= endTime then
        if filter(filterItem) then
          outgoing = outgoing + item.money + (item.sendCost or 0)
        end
      end
    end

    local mailReceived = Journalator.Archiving.GetRange(startTime, "BasicMailReceived")
    for _, item in ipairs(mailReceived) do
      local filterItem = {
        itemName = item.subject,
        time = item.time,
        source = item.source,
        playerCheck = item.sender,
      }
      if filterItem.time >= startTime and filterItem.time <= endTime then
        if filter(filterItem) then
          outgoing = outgoing + item.cod
          incoming = incoming + item.money
        end
      end
    end
    Add(JOURNALATOR_L_MAIL, incoming, outgoing, {root="BasicMail", child="Sent"})
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_TRADES) then
    local incoming = 0
    local outgoing = 0
    local trades = Journalator.Archiving.GetRange(startTime, "Trades")
    for _, item in ipairs(trades) do
      local filterItem = {
        itemName = item.player,
        time = item.time,
        source = item.source,
        playerCheck = item.player
      }
      if filterItem.time >= startTime and filterItem.time <= endTime then
        if filter(filterItem) then
          incoming = incoming + item.moneyIn
          outgoing = outgoing + item.moneyOut
        end
      end
    end
    Add(JOURNALATOR_L_TRADES, incoming, outgoing, {root="Trades"})
  end

  if Journalator.Config.Get(Journalator.Config.Options.MONITOR_MISSION_TABLES) then
    local incoming = 0
    local outgoing = 0
    local missions = Journalator.Archiving.GetRange(startTime, "MissionTables")
    for _, item in ipairs(missions) do
      local filterItem = {
        itemName = item.missionName,
        time = item.time,
        source = item.source,
      }
      if filterItem.time >= startTime and filterItem.time <= endTime then
        if filter(filterItem) then
          incoming = incoming + item.money
        end
      end
    end
    Add(JOURNALATOR_L_MISSION_TABLES, incoming, outgoing, {root="MissionTables"})
  end

  return result
end

function Journalator.GetProfit(startTime, endTime, filter)
  local tmp = Journalator.GetInOut(startTime, endTime, filter)

  local incoming = 0
  local outgoing = 0
  for _, entry in ipairs(tmp) do
    incoming = incoming + (entry.incoming or 0)
    outgoing = outgoing + (entry.outgoing or 0)
  end

  return incoming - outgoing, incoming, outgoing
end

function Journalator.GetDetailedProfits(startTime, endTime, filter)
  filter = filter or function() return true end

  local sales = 0
  local purchases = 0
  local lostDeposits = 0
  local lostFees = 0

  local invoices = Journalator.Archiving.GetRange(startTime, "Invoices")
  -- Incoming and outgoing gold from sales and purchases
  for _, item in ipairs(invoices) do
    if item.time >= startTime and item.time <= endTime then
      if filter(item) then
        if item.invoiceType == "seller" then
          sales = sales + item.value
          lostFees = lostFees + item.consignment
          lostDeposits = lostDeposits - item.deposit
        else
          purchases = purchases + item.value
        end
      end
    end
  end

  -- Lost gold from deposits
  local postings = Journalator.Archiving.GetRange(startTime, "Posting")
  for _, item in ipairs(postings) do
    if item.time >= startTime and item.time <= endTime then
      if filter(item) then
        lostDeposits = lostDeposits + item.deposit
      end
    end
  end

  local vendoring = Journalator.Archiving.GetRange(startTime, "Vendoring")
  for _, item in ipairs(vendoring) do
    if item.time >= startTime and item.time <= endTime then
      if filter(item) then
        if item.vendorType == "sell" then
          sales = sales + item.unitPrice * item.count
        else
          purchases = purchases + item.unitPrice * item.count
        end
      end
    end
  end

  local vendorRepairs = Journalator.Archiving.GetRange(startTime, "VendorRepairs")
  for _, item in ipairs(vendorRepairs) do
    local filterItem = {
      itemName = "",
      time = item.time,
      source = item.source,
    }
    if filterItem.time >= startTime and filterItem.time <= endTime then
      if filter(filterItem) then
        purchases = purchases + item.money
      end
    end
  end

  local taxis = Journalator.Archiving.GetRange(startTime, "Taxis")
  for _, item in ipairs(taxis) do
    local filterItem = {
      itemName = item.zone,
      time = item.time,
      source = item.source,
    }
    if filterItem.time >= startTime and filterItem.time <= endTime then
      if filter(filterItem) then
        purchases = purchases + item.money
      end
    end
  end

  local fulfillings = Journalator.Archiving.GetRange(startTime, "Fulfilling")
  for _, item in ipairs(fulfillings) do
    if item.time >= startTime and item.time <= endTime then
      if filter(item) then
        sales = sales + item.tipAmount - item.consortiumCut
      end
    end
  end

  local wowTokens = Journalator.Archiving.GetRange(startTime, "WoWTokens")
  for _, item in ipairs(wowTokens) do
    if item.time >= startTime and item.time <= endTime then
      if filter(item) then
        purchases = purchases + item.value
      end
    end
  end

  return sales, purchases, lostFees, math.max(0, lostDeposits), (sales - purchases - lostDeposits - lostFees)
end
