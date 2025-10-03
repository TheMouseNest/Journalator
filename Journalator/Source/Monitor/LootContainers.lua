JournalatorLootContainersMonitorMixin = {}

local LootSlotType = Enum.LootSlotType

-- Classic Era
if LootSlotType == nil then
  LootSlotType = {
    None = LOOT_SLOT_NONE,
    Item = LOOT_SLOT_ITEM,
    Money = LOOT_SLOT_MONEY,
    Currency = LOOT_SLOT_CURRENCY,
  }
end

function JournalatorLootContainersMonitorMixin:OnLoad()
  self.currentContainer = nil
  self.waiting = {}

  FrameUtil.RegisterFrameForEvents(self, {
    "LOOT_READY",
    "LOOT_OPENED",
    "LOOT_SLOT_CHANGED",
    "LOOT_SLOT_CLEARED",
    "LOOT_CLOSED",
    "UNIT_SPELLCAST_SENT",
  })
end

function JournalatorLootContainersMonitorMixin:OnEvent(eventName, ...)
  if eventName == "LOOT_READY" then
    self:QueueLooted()
    self:InitialLootCache()

  elseif eventName == "LOOT_OPENED" then
    if self.currentContainer == nil then
      self:QueueLooted()
      self:InitialLootCache()
    end

  -- Check for source quantity changes as loot gets picked up in chunks
  -- internally
  elseif eventName == "LOOT_SLOT_CHANGED" then
    local slot = ...
    self:UpdateCacheSlot(slot)

  -- Loot item finished getting picked up
  elseif eventName == "LOOT_SLOT_CLEARED" then
    if not self.currentContainer then
      return
    end
    local slot = ...
    self:TagLooted(slot)

  -- Loot window closed
  elseif eventName == "LOOT_CLOSED" then
    self:QueueLooted()
    self:AddToLogs()
    self.waiting = {}

  -- Get the name of the object when herbing/mining
  elseif eventName == "UNIT_SPELLCAST_SENT" then
    local unit, targetName = ...
    if (not issecretvalue or (not issecretvalue(unit) and not issecretvalue(targetName))) and unit == "player" then
      self.worldObjectCast = targetName
    end
  end
end

local function ConvertSourceInfo(slot)
  local sources = {GetLootSourceInfo(slot)}
  local converted = {}

  for i = 1, #sources, 2 do
    table.insert(converted, {
      guid = sources[i],
      quantity = sources[i + 1],
    })
  end
  return converted
end

local function MergeSources(result, mergeFrom)
  for _, s1 in ipairs(mergeFrom) do
    local found = false
    for _, s2 in ipairs(result) do
      if s1.guid == s2.guid then
        s2.quantity = s2.quantity + s1.quantity
        found = true
      end
    end
    if not found then
      table.insert(result, s1)
    end
  end
end

local function AccumulateSources(sources)
  local total = 0
  for _, s in ipairs(sources) do
    total = total + s.quantity
  end
  return total
end

local function DebugPrintItem(prefix, item)
  if item.type == LootSlotType.Item then
    Journalator.Debug.Message(prefix, item.slot, item.type, #item.sources, item.itemLink)
  elseif item.type == LootSlotType.Money then
    Journalator.Debug.Message(prefix, item.slot, item.type, #item.sources, GetMoneyString(AccumulateSources(item.sources), true))
  elseif item.type == LootSlotType.Currency then
    local quantity = AccumulateSources(item.sources)
    Journalator.Debug.Message(prefix, item.slot, item.type, #item.sources, (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyLink or GetCurrencyLink)(item.currencyID, quantity), quantity)
  else
    Journalator.Debug.Message(prefix, "missing type")
  end
end

function JournalatorLootContainersMonitorMixin:InitialLootCache()
  self.currentContainer = {}
  for slot = 1, GetNumLootItems() do
    local texture, itemName, quantity, currencyID, itemQuality, locked, isQuestItem, questID, isActive, isCoin = GetLootSlotInfo(slot)

    local link = GetLootSlotLink(slot)
    local sources = ConvertSourceInfo(slot)
    local slotType = GetLootSlotType(slot)

    local item
    if slotType == LootSlotType.Money then
      item = {
        type = LootSlotType.Money,
        sources = sources,
        looted = false,
        slot = slot,

        quantity = quantity,
        lastQuantityShift = 0,
        prevSources = CopyTable(sources),
        importSources = {},
      }
    elseif slotType == LootSlotType.Currency then
      item = {
        type = LootSlotType.Currency,
        currencyID = currencyID,
        sources = sources,
        looted = false,
        slot = slot,

        quantity = quantity,
        lastQuantityShift = 0,
        prevSources = CopyTable(sources),
        importSources = {},
      }
    elseif slotType == LootSlotType.Item then
      item = {
        type = LootSlotType.Item,
        itemLink = link,
        questID = questID,
        sources = sources,
        looted = false,
        slot = slot,

        quantity = quantity,
        lastQuantityShift = 0,
        prevSources = CopyTable(sources),
        importSources = {},
      }
    end

    if item then
      table.insert(self.currentContainer, item)
    end
  end
  Journalator.Debug.Message("loot container cached", #self.currentContainer)
end

local function GetSeen(sources)
  local result = {}
  for _, s in ipairs(sources) do
    result[s.guid .. " " .. s.quantity] = s
  end
  return result
end

function JournalatorLootContainersMonitorMixin:UpdateCacheSlot(slot)
  if self.currentContainer == nil then
    return
  end

  -- Find the slot's information
  local slotInfo
  for _, s in ipairs(self.currentContainer) do
    if s.slot == slot then
      slotInfo = s
    end
  end
  if slotInfo == nil then
    return
  end

  local quantity = select(3, GetLootSlotInfo(slot))

  local shifted = false

  if quantity ~= slotInfo.quantity then
    slotInfo.lastQuantityShift = slotInfo.quantity - quantity
    slotInfo.quantity = quantity
    shifted = true
  end

  local sources = ConvertSourceInfo(slot)

  -- Figure out which chunk (if any) has been picked up
  -- 1. By comparing the chunks that exist this time round to last time
  local oldSeen = GetSeen(slotInfo.prevSources)
  local currentSeen = GetSeen(sources)
  local anyMatched = false
  for k, s in pairs(oldSeen) do
    if currentSeen[k] == nil then
      table.insert(slotInfo.importSources, s)
      anyMatched = true
    end
  end
  -- 2. By matching the quantity size change (backup option for when the items
  -- don't change but the quantity does meaning a chunk got replaced with an
  -- identical one
  if not shifted and not anyMatched and slotInfo.lastQuantityShift > 0 then
    local recovered = false
    for k, s in pairs(oldSeen) do
      if s.quantity == slotInfo.lastQuantityShift then
        table.insert(slotInfo.importSources, s)
        recovered = true
        break
      end
    end

    -- The slot size needed isn't in the current sources list, so invent it
    if not recovered and #sources > 0 then
      Journalator.Debug.Message("recovery miss guessing again", slotInfo.lastQuantityShift)
      table.insert(slotInfo.importSources, {
        guid = sources[1].guid,
        quantity = slotInfo.lastQuantityShift,
      })
    elseif not recovered then
      Journalator.Debug.Message("recovery miss nothing to guess with", #sources, #slotInfo.prevSources)
    end
    slotInfo.lastQuantityShift = 0
  end

  slotInfo.sources = CopyTable(sources)
  MergeSources(slotInfo.sources, CopyTable(slotInfo.importSources))
  slotInfo.prevSources = sources
end

function JournalatorLootContainersMonitorMixin:TagLooted(slot)
  for _, item in ipairs(self.currentContainer) do
    if item.slot == slot and not item.looted then
      DebugPrintItem("loot slot cleared", item)
      item.looted = true
    end
  end
end

function JournalatorLootContainersMonitorMixin:QueueLooted()
  if self.currentContainer == nil then
    return
  end

  for _, item in ipairs(self.currentContainer) do
    if item.looted then
      table.insert(self.waiting, item)
    end
  end

  self.currentContainer = nil
end

local function GroupByGUID(waiting)
  local groups = {}
  for _, item in ipairs(waiting) do
    for _, source in ipairs(item.sources) do
      if not groups[source.guid] then
        groups[source.guid] = {}
      end
      table.insert(groups[source.guid], {
        type = item.type,
        currencyID = item.currencyID,
        questID = item.questID,
        itemLink = item.itemLink,
        quantity = source.quantity,
      })
    end
  end

  return groups
end

function JournalatorLootContainersMonitorMixin:AddToLogs()
  if #self.waiting == 0 then
    return
  end
  Journalator.Debug.Message("loot add to logs", #self.waiting)

  local map = C_Map.GetBestMapForUnit("player")

  local groups = GroupByGUID(self.waiting)
  for guid, items in pairs(groups) do
    local result = {
      name = "",
      map = map,
      money = 0,
      items = {},
      currencies = {},
      source = Journalator.State.Source
    }
    for _, i in ipairs(items) do
      if i.type == LootSlotType.Money then
        result.money = result.money + i.quantity
      elseif i.type == LootSlotType.Currency then
        table.insert(result.currencies, {
          currencyID = i.currencyID,
          quantity = i.quantity,
        })
      elseif i.type == LootSlotType.Item then
        table.insert(result.items, {
          itemLink = i.itemLink,
          quantity = i.quantity,
        })
      end
    end

    Journalator.Debug.Message("loot guid", guid)
    if guid:find("Creature") ~= nil or guid:find("Vehicle") ~= nil then
      result.type = "npc"
      result.npcID = tonumber(guid:match("^%w+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%w+$"))
      Journalator.Utilities.GetNPCDetailsFromGUID(guid, function(details)
        result.name = details.name
        result.time = time()
        Journalator.AddToLogs({ LootContainers = { result } })
      end)
    elseif guid:find("GameObject") ~= nil then
      result.type = "world"
      result.name = self.worldObjectCast or UNKNOWN
      result.objectID = tonumber(guid:match("^%w+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-%w+$"))
      result.time = time()
      Journalator.AddToLogs({ LootContainers = { result } })
    elseif guid:find("Item") ~= nil then
      result.type = "item"
      local location = Journalator.Utilities.GetItemLocationFromGUID(guid)
      if location ~= nil then
        local item = Item:CreateFromItemLocation(location)
        item:ContinueOnItemLoad(function()
          result.itemLink = C_Item.GetItemLink(location)
          result.name = (C_Item.GetItemInfo(result.itemLink))
          result.time = time()

          Journalator.AddToLogs({ LootContainers = { result } })
        end)
      else
        result.time = time()

        Journalator.AddToLogs({ LootContainers = { result } })
      end
    else
      Journalator.Debug.Message("loot guid type not matched")
    end
  end
end
