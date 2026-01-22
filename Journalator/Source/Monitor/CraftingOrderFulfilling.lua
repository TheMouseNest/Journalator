-- Records crafting orders fulfilling by the current character, including
-- reagents used if possible.
-- Most of the code in this is detecting the reagents used,  with only the
-- OnEvent function really being needed if detecting the order being fulfilling
-- (no reagents) is enough.
local CRAFTING_ORDER_EVENTS = {
  "CRAFTINGORDERS_FULFILL_ORDER_RESPONSE",
}

JournalatorCraftingOrderFulfillingMonitorMixin = {}

-- Only returns reagents in unoccupied slots from toExclude
local function ExcludeMatching(array, toExclude)
  local hits = {}
  for _, item in ipairs(toExclude) do
    hits[item.slotIndex] = true
  end

  local result = {}
  for _, item in ipairs(array) do
    if not hits[item.slotIndex] then
      table.insert(result, item)
    end
  end
  return result
end

local function MergeReagents(existing, toAdd)
  local hits = {}
  for index, item in ipairs(existing) do
    hits[item.itemID] = index
  end

  for _, item in ipairs(toAdd) do
    local index = hits[item.itemID]
    if index then
      existing[index].quantity = existing[index].quantity + item.quantity
    else
      table.insert(existing, item)
    end
  end
end

-- Returns reagents that don't get included in a CraftRecipe API call
local function GetBasicAndNotModifiedReagents(recipeSchematic)
  local result = {}
  for _, reagentSlotSchematic in ipairs(recipeSchematic.reagentSlotSchematics) do
    if reagentSlotSchematic.reagentType == Enum.CraftingReagentType.Basic and
       reagentSlotSchematic.dataSlotType == Enum.TradeskillSlotDataType.Reagent then
      table.insert(result, {
        itemID = reagentSlotSchematic.reagents[1].itemID,
        quantity = reagentSlotSchematic.quantityRequired,
        slotIndex = reagentSlotSchematic.slotIndex
      })
    end
  end
  return result
end

local function GetCustomerReagents(reagentsData)
  local result = {}
  for _, r in ipairs(reagentsData) do
    table.insert(result, {
      itemID = r.reagentInfo.itemID,
      quantity = r.reagentInfo.quantity,
      slotIndex = r.slotIndex, -- Used in ExcludeMatching
    })
  end
  return result
end

local function GetCrafterReagents(customerReagents, allReagents)
  return ExcludeMatching(allReagents, customerReagents)
end

local function GetSlotsWithReagents(recipeSchematic, reagents)
  local reagentsToSlots = {}
  for _, reagentSlotSchematic in ipairs(recipeSchematic.reagentSlotSchematics) do
    for _, reagent in ipairs(reagentSlotSchematic.reagents) do
      reagentsToSlots[reagent.itemID] = reagentSlotSchematic.slotIndex
    end
  end

  local result = {}
  for _, r in ipairs(reagents) do
    table.insert(result, {
      itemID = r.itemID,
      quantity = r.quantity,
      slotIndex = reagentsToSlots[r.itemID] -- Used in ExcludeMatching
    })
  end

  return result
end

function JournalatorCraftingOrderFulfillingMonitorMixin:OnLoad()
  -- Not all state is available in the fulfilled event, so we record the
  -- missing stuff when the API calls that use it happen.

  self:ResetState()

  hooksecurefunc(C_CraftingOrders, "FulfillOrder", function(orderID, crafterNote, profession)
    self:RecordOrder(orderID)
    self.orderDetails.crafterNote = crafterNote
  end)

  -- Normal recipe craft
  hooksecurefunc(C_TradeSkillUI, "CraftRecipe", function(recipeID, _, craftingReagents, _, orderID)
    if orderID == nil then
      -- Prevent other crafts having their reagents included
      self.orderDetails.pendingReagents = nil
      return
    end

    self:RecordOrder(orderID)

    local recipeSchematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)

    -- Note we don't need to consider modified or non-basic reagents that are
    -- not included in the parameters because the recipe must have been
    -- supplied with the complete parameters for a given slot, and if the
    -- needed modified reagents _are_ missing the recipe craft fails.

    self.orderDetails.pendingReagents = GetSlotsWithReagents(recipeSchematic, craftingReagents or {})

    local basicMissingReagents = ExcludeMatching(GetBasicAndNotModifiedReagents(recipeSchematic), self.orderDetails.pendingReagents)

    tAppendAll(self.orderDetails.pendingReagents, basicMissingReagents)

    self:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
  end)

  -- Recraft
  hooksecurefunc(C_TradeSkillUI, "RecraftRecipeForOrder", function(orderID, itemGUID, craftingReagents)
    local claimedOrder = C_CraftingOrders.GetClaimedOrder()
    if not claimedOrder or claimedOrder.orderID ~= orderID then
      -- Prevent other crafts having their reagents included
      self.orderDetails.pendingReagents = nil
      return
    end

    self:RecordOrder(orderID)

    self.orderDetails.orderID = orderID

    local recipeSchematic = C_TradeSkillUI.GetRecipeSchematic(claimedOrder.spellID, true)

    -- Same usage as for the CraftRecipe hook
    self.orderDetails.pendingReagents = GetSlotsWithReagents(recipeSchematic, craftingReagents or {})

    local basicMissingReagents = ExcludeMatching(GetBasicAndNotModifiedReagents(recipeSchematic), self.orderDetails.pendingReagents)

    tAppendAll(self.orderDetails.pendingReagents, basicMissingReagents)

    self:RegisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")
  end)

  FrameUtil.RegisterFrameForEvents(self, CRAFTING_ORDER_EVENTS)
end

function JournalatorCraftingOrderFulfillingMonitorMixin:ResetState()
  self.orderDetails = {}
end

function JournalatorCraftingOrderFulfillingMonitorMixin:RecordOrder(orderID)
  if self.orderDetails.orderID ~= orderID then
    self.orderDetails = {
      orderID = orderID,
      initialCraft = true, -- Is the next successful craft the initial craft and not a further recraft?
      craftCount = 0,
    }
  end
end

function JournalatorCraftingOrderFulfillingMonitorMixin:ProcessReagents()
  local claimedOrder = C_CraftingOrders.GetClaimedOrder()
  if claimedOrder ~= nil and claimedOrder.orderID == self.orderDetails.orderID and self.orderDetails.pendingReagents then
    if self.orderDetails.initialCraft then
      -- Determine the reagents supplied by the crafter by excluding those
      -- attached to the order from the list of potential reagents
      local customerReagentsWithSlots = GetCustomerReagents(claimedOrder.reagents)
      self.orderDetails.crafterReagents = Journalator.Utilities.CleanReagents(GetCrafterReagents(customerReagentsWithSlots, self.orderDetails.pendingReagents))
    else
      -- This is a recraft after the order's initial craft, so just append the
      -- reagents
      MergeReagents(self.orderDetails.crafterReagents, Journalator.Utilities.CleanReagents(self.orderDetails.pendingReagents))
    end
    self.orderDetails.craftCount = self.orderDetails.craftCount + 1
    self.orderDetails.initialCraft = false
    self.orderDetails.pendingReagents = nil
  end
end

-- Use state recorded and event data to create a log entry for fulfilling this
-- crafting order.
function JournalatorCraftingOrderFulfillingMonitorMixin:OnEvent(eventName, ...)
  if eventName == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
    self:ProcessReagents()
    self:UnregisterEvent("TRADE_SKILL_ITEM_CRAFTED_RESULT")

  elseif eventName == "CRAFTINGORDERS_FULFILL_ORDER_RESPONSE" then
    local state, orderID = ...

    if state ~= Enum.CraftingOrderResult.Ok then
      return
    end

    local claimedOrder = C_CraftingOrders.GetClaimedOrder()

    if orderID ~= claimedOrder.orderID or claimedOrder.outputItemHyperlink == nil then
      return
    end

    local crafterNote = ""
    if self.orderDetails.orderID == orderID and self.orderDetails.crafterNote then
      crafterNote = self.orderDetails.crafterNote
    end

    local customerReagents = Journalator.Utilities.CleanReagents(GetCustomerReagents(claimedOrder.reagents))
    local crafterReagents
    if self.orderDetails.orderID == orderID and self.orderDetails.crafterReagents then
      crafterReagents = self.orderDetails.crafterReagents
    end

    local craftAttempts
    if self.orderDetails.orderID == orderID and self.orderDetails.craftCount > 0 then
      craftAttempts = self.orderDetails.craftCount
    end

    local item = Item:CreateFromItemLink(claimedOrder.outputItemHyperlink)
    item:ContinueOnItemLoad(function()
      local itemName = item:GetItemName()

      local guildName
      if claimedOrder.orderType == Enum.CraftingOrderType.Guild then
        guildName = GetGuildInfo("player")
      end

      Journalator.AddToLogs({ Fulfilling = {
        {
        recipeID = claimedOrder.spellID,
        isRecraft = claimedOrder.isRecraft,
        minCraftQuality = claimedOrder.minQuality,

        itemName = itemName,
        itemLink = claimedOrder.outputItemHyperlink,
        customerReagents = customerReagents,
        crafterReagents = crafterReagents,
        craftAttempts = craftAttempts,
        recraftItemLink = claimedOrder.recraftItemHyperlink,
        count = 1,

        orderType = claimedOrder.orderType,
        playerName = claimedOrder.customerName,
        guildName = guildName,

        tipAmount = claimedOrder.tipAmount,
        consortiumCut = claimedOrder.consortiumCut,
        customerNote = claimedOrder.customerNotes,
        crafterNote = crafterNote,

        time = time(),
        source = Journalator.State.Source,
        }
      }})
      self:ResetState()
    end)
  end
end
