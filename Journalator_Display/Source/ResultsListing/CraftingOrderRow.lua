JournalatorLogViewCraftingOrdersRowMixin = CreateFromMixins(AuctionatorResultsRowTemplateMixin)

JournalatorLogViewCraftingOrdersRowMixin.Populate = JournalatorLogViewResultsRowMixin.Populate
JournalatorLogViewCraftingOrdersRowMixin.OnClick = JournalatorLogViewResultsRowMixin.OnClick

local lightBlue = CreateColor(116/255, 236/255, 252/255)

local function AddReagents(reagents, headerText, noEntriesText, missingText)
  if reagents and #reagents > 0 then
    GameTooltip:AddLine(lightBlue:WrapTextInColorCode(headerText))
    for _, reagent in ipairs(reagents) do
      if reagent.itemID then
        local _, link = C_Item.GetItemInfo(reagent.itemID)
        if link ~= nil then
          GameTooltip:AddLine(WHITE_FONT_COLOR:WrapTextInColorCode(Auctionator.Utilities.GetNameFromLink(link)) .. Auctionator.Utilities.CreateCountString(reagent.quantity))
        end
      else
        GameTooltip:AddLine(WHITE_FONT_COLOR:WrapTextInColorCode(UNKNOWN) .. Auctionator.Utilities.CreateCountString(reagent.quantity))
      end
    end
  elseif reagents then
    GameTooltip:AddLine(lightBlue:WrapTextInColorCode(noEntriesText))
  else
    GameTooltip:AddLine(missingText)
  end
end

function JournalatorLogViewCraftingOrdersRowMixin:ShowTooltip()
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  self.UpdateTooltip = self.OnEnter
  if self.rowData.itemLink then
    GameTooltip:SetHyperlink(self.rowData.itemLink)
  end

  if self.rowData.isRecraft then
    local inQuality = C_TradeSkillUI.GetItemCraftedQualityByItemInfo(self.rowData.recraftItemLink)
    local outQuality = C_TradeSkillUI.GetItemCraftedQualityByItemInfo(self.rowData.itemLink)
    if inQuality ~= nil and outQuality ~= nil then
      GameTooltip:AddLine(" ")
      local text = JOURNALATOR_L_RECRAFT_X_TO_X:format(
        C_Texture.GetCraftingReagentQualityChatIcon(inQuality),
        C_Texture.GetCraftingReagentQualityChatIcon(outQuality)
      )
      GameTooltip:AddLine(lightBlue:WrapTextInColorCode(text))
    end
  end

  GameTooltip:AddLine(" ")
  if self.rowData.customerReagents or self.rowData.crafterReagents then
    AddReagents(self.rowData.customerReagents,
      JOURNALATOR_L_CUSTOMER_REAGENTS_COLON,
      JOURNALATOR_L_NO_CUSTOMER_REAGENTS,
      JOURNALATOR_L_NO_RECORDS_CUSTOMER_REAGENTS
      )

    GameTooltip:AddLine(" ")

    AddReagents(self.rowData.crafterReagents,
      JOURNALATOR_L_CRAFTER_REAGENTS_COLON,
      JOURNALATOR_L_NO_CRAFTER_REAGENTS,
      JOURNALATOR_L_NO_RECORDS_CRAFTER_REAGENTS
      )
  else
    GameTooltip:AddLine(JOURNALATOR_L_NO_RECORDS_FOR_REAGENTS)
  end

  if self.rowData.craftAttempts and self.rowData.craftAttempts > 1 then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(lightBlue:WrapTextInColorCode(JOURNALATOR_L_INCLUDES_EXTRA_CRAFTS))
  end

  if self.rowData.customerNote  and self.rowData.customerNote ~= "" then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(lightBlue:WrapTextInColorCode(JOURNALATOR_L_CUSTOMER_NOTE .. ":"))
    GameTooltip:AddLine(WHITE_FONT_COLOR:WrapTextInColorCode(self.rowData.customerNote), nil, nil, nil, true)
  end

  if self.rowData.crafterNote and self.rowData.crafterNote  ~= "" then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(lightBlue:WrapTextInColorCode(JOURNALATOR_L_CRAFTER_NOTE .. ":"))
    GameTooltip:AddLine(WHITE_FONT_COLOR:WrapTextInColorCode(self.rowData.crafterNote), nil, nil, nil, true)
  end

  GameTooltip:Show()
end

-- Used to prevent tooltip triggering too late and interfering with another
-- tooltip
function JournalatorLogViewCraftingOrdersRowMixin:CancelContinuable()
  if self.continuableContainer then
    self.continuableContainer:Cancel()
    self.continuableContainer = nil
  end
end

function JournalatorLogViewCraftingOrdersRowMixin:OnHide()
  self:CancelContinuable()
end

function JournalatorLogViewCraftingOrdersRowMixin:OnEnter()
  AuctionatorResultsRowTemplateMixin.OnEnter(self)

  self:CancelContinuable()

  local allReagents = CopyTable(self.rowData.customerReagents or {})
  tAppendAll(allReagents, self.rowData.crafterReagents or {})

  self.continuableContainer = ContinuableContainer:Create()

  -- Cache item data for all reagents ready for display in tooltip
  if #allReagents > 0 then
    for _, reagent in ipairs(allReagents) do
      if reagent.itemID then
        self.continuableContainer:AddContinuable(Item:CreateFromItemID(reagent.itemID))
      end
    end
  end

  if self.rowData.isRecraft then
    self.continuableContainer:AddContinuable(Item:CreateFromItemLink(self.rowData.itemLink))
    self.continuableContainer:AddContinuable(Item:CreateFromItemLink(self.rowData.recraftItemLink))
  end

  self.continuableContainer:ContinueOnLoad(function()
    self.continuableContainer = nil
    self:ShowTooltip()
  end)
end

function JournalatorLogViewCraftingOrdersRowMixin:OnLeave()
  AuctionatorResultsRowTemplateMixin.OnLeave(self)
  self.UpdateTooltip = nil
  self:CancelContinuable()
  GameTooltip:Hide()
end
