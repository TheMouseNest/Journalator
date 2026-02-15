JournalatorConfigTooltipsFrameMixin = {}

function JournalatorConfigTooltipsFrameMixin:OnLoad()
  self:SetParent(SettingsPanel or InterfaceOptionsFrame)
  self.name = AUCTIONATOR_L_CONFIG_TOOLTIPS_CATEGORY
  self.parent = JOURNALATOR_L_JOURNALATOR

  self:Show()

  self.cancel = function()
    self:Cancel()
  end

  self.okay = function()
    if self.shownSettings then
      self:Save()
    end
  end

  self.OnCommit = self.okay
  self.OnDefault = function() end
  self.OnRefresh = function() end

  local subcategory = Settings.RegisterCanvasLayoutSubcategory(Journalator.Config.SettingsCategory, self, self.name)
  Settings.RegisterAddOnCategory(subcategory)
end

function JournalatorConfigTooltipsFrameMixin:OnShow()
  if not C_AddOns.IsAddOnLoaded("Journalator_Statistics") then
    for _, frame in ipairs(self.Statistics) do
      frame:SetAlpha(0.5)
    end
  end

  self.TooltipSaleRate:SetChecked(Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_SALE_RATE))
  self.TooltipFailures:SetChecked(Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_FAILURES))
  self.TooltipLastSold:SetChecked(Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_LAST_SOLD))
  self.TooltipLastBought:SetChecked(Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_LAST_BOUGHT))
  self.TooltipSoldStats:SetChecked(Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_SOLD_STATS))
  self.TooltipBoughtStats:SetChecked(Journalator.Config.Get(Journalator.Config.Options.TOOLTIP_BOUGHT_STATS))

  self.shownSettings = true
end

function JournalatorConfigTooltipsFrameMixin:Save()
  Journalator.Config.Set(Journalator.Config.Options.TOOLTIP_SALE_RATE, self.TooltipSaleRate:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.TOOLTIP_FAILURES, self.TooltipFailures:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.TOOLTIP_LAST_SOLD, self.TooltipLastSold:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.TOOLTIP_LAST_BOUGHT, self.TooltipLastBought:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.TOOLTIP_SOLD_STATS, self.TooltipSoldStats:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.TOOLTIP_BOUGHT_STATS, self.TooltipBoughtStats:GetChecked())
end


function JournalatorConfigTooltipsFrameMixin:Cancel()
end
