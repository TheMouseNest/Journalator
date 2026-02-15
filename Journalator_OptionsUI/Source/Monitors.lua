JournalatorConfigMonitorsOptionsFrameMixin = {}

function JournalatorConfigMonitorsOptionsFrameMixin:OnLoad()
  self:SetParent(SettingsPanel or InterfaceOptionsFrame)
  self.name = JOURNALATOR_L_CONFIG_MONITORS
  self.parent = JOURNALATOR_L_JOURNALATOR

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

  -- Hide options that don't apply to classic
  if Auctionator.Constants.IsClassic then
    self.CraftingOrders:Hide()
    self.TradingPost:Hide()
    self.Questing:SetPoint("TOPLEFT", self.Vendoring, "BOTTOMLEFT")
  end
  if not C_WowTokenPublic.GetCommerceSystemStatus() then
    self.WoWTokens:Hide()
    self.Mail:SetPoint("TOPLEFT", self.Looting, "BOTTOMLEFT")
  end
end

function JournalatorConfigMonitorsOptionsFrameMixin:OnShow()
  -- auction house
  self.AuctionHouse:SetChecked(Journalator.Config.Get(Journalator.Config.Options.MONITOR_AUCTION_HOUSE))
  -- vendors
  self.Vendoring:SetChecked(Journalator.Config.Get(Journalator.Config.Options.MONITOR_VENDORING))
  -- crafting orders
  self.CraftingOrders:SetChecked(Journalator.Config.Get(Journalator.Config.Options.MONITOR_CRAFTING_ORDERS))
  -- trading post
  self.TradingPost:SetChecked(Journalator.Config.Get(Journalator.Config.Options.MONITOR_TRADING_POST))
  -- quest rewards
  self.Questing:SetChecked(Journalator.Config.Get(Journalator.Config.Options.MONITOR_QUESTING))
  -- looting/loot containers
  self.Looting:SetChecked(Journalator.Config.Get(Journalator.Config.Options.MONITOR_LOOTING))
  -- purchasing wow tokens for gold
  self.WoWTokens:SetChecked(Journalator.Config.Get(Journalator.Config.Options.MONITOR_WOW_TOKENS))

  self.Mail:SetChecked(Journalator.Config.Get(Journalator.Config.Options.MONITOR_BASIC_MAIL))
  self.Trades:SetChecked(Journalator.Config.Get(Journalator.Config.Options.MONITOR_TRADES))

  self.shownSettings = true
end

function JournalatorConfigMonitorsOptionsFrameMixin:Save()
  Journalator.Config.Set(Journalator.Config.Options.MONITOR_AUCTION_HOUSE, self.AuctionHouse:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.MONITOR_VENDORING, self.Vendoring:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.MONITOR_CRAFTING_ORDERS, self.CraftingOrders:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.MONITOR_TRADING_POST, self.TradingPost:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.MONITOR_QUESTING, self.Questing:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.MONITOR_LOOTING, self.Looting:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.MONITOR_WOW_TOKENS, self.WoWTokens:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.MONITOR_BASIC_MAIL, self.Mail:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.MONITOR_TRADES, self.Trades:GetChecked())
end

function JournalatorConfigMonitorsOptionsFrameMixin:Cancel()

end
