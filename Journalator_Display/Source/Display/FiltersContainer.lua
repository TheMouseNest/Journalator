JournalatorFiltersContainerMixin = {}

function JournalatorFiltersContainerMixin:OnLoad()
  local now = time()
  -- Used to only scan segments already open for realms and characters
  self.earliestRangeTime = now

  self.lastDailyResetTime = now - 86400 + C_DateAndTime.GetSecondsUntilDailyReset()
  self.lastWeeklyResetTime = now - 7 * 86400 + C_DateAndTime.GetSecondsUntilWeeklyReset()
  
  Auctionator.EventBus:Register(self, {
    Journalator.Events.RowClicked
  })

  self.TimePeriodDropDown:InitAgain(
    Journalator.Constants.TimePeriods.Text,
    Journalator.Constants.TimePeriods.Values
  )
  local currentPeriod = Journalator.Config.Get(Journalator.Config.Options.DEFAULT_TIME_PERIOD)
  if tIndexOf(Journalator.Constants.TimePeriods.Values, currentPeriod) == nil then
    self.TimePeriodDropDown:SetValue(Journalator.Constants.TimePeriods.Month)
    Journalator.Debug.Message("JournalatorFiltersContainer: invalid default time period", tostring(currentPeriod))
  else
    self.TimePeriodDropDown:SetValue(currentPeriod)
  end

  self.FactionDropDown:InitAgain({
    JOURNALATOR_L_ALL_FACTIONS,
    FACTION_ALLIANCE,
    FACTION_HORDE,
  }, {
    "",
    "Alliance",
    "Horde",
  })

  Auctionator.EventBus:RegisterSource(self, "JournalatorFiltersContainer")

  self.filters = self:GetFilters()
  self.pending = false
end

function JournalatorFiltersContainerMixin:OnShow()
  self:UpdateRealmsAndCharacters()
end

function JournalatorFiltersContainerMixin:OnUpdate()
  self:UpdateMinTime(self:GetTimeForRange())
  self:CheckFiltersChanged()
end

function JournalatorFiltersContainerMixin:UpdateRealmsAndCharacters()
  local realmsAndChars = Journalator.GetCharactersAndRealms(self.earliestRangeTime)

  local realms = Journalator.Utilities.GetSortedKeys(realmsAndChars)

  self.RealmDropDown:SetRealms(realms, true)

  self.CharacterDropDown:SetCharacters(realmsAndChars, true)
end

function JournalatorFiltersContainerMixin:CheckFiltersChanged()
  local prevFilters = self.filters
  local hasChanged =
    prevFilters.searchText ~= self.SearchFilter:GetText() or
    prevFilters.secondsToInclude ~= self.TimePeriodDropDown:GetValue() or
    self.RealmDropDown:HasChanged() or
    prevFilters.faction ~= self.FactionDropDown:GetValue() or
    self.CharacterDropDown:HasChanged()

  if hasChanged then
    self.filters = self:GetFilters()
    Auctionator.EventBus:Fire(self, Journalator.Events.FiltersChanged)
  end
end

function JournalatorFiltersContainerMixin:ReceiveEvent(eventName, ...)
  if eventName == Journalator.Events.RowClicked and self:IsVisible() then
    local rowData = ...
    self.SearchFilter:SetText("\"" .. (rowData.searchTerm or rowData.itemName) .. "\"")
  end
end

function JournalatorFiltersContainerMixin:GetTimeForRange()
  local secondsToInclude = self.TimePeriodDropDown:GetValue()
  if secondsToInclude == "server_day" then
    return self.lastDailyResetTime
  elseif secondsToInclude == "server_week" then
    return self.lastWeeklyResetTime
  elseif secondsToInclude == 0 then
    return 0
  else
    return time() - secondsToInclude
  end
end

function JournalatorFiltersContainerMixin:Filter(item)
  local check = true

  if self.filters.secondsToInclude ~= 0 then
    local now = time()
    local itemAge = now - item.time
    if self.filters.secondsToInclude == "server_day" then
      check = check and itemAge <= now - self.lastDailyResetTime
    elseif self.filters.secondsToInclude == "server_week" then
      check = check and itemAge <= now - self.lastWeeklyResetTime
    else
      check = check and itemAge <= self.filters.secondsToInclude
    end
  end

  -- Work around one-time error when source data wasn't saved
  if item.source == nil then
    return false
  end

  check = check and self.filters.realm(item.source.realm)

  if self.filters.faction ~= "" then
    check = check and self.filters.faction == item.source.faction
  end

  check = check and self.filters.character(item.source.character, item.source.realm)

  -- Ignore broken results caused by WoW API not returning a valid name inside
  -- the item link (code that generated them has been replaced, but some may
  -- still exist in Journalator item logs)
  if item.itemName == nil then
    return false
  end

  check = check and (self.filters.search(item.searchTerm or item.itemName) or (item.playerName and self.filters.search(item.playerName)))

  if item.playerCheck ~= nil then
    check = check and Journalator.CheckCharacter(item.playerCheck, item.source)
  end

  return check
end

-- Returns a function that will check if an item name matches any of the current
-- search terms.
function JournalatorFiltersContainerMixin:GetSearch()
  local searchTexts = {strsplit("\a", (self.SearchFilter:GetText():lower():gsub("%|%|", "\a")))}
  local searchTerms = {}
  for _, text in ipairs(searchTexts) do
    local exact = text:match("^\"(.*)\"$")
    if exact ~= nil then
      table.insert(searchTerms, {text = exact, isExact = true})
    else
      table.insert(searchTerms, {text = text, isExact = false})
    end
  end

  return function(itemName)
    if type(itemName) ~= "string" then
      return false
    end
    local lower = string.lower(itemName)
    for _, term in ipairs(searchTerms) do
      if term.isExact then
        if lower == term.text then
          return true
        end
      else
        if string.find(lower, term.text, 1, true) then
          return true
        end
      end
    end
    return false
  end
end

function JournalatorFiltersContainerMixin:GetFilters()
  return {
    search = self:GetSearch(),
    searchText = self.SearchFilter:GetText(), -- Used to check if filter changes
    secondsToInclude = self.TimePeriodDropDown:GetValue(),
    realm = function(realmName) return self.RealmDropDown:GetValue(realmName) end,
    faction = self.FactionDropDown:GetValue(),
    character = function(character, realm) return self.CharacterDropDown:GetValue(character, realm) end,
  }
end

function JournalatorFiltersContainerMixin:UpdateMinTime(newTime)
  if newTime < self.earliestRangeTime then
    self.earliestRangeTime = newTime
    if not self.pending then
      self.pending = true
      Journalator.Archiving.LoadUpTo(self:GetTimeForRange(), function()
        self:UpdateRealmsAndCharacters()
        self.pending = false
      end)
    end
  end
end
