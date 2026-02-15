JournalatorConfigBasicOptionsFrameMixin = {}

function JournalatorConfigBasicOptionsFrameMixin:OnLoad()
  self:SetParent(SettingsPanel or InterfaceOptionsFrame)
  self.name = JOURNALATOR_L_JOURNALATOR

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

  local category = Settings.RegisterCanvasLayoutCategory(self, self.name)
  Settings.RegisterAddOnCategory(category)
  Journalator.Config.SettingsCategory = category

  self:SetupDefaultTabChooser()
end

function JournalatorConfigBasicOptionsFrameMixin:OnShow()
  if not C_AddOns.IsAddOnLoaded("Journalator_Statistics") then
    for _, frame in ipairs(self.Statistics) do
      frame:SetAlpha(0.5)
    end
  end

  if not C_AddOns.IsAddOnLoaded("Journalator_Display") then
    for _, frame in ipairs(self.Display) do
      frame:SetAlpha(0.5)
    end
  end

  self.GroupJunk:SetChecked(Journalator.Config.Get(Journalator.Config.Options.VENDORING_GROUP_JUNK))

  self.ShowDetailedStatus:SetChecked(Journalator.Config.Get(Journalator.Config.Options.SHOW_DETAILED_STATUS))

  self.ShowMinimapIcon:SetChecked(not Journalator.Config.Get(Journalator.Config.Options.MINIMAP_ICON).hide)

  self:SetDefaultTabText()

  self.shownSettings = true
end

function JournalatorConfigBasicOptionsFrameMixin:Save()
  Journalator.Config.Set(Journalator.Config.Options.VENDORING_GROUP_JUNK, self.GroupJunk:GetChecked())
  Journalator.Config.Set(Journalator.Config.Options.SHOW_DETAILED_STATUS, self.ShowDetailedStatus:GetChecked())

  Journalator.Config.Get(Journalator.Config.Options.MINIMAP_ICON).hide = not self.ShowMinimapIcon:GetChecked()
  if Journalator.MinimapIcon then
    Journalator.MinimapIcon.UpdateShown()
  end
end

function JournalatorConfigBasicOptionsFrameMixin:ComputeFullStatisticsClicked()
  if Journalator.Statistics == nil then
    Journalator.Utilities.Message("Stats module not loaded XXX")
    return
  end
  Journalator.Archiving.LoadUpTo(0, function()
    Journalator.Statistics.ComputeFullCache()
    Journalator.Utilities.Message(JOURNALATOR_L_FINISHED_COMPUTING_STATISTICS)
  end)
end

function JournalatorConfigBasicOptionsFrameMixin:SetupDefaultTabChooser()
  local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")
  local dropdown = LibDD:Create_UIDropDownMenu(self.DefaultTabChooser)
  LibDD:UIDropDownMenu_SetWidth(dropdown, 220)
  LibDD:UIDropDownMenu_SetInitializeFunction(dropdown, function(_, level, menuList)
    if level == 1 then
      local set = Journalator.Config.Get(Journalator.Config.Options.DEFAULT_TAB)
      for index, tabDetails in ipairs(Journalator.Constants.TabLayout) do
        if not Journalator.Constants.IsClassic or not tabDetails.notClassic then
          local info = LibDD:UIDropDownMenu_CreateInfo()
          info.text = tabDetails.name
          if tabDetails.children then
            info.menuList = tabDetails
            info.hasArrow = true
          end
          info.arg1 = tabDetails
          info.checked = tabDetails.displayMode == set.root
          info.func = function(_, arg1, arg2)
            Journalator.Config.Set(Journalator.Config.Options.DEFAULT_TAB, {
              root = arg1.displayMode, child = "",
            })
            LibDD:CloseDropDownMenus()
            self:SetDefaultTabText()
          end
          LibDD:UIDropDownMenu_AddButton(info)
        end
      end
    elseif menuList ~= nil then
      local set = Journalator.Config.Get(Journalator.Config.Options.DEFAULT_TAB)
      for index, tabDetails in ipairs(menuList.children) do
        if not Journalator.Constants.IsClassic or not tabDetails.notClassic then
          local info = LibDD:UIDropDownMenu_CreateInfo()
          info.text = tabDetails.name
          info.arg1 = tabDetails
          info.checked = menuList.displayMode == set.root and tabDetails.displayMode == set.child
          info.func = function(_, arg1, arg2)
            Journalator.Config.Set(Journalator.Config.Options.DEFAULT_TAB, {
              root = menuList.displayMode, child = arg1.displayMode,
            })
            LibDD:CloseDropDownMenus()
            self:SetDefaultTabText()
          end
          LibDD:UIDropDownMenu_AddButton(info, level)
        end
      end
    end
  end)
end

function JournalatorConfigBasicOptionsFrameMixin:SetDefaultTabText()
  local LibDD = LibStub:GetLibrary("LibUIDropDownMenu-4.0")

  local set = Journalator.Config.Get(Journalator.Config.Options.DEFAULT_TAB)
  for _, tabDetails in ipairs(Journalator.Constants.TabLayout) do
    if tabDetails.displayMode == set.root then
      if tabDetails.children and set.child ~= "" then
        for _, childTabDetails in ipairs(tabDetails.children) do
          if childTabDetails.displayMode == set.child then
            LibDD:UIDropDownMenu_SetText(self.DefaultTabChooser, tabDetails.name .. " -> " .. childTabDetails.name)
          end
        end
      else
        LibDD:UIDropDownMenu_SetText(self.DefaultTabChooser, tabDetails.name)
      end
      break
    end
  end
end

function JournalatorConfigBasicOptionsFrameMixin:Cancel()

end
