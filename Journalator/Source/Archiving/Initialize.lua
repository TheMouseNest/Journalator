-- Invoices/Posting/etc. data is separated into stores inside an Archivist
-- instance.
--
-- Each store covers the period of a month (configured by
-- Journalator.Constants.ARCHIVE_INTERVAL), and includes all the
-- Invoices/Posting/etc. entries for that month, stored in the
-- Invoices/Posting/etc. keys, which contain ordered arrays by time ascending of
-- the entries.
--
-- Usage of Archivist is best explained by reading the Github documentation
-- https://github.com/emptyrivers/Archivist
local Archivist = select(2, ...).Archivist

function Journalator.Archiving.InitializeStore(store)
  if store.Version == 1 or store.Version == 2 then
    store.Version = 3
    store.Fulfilling = {}
  end

  if store.Version == 3 then
    store.Version = 4
    store.CraftingOrdersPlaced = {}
  end

  if store.Version == 4 then
    store.Version = 5
    store.Questing = {}
  end

  if store.Version == 5 then
    store.Version = 6
    store.TradingPostVendoring = {}
  end

  if store.Version == 6 then
    store.Version = 7
    store.LootContainers = {}
  end

  if store.Version == 7 then
    store.Version = 8
    store.WoWTokens = {}
  end

  if store.Version == 8 then
    store.Version = 9
    store.VendorRepairs = {}
  end

  if store.Version == 9 then
    store.Version = 10
    store.Taxis = {}
  end

  if store.Version == 10 then
    store.Version = 11
    store.CraftingOrdersFailed = {}
    store.CraftingOrdersSucceeded = {}
  end

  if store.Version == 11 and store.CraftingOrdersFailed == nil then
    store.CraftingOrdersFailed = {}
  end
  if store.Version == 11 and store.CraftingOrdersSucceeded == nil then
    store.CraftingOrdersSucceeded = {}
  end

  if store.Version == 11 then
    store.Version = 12
    store.BasicMailSent = {}
    store.BasicMailReceived = {}
  end

  if store.Version == 12 then
    store.Version = 13
    store.Trades = {}
  end

  if store.Version == 13 then
    store.Version = 14
    store.TrainingCosts = {}
  end

  if store.Version == 14 then
    store.Version = 15
    store.MissionTables = {}
  end

  if store.Version ~= 15 then
    store.Version = 15
    store.Invoices = {}
    store.Posting = {}
    store.Failures = {}
    store.Vendoring = {}
    store.Fulfilling = {}
    store.CraftingOrdersPlaced = {}
    store.CraftingOrdersFailed = {}
    store.CraftingOrdersSucceeded = {}
    store.Questing = {}
    store.TradingPostVendoring = {}
    store.LootContainers = {}
    store.WoWTokens = {}
    store.VendorRepairs = {}
    store.Taxis = {}
    store.BasicMailSent = {}
    store.BasicMailReceived = {}
    store.Trades = {}
    store.TrainingCosts = {}
    store.MissionTables = {}
  end
end

function Journalator.Archiving.Initialize()
  JOURNALATOR_ARCHIVE = JOURNALATOR_ARCHIVE or {}
  local archive = Archivist:Initialize(JOURNALATOR_ARCHIVE)

  -- Upgrade from the old storage format (plain tables with lots of keys)
  -- This can be removed if _all_ users have been converted (2021-07-24).
  if JOURNALATOR_LOGS then
    Journalator.Archiving.Convert2021TablesToStores(JOURNALATOR_LOGS, archive)
    JOURNALATOR_LOGS = nil
  end

  Journalator.State.Archive = archive

  -- Create a store if there aren't any already
  if JOURNALATOR_ARCHIVE_TIMES == nil or #JOURNALATOR_ARCHIVE_TIMES == 0 then
    JOURNALATOR_ARCHIVE_TIMES = {}
    Journalator.Archiving.MakeNewStore()
  end

  Journalator.Archiving.SetState()
end

function Journalator.Archiving.MakeNewStore()
  local storeTime = time()
  local currentStore = Journalator.Constants.STORE_PREFIX .. storeTime

  Journalator.State.Archive:Create("SometimesLocked", currentStore)
  table.insert(JOURNALATOR_ARCHIVE_TIMES, storeTime)
end

function Journalator.Archiving.CloseLastStore()
  Journalator.State.Archive:Create("SometimesLocked", currentStore)
  local storeTime = JOURNALATOR_ARCHIVE_TIMES[#JOURNALATOR_ARCHIVE_TIMES]
  local currentStore = Journalator.Constants.STORE_PREFIX .. storeTime

  Journalator.State.Archive:CloseStore("SometimesLocked", currentStore)
end

function Journalator.Archiving.SetState()
  local storeTime = JOURNALATOR_ARCHIVE_TIMES[#JOURNALATOR_ARCHIVE_TIMES]
  local currentStore = Journalator.Constants.STORE_PREFIX .. storeTime

  Journalator.State.Logs = Journalator.State.Archive:Open("SometimesLocked", currentStore)
  Journalator.Archiving.InitializeStore(Journalator.State.Logs)
  Journalator.State.MinTimeLoaded = time()
end

function Journalator.Archiving.AutogenerateStore()
  local count = 0
  for key, list in pairs(Journalator.State.Logs) do
    if type(list) == "table" then
      count = count + #list
    end
  end
  if count >= Journalator.Constants.STORE_SIZE_LIMIT then
    Journalator.Debug.Message("Generating new store", count)
    Journalator.Archiving.CloseLastStore()
    Journalator.Archiving.MakeNewStore()
    Journalator.Archiving.SetState()
  end
end
