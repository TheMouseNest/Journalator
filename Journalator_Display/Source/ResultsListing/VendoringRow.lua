JournalatorLogViewVendoringRowMixin = CreateFromMixins(AuctionatorResultsRowTemplateMixin)

JournalatorLogViewVendoringRowMixin.Populate = JournalatorLogViewResultsRowMixin.Populate
JournalatorLogViewVendoringRowMixin.OnClick = JournalatorLogViewResultsRowMixin.OnClick

function JournalatorLogViewVendoringRowMixin:ShowTooltip()
  local tooltip = GameTooltip
  tooltip:SetOwner(self, "ANCHOR_RIGHT")
  self.UpdateTooltip = self.OnEnter

  if string.match(self.rowData.itemLink, "battlepet") then
    BattlePetToolTip_ShowLink(self.rowData.itemLink)
    tooltip = BattlePetTooltip
  else
    GameTooltip:SetHyperlink(self.rowData.itemLink)
  end

  if #self.rowData.currencies > 0 or #self.rowData.items > 0 then
    tooltip:AddLine(" ")
    tooltip:AddLine(JOURNALATOR_L_ADDITIONAL_COSTS_COLON)

    for _, item in ipairs(self.rowData.items) do
      local name, link = C_Item.GetItemInfo(item.itemLink)
      tooltip:AddLine(Journalator.Utilities.GetItemText(item.itemLink, item.quantity))
    end
    for _, item in ipairs(self.rowData.currencies) do
      tooltip:AddLine(Journalator.Utilities.GetCurrencyText(item.currencyID, item.quantity))
    end
  end

  if tooltip == GameTooltip then
    tooltip:Show()
  end
end

function JournalatorLogViewVendoringRowMixin:CancelContinuable()
  if self.continuableContainer then
    self.continuableContainer:Cancel()
    self.continuableContainer = nil
  end
end

function JournalatorLogViewVendoringRowMixin:OnHide()
  self:CancelContinuable()
end

function JournalatorLogViewVendoringRowMixin:OnEnter()
  AuctionatorResultsRowTemplateMixin.OnEnter(self)

  if self.rowData.itemLink == nil then
    return
  end

  self:CancelContinuable()

  self.continuableContainer = ContinuableContainer:Create()

  self.continuableContainer:AddContinuable(Item:CreateFromItemLink(self.rowData.itemLink))
  if self.rowData.items then
    for _, item in ipairs(self.rowData.items) do
      self.continuableContainer:AddContinuable(Item:CreateFromItemLink(item.itemLink))
    end
  end

  self.continuableContainer:ContinueOnLoad(function()
    self.continuableContainer = nil
    self:ShowTooltip()
  end)
end

function JournalatorLogViewVendoringRowMixin:OnLeave()
  AuctionatorResultsRowTemplateMixin.OnLeave(self)

  self.UpdateTooltip = nil
  self:CancelContinuable()

  if not self.rowData or not self.rowData.itemLink then
    return
  end

  if string.match(self.rowData.itemLink, "battlepet") then
    BattlePetTooltip:Hide()
  else
    GameTooltip:Hide()
  end
end
