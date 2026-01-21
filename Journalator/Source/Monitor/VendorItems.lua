JournalatorVendorItemsMonitorMixin = {}

local EQUIPMENT_SLOT_CAP = 19

local function GetGUIDFromLocation(location)
  if C_Item.DoesItemExist(location) then
    return C_Item.GetItemGUID(location)
  end
end

local function GetGUIDFromBagAndSlot(bag, slot)
  local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
  return GetGUIDFromLocation(location)
end

local function GetGUIDFromEquipmentSlot(slot)
  local location = ItemLocation:CreateFromEquipmentSlot(slot)
  return GetGUIDFromLocation(location)
end

local function GetCountLinkFromBagAndSlot(bag, slot)
  local info = C_Container.GetContainerItemInfo(bag, slot)

  if info then
    return info.stackCount, info.hyperlink
  else
    return nil
  end
end

local function GetRefundInfo(bag, slot, isEquipped)
  isEquipped = isEquipped or false

  local info = C_Container.GetContainerItemPurchaseInfo(bag, slot, isEquipped)

  local currencies, items = {}, {}
  -- Get the currencies and items returned by the refund
  if C_CurrencyInfo then
    for i = 1, info.currencyCount do
      local currencyInfo = C_Container.GetContainerItemPurchaseCurrency(bag, slot, i, isEquipped)
      local currencyID = Journalator.Utilities.GetCurrencyID(currencyInfo.name)
      if currencyID ~= nil then
        table.insert(currencies, {currencyID = currencyID, quantity = currencyInfo.currencyCount})
      end
    end
  end

  for i = 1, info.itemCount do
    local itemInfo = C_Container.GetContainerItemPurchaseItem(bag, slot, i, isEquipped)
    if itemInfo.hyperlink ~= nil then
      table.insert(items, {itemLink = itemInfo.hyperlink, quantity = itemInfo.itemCount})
    end
  end

  return info.money, currencies, items, info.refundSeconds
end

local function IsGUIDInPossession(guid)
  -- Check if an item in a bag has disappeared/been sold.
  for _, bag in ipairs(Journalator.Constants.BagIDs) do
    -- Start the slots at 0 in include the container's item
    for slot = 0, C_Container.GetContainerNumSlots(bag) do
      if GetGUIDFromBagAndSlot(bag, slot) == guid then
        return true
      end
    end
  end

  -- Check if an equipped item has disappeared/been sold
  for equipmentSlot = 1, Journalator.Constants.EquipmentSlotCap do
    if GetGUIDFromEquipmentSlot(equipmentSlot) == guid then
      return true
    end
  end

  return false
end

local function GetGUIDStackSizes()
  local result = {}

  for _, bag in ipairs(Journalator.Constants.BagIDs) do
    -- Start the slots at 0 in include the container's item
    for slot = 0, C_Container.GetContainerNumSlots(bag) do
      local guid = GetGUIDFromBagAndSlot(bag, slot)
      if guid ~= nil then
        local count, itemLink = GetCountLinkFromBagAndSlot(bag, slot)
        result[guid] = {count = count, itemLink = itemLink}
      end
    end
  end

  --We don't check equipped items as you can't buy directly to an equipment slot

  return result
end

-- Assumes C_Item.GetItemInfo data is loaded
-- Returns true if a bag has the space for all of slotSizeNeeded*itemLink
local function IsLargeEnoughSlotAvailable(itemLink, slotSizeNeeded)
  local stackSize = select(8, C_Item.GetItemInfo(itemLink))

  for _, bag in ipairs(Journalator.Constants.BagIDs) do
    local available = 0

    for slot = 1, C_Container.GetContainerNumSlots(bag) do
      local itemCount, slotLink = GetCountLinkFromBagAndSlot(bag, slot)
      if itemCount == 0 or itemCount == nil then
        available = available + stackSize
      elseif itemLink == slotLink then
        available = available + stackSize - itemCount
      end
    end

    if available >= slotSizeNeeded then
      return true
    end
  end

  return false
end

local MERCHANT_EVENTS = {
  "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE", "MERCHANT_UPDATE"
}

local PURCHASE_VALIDATION_EVENTS = {
  "BAG_UPDATE"
}

function JournalatorVendorItemsMonitorMixin:OnLoad()
  self:ResetQueues()

  FrameUtil.RegisterFrameForEvents(self, MERCHANT_EVENTS)

  self:RegisterRightClickToSellHandlers()
  self:RegisterDragToSellHandlers()
  self:RegisterRefundHandlers()
  self:RegisterSellJunkButton()

  self:RegisterBuybackHandlers()

  self:RegisterPurchaseHandlers()
end

function JournalatorVendorItemsMonitorMixin:OnUpdate()
  self:UpdateCursorItem()

  self:CheckPurchaseQueueForBagSpace()
end

function JournalatorVendorItemsMonitorMixin:ResetQueues()
  -- Used to detect the successful sale or purchase of items
  -- Keeping a queue is necessary as addons automating merchants can make bulk
  -- purchases (reagents) and sales (e.g. of junk) which aren't fulfilled
  -- immediately.
  self.sellQueue = {}
  self.purchaseQueue = {}
end

local ITEM_INFO_QUALITY = 3
local ITEM_INFO_SELL_PRICE = 11

function JournalatorVendorItemsMonitorMixin:RegisterRightClickToSellHandlers()
  local function ProcessDetails(bag, slot)
    if not self.merchantShown then
      return
    end

    local itemCount, itemLink = GetCountLinkFromBagAndSlot(bag, slot)
    if itemLink == nil then
      return
    end

    local item = Item:CreateFromItemLink(itemLink)
    if item:IsItemEmpty() then
      return
    end

    local guid = GetGUIDFromBagAndSlot(bag, slot)
    item:ContinueOnItemLoad(function()
      local vendorPrice = select(ITEM_INFO_SELL_PRICE, C_Item.GetItemInfo(itemLink))
      self.sellQueue[guid] = {
        vendorType = "sell",
        itemName = (C_Item.GetItemInfo(itemLink)),
        count = itemCount,
        unitPrice = vendorPrice,
        itemLink = itemLink,
        time = time(),
        source = Journalator.State.Source,
      }
    end)
  end
  --Detect when an attempt to sell an item is done by right-clicking an item in
  --a bag. This handler also works for addon automated sales.
  hooksecurefunc(C_Container, "UseContainerItem", ProcessDetails)
end

function JournalatorVendorItemsMonitorMixin:RegisterSellJunkButton()
  if not C_MerchantFrame or not C_MerchantFrame.SellAllJunkItems then
    return
  end

  -- Check if the item is junk before adding it to the queue
  local function ProcessMaybeJunkItem(bag, slot)
    local itemCount, itemLink = GetCountLinkFromBagAndSlot(bag, slot)

    if itemLink == nil then
      return
    end

    local item = Item:CreateFromItemLink(itemLink)
    if item:IsItemEmpty() then
      return
    end

    local guid = GetGUIDFromBagAndSlot(bag, slot)

    local info = C_Container.GetContainerItemInfo(bag, slot)
    item:ContinueOnItemLoad(function()
      local quality = select(ITEM_INFO_QUALITY, C_Item.GetItemInfo(itemLink))
      if quality == Enum.ItemQuality.Poor and not info.hasNoValue then
        local vendorPrice = select(ITEM_INFO_SELL_PRICE, C_Item.GetItemInfo(itemLink))
        self.sellQueue[guid] = {
          vendorType = "sell",
          itemName = (C_Item.GetItemInfo(itemLink)),
          count = itemCount,
          unitPrice = vendorPrice,
          itemLink = itemLink,
          time = time(),
          source = Journalator.State.Source,
        }
      end
    end)
  end

  hooksecurefunc(C_MerchantFrame, "SellAllJunkItems", function()
    for _, bag in ipairs(Journalator.Constants.BagIDs) do
      for slot = 1, C_Container.GetContainerNumSlots(bag) do
        ProcessMaybeJunkItem(bag, slot)
      end
    end
  end)
end

-- Used to identify the item selected/being dragged by the cursor
-- The selected item may be sold, destroyed, repositioned in the bag, or left
-- as-is.
function JournalatorVendorItemsMonitorMixin:UpdateCursorItem()
  self.lastCursorItem = nil

  if not self.merchantShown then
    return
  end

  local itemLocation = C_Cursor.GetCursorItem()
  if itemLocation and itemLocation:HasAnyLocation() then
    local guid = GetGUIDFromLocation(itemLocation)
    local itemLink = C_Item.GetItemLink(itemLocation)
    local itemCount = C_Item.GetStackCount(itemLocation)

    -- If the item is currently selected by the cursor it will be locked in the
    -- bag, so it isn't currently waiting for a sale of it to process.
    self.sellQueue[guid] = nil

    local item = Item:CreateFromItemLocation(itemLocation)
    item:ContinueOnItemLoad(function()
      -- If this item has been queued to be sold, it should no longer be on the
      -- cursor and in the queue, we just reset the queue so it works to check
      -- it.
      if self.sellQueue[guid] ~= nil then
        return
      end

      local vendorPrice = select(ITEM_INFO_SELL_PRICE, C_Item.GetItemInfo(itemLink))
      self.lastCursorItem = {
        guid = guid,
        item = {
          vendorType = "sell",
          itemName = (C_Item.GetItemInfo(itemLink)),
          count = itemCount,
          unitPrice = vendorPrice,
          itemLink = itemLink,
          time = time(),
          source = Journalator.State.Source,
        },
      }
    end)
  end
end

function JournalatorVendorItemsMonitorMixin:RegisterDragToSellHandlers()
  local function OnMerchantSell()
    if not self.merchantShown then
      return
    end

    if self.lastCursorItem ~= nil and C_Cursor.GetCursorItem() == nil then
      self.sellQueue[self.lastCursorItem.guid] = self.lastCursorItem.item
    end
    self.lastCursorItem = nil
  end
  -- Handle case when the cursor is used to select and sell an item
  hooksecurefunc(_G, "PickupMerchantItem", OnMerchantSell)
  hooksecurefunc(_G, "SellCursorItem", OnMerchantSell)

  -- Handle pickups by other addons
  hooksecurefunc(_G, "PickupInventoryItem", function()
    self:UpdateCursorItem()
  end)
  hooksecurefunc(_G, "PickupBagFromSlot", function()
    self:UpdateCursorItem()
  end)
  hooksecurefunc(C_Container, "PickupContainerItem", function()
    self:UpdateCursorItem()
  end)
end

-- Used to log refund amounts for heirlooms (and probably a few other refundable
-- items)
function JournalatorVendorItemsMonitorMixin:RegisterRefundHandlers()
  local function ProcessDetails(bag, slot, isEquipped)
    if not self.merchantShown then
      return
    end

    local money, currencies, items, refundSec = GetRefundInfo(bag, slot, isEquipped)

    local itemCount, itemLink = GetCountLinkFromBagAndSlot(bag, slot)

    if itemLink == nil or refundSec == nil then
      return
    end

    local item = Item:CreateFromItemLink(itemLink)
    if item:IsItemEmpty() then
      return
    end

    local guid = GetGUIDFromBagAndSlot(bag, slot)
    item:ContinueOnItemLoad(function()
      self.sellQueue[guid] = {
        vendorType = "sell",
        itemName = (C_Item.GetItemInfo(itemLink)),
        count = itemCount,
        unitPrice = money,
        currencies = currencies,
        items = items, -- Items exchanged to purchase this item
        itemLink = itemLink,
        time = time(),
        source = Journalator.State.Source,
      }
    end)
  end
  hooksecurefunc(C_Container, "ContainerRefundItemPurchase", ProcessDetails)
end

function JournalatorVendorItemsMonitorMixin:UpdateForCompletedSales()
  -- Checks if an item sold to a vendor has disappeared from the player's bag or
  -- equipped items.
  for guid, item in pairs(self.sellQueue) do
    if not IsGUIDInPossession(guid) then
      Journalator.AddToLogs({ Vendoring = {item} })
      self.sellQueue[guid] = nil
    end
  end
end

-- Handle items being repurchased from the vendor aftering having been sold
-- earlier.
function JournalatorVendorItemsMonitorMixin:RegisterBuybackHandlers()
  hooksecurefunc(_G, "BuybackItem", function(index)
    if not self.merchantShown then
      return
    end

    local name, _, price, quantity = GetBuybackItemInfo(index)
    local link = GetBuybackItemLink(index)

    if link == nil then
      return
    end

    -- There is no duplicate check for the same item being clicked multiple
    -- times, as even if there are duplicates, the code checking for a
    -- successful buyback uses guids for the items in the bag to detect newly
    -- purchased ones - avoiding the duplicates.
    table.insert(self.purchaseQueue, {
      vendorType = "buyback",
      itemName = name,
      count = quantity,
      unitPrice = price / quantity,
      currencies = {},
      items = {},
      itemLink = link,
      time = time(),
      source = Journalator.State.Source,
    })
    self:SortPurchaseQueue()
  end)
end

local GetMerchantItemInfo = GetMerchantItemInfo or function(index)
  local info = C_MerchantFrame.GetItemInfo(index);
  if info then
    return info.name, info.texture, info.price, info.stackCount, info.numAvailable, info.isPurchasable, info.isUsable, info.hasExtendedCost, info.currencyID, info.spellID;
  end
end

-- Handle normal purchase of items. This even works when the cursor is used to
-- drag and item from the vendor into a bag.
function JournalatorVendorItemsMonitorMixin:RegisterPurchaseHandlers()
  hooksecurefunc(_G, "BuyMerchantItem", function(index, quantity)
    if not self.merchantShown then
      return
    end

    local name, _, price, stackSize, numInStock = GetMerchantItemInfo(index)
    local link = GetMerchantItemLink(index)
    local maxStackSize = GetMerchantItemMaxStack(index)
    local currencies, items = {}, {}

    quantity = quantity or stackSize

    for i = 1, GetMerchantItemCostInfo(index) do
      local _, quantity, itemLink, currencyName = GetMerchantItemCostItem(index, i)
      if currencyName ~= nil then
        local currencyID = Journalator.Utilities.GetCurrencyID(currencyName)
        if currencyID ~= nil then
          table.insert(currencies, {currencyID = currencyID, quantity = quantity})
        end
      elseif itemLink ~= nil then
        table.insert(items, {itemLink = itemLink, quantity = quantity})
      end
    end

    if
      -- Has an item link (some timewalking items don't)
      link ~= nil
      -- Has a copper/silver/gold price
      and (price ~= 0 or #currencies > 0 or #items > 0)
      -- In stock, and not buying more than on sale
      and (numInStock == -1 or numInStock >= quantity)
      -- Buying more than a maxed out stack fails with "Internal Bag Error"
      and maxStackSize >= quantity
    then
      table.insert(self.purchaseQueue, {
        vendorType = "purchase",
        itemName = name,
        count = quantity,
        unitPrice = price / stackSize,
        currencies = currencies,
        items = items,
        itemLink = link,
        time = time(),
        source = Journalator.State.Source,
      })
      self:SortPurchaseQueue()
    end
  end)
end

function JournalatorVendorItemsMonitorMixin:SortPurchaseQueue()
  -- Sort in descending order by stack size, grouped by item. Used to determine
  -- which purchases have gone through, and affects the order in which items are
  -- added to the vendor logs, by slotting each stack into the new stacks added,
  -- largest to smallest.
  table.sort(self.purchaseQueue, function(a, b)
    if a.itemLink == b.itemLink then
      return b.count < a.count
    else
      return a.itemLink < b.itemLink
    end
  end)
end

function JournalatorVendorItemsMonitorMixin:UpdateForCompletedPurchases()
  if #self.purchaseQueue == 0 then
    return
  end

  local newStackSizes = GetGUIDStackSizes()
  local newQueue = {}
  for _, item in ipairs(self.purchaseQueue) do

    local foundMatch = false

    -- Identify stack with new items in it corresponding to the purchase.
    for guid, details in pairs(newStackSizes) do
      if details.itemLink == item.itemLink then
        if self.oldStackSizes[guid] == nil then
          foundMatch = true
          self.oldStackSizes[guid] = {itemLink = item.itemLink, count = item.count}
          break
        elseif newStackSizes[guid].count - self.oldStackSizes[guid].count >= item.count then
          foundMatch = true
          -- We've accounted for the items, so update the old stack size count
          -- so that we can identify other stacks for other purchases.
          self.oldStackSizes[guid].count = self.oldStackSizes[guid].count + item.count
          break
        end
      end
    end

    if foundMatch then
      Journalator.AddToLogs({ Vendoring = {item} })
    else
      -- Didn't find an appropriate stack of the item in the bag, so leave the
      -- purchase queued.
      table.insert(newQueue, item)
    end
  end

  self.oldStackSizes = newStackSizes
  self.purchaseQueue = newQueue
end

-- Used to remove items from the purchase queue when there is no space for them
-- in a bag
-- Calculating in advance whether a given item will fit when multiple items
-- can be purchased at once is awkward, so we check afterwards to see if ANY of
-- the items can fit independently. So when one item does get added to the bag
-- the remaining items will either fit (and get purchased), or not, and get
-- removed from the queue..
function JournalatorVendorItemsMonitorMixin:CheckPurchaseQueueForBagSpace()
  local newQueue = {}
  for index, item in ipairs(self.purchaseQueue) do
    if C_Item.GetItemInfo(item.itemLink) == nil or
        IsLargeEnoughSlotAvailable(item.itemLink, item.count) then
      table.insert(newQueue, item)
    end
  end

  self.purchaseQueue = newQueue
end

function JournalatorVendorItemsMonitorMixin:OnMerchantShow()
  self:SetScript("OnUpdate", self.OnUpdate)
  FrameUtil.RegisterFrameForEvents(self, PURCHASE_VALIDATION_EVENTS)

  self:ResetQueues()
  self.oldStackSizes = GetGUIDStackSizes()
  self.merchantShown = true
end

function JournalatorVendorItemsMonitorMixin:OnMerchantHide()
  self:SetScript("OnUpdate", nil)
  FrameUtil.UnregisterFrameForEvents(self, PURCHASE_VALIDATION_EVENTS)

  self:ResetQueues()
  self.merchantShown = false
end

function JournalatorVendorItemsMonitorMixin:OnEvent(eventName, ...)
  if eventName == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
    local showType = ...
    if showType == Enum.PlayerInteractionType.Merchant then
      self:OnMerchantShow()
    end

  elseif eventName == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    local hideType = ...
    if hideType == Enum.PlayerInteractionType.Merchant then
      self:OnMerchantHide()
    end

  elseif eventName == "MERCHANT_UPDATE" then
    self:UpdateForCompletedSales()

  elseif eventName == "BAG_UPDATE" then
    self:UpdateForCompletedSales()
    self:UpdateForCompletedPurchases()
  end
end
