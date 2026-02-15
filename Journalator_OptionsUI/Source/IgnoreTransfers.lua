JournalatorConfigIgnoreTransfersOptionsFrameMixin = {}

function JournalatorConfigIgnoreTransfersOptionsFrameMixin:OnLoad()
  self:SetParent(SettingsPanel or InterfaceOptionsFrame)
  self.name = JOURNALATOR_L_CONFIG_IGNORE_TRANSFERS
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

  local view = CreateScrollBoxLinearView()
  view:SetPadding(0, 25, 10, 10, 0)
  view:SetPanExtent(50)
  ScrollUtil.InitScrollBoxWithScrollBar(self.ScrollBox, self.ScrollBar, view);
  self.ScrollBox.Content.OnCleaned = function() self.ScrollBox:FullUpdate(ScrollBoxConstants.UpdateImmediately) end

  self.entriesPool = CreateFramePool("Frame", self.ScrollBox.Content, "JournalatorConfigIgnoreTransfersEntryTemplate")

  self.removeFunc = function(index)
    self:Save()
    local ignoreList = Journalator.Config.Get(Journalator.Config.Options.IGNORE_TRANSFERS)
    table.remove(ignoreList, index)
    self:UpdateEntries()
  end

  self.addNewEntryButton = self.ScrollBox.Content.AddNewEntryButton
end

function JournalatorConfigIgnoreTransfersOptionsFrameMixin:OnShow()
  self:UpdateEntries()

  self.shownSettings = true
end

function JournalatorConfigIgnoreTransfersOptionsFrameMixin:AddNewEntry()
  self:Save()

  local ignoreList = Journalator.Config.Get(Journalator.Config.Options.IGNORE_TRANSFERS)
  table.insert(ignoreList, {character="", realm=""})
  self:UpdateEntries()
end

function JournalatorConfigIgnoreTransfersOptionsFrameMixin:UpdateEntries()
  self.entriesPool:ReleaseAll()

  local ignoreList = Journalator.Config.Get(Journalator.Config.Options.IGNORE_TRANSFERS)

  local yOffset = 0

  for index, entry in ipairs(ignoreList) do
    local frame = self.entriesPool:Acquire()
    frame:Show()
    frame:Init(index, entry.character, entry.realm, self.removeFunc)
    frame:SetPoint("LEFT")
    frame:SetPoint("RIGHT")
    frame:SetPoint("TOPLEFT", 0, -yOffset)
    yOffset = yOffset + frame:GetHeight()
  end

  self.ScrollBox.Content:MarkDirty()
end

function JournalatorConfigIgnoreTransfersOptionsFrameMixin:Save()
  local ignoreList = Journalator.Config.Get(Journalator.Config.Options.IGNORE_TRANSFERS)
  for frame in self.entriesPool:EnumerateActive() do
    ignoreList[frame.index] = {character = frame.Character:GetText(), realm = frame.Realm:GetText()}
  end

  if C_AddOns.IsAddOnLoaded("Journalator_Display") then
    Journalator.CacheIgnoredCharacters()
  end
end

function JournalatorConfigIgnoreTransfersOptionsFrameMixin:Cancel()

end

JournalatorConfigIgnoreTransfersEntryMixin = {}
function JournalatorConfigIgnoreTransfersEntryMixin:Init(index, character, realm, removeFunc)
  self.index = index
  self.removeFunc = removeFunc
  self.Character:SetText(character)
  self.Realm:SetText(realm)
end

function JournalatorConfigIgnoreTransfersEntryMixin:Remove()
  self.removeFunc(self.index)
end
