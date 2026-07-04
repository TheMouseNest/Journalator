Journalator.Config.Options = {
  TOOLTIP_SALE_RATE = "tooltip_sale_rate",
  TOOLTIP_SUCCESSES = "tooltip_successes",
  TOOLTIP_FAILURES = "tooltip_failures",
  TOOLTIP_LAST_SOLD = "tooltip_last_sold",
  TOOLTIP_LAST_BOUGHT = "tooltip_last_bought",
  TOOLTIP_BOUGHT_STATS = "tooltip_bought_stats",
  TOOLTIP_SOLD_STATS = "tooltip_sold_stats",

  VENDORING_GROUP_JUNK = "vendoring_group_junk",
  MINIMAP_ICON = "minimap_icon",

  SHOW_DETAILED_STATUS = "show_detailed_status",
  
  MONITOR_AUCTION_HOUSE = "monitor_auction_house",
  MONITOR_VENDORING = "monitor_vendoring",
  MONITOR_CRAFTING_ORDERS = "monitor_crafting_orders",
  MONITOR_TRADING_POST = "monitor_trading_post",
  MONITOR_QUESTING = "monitor_questing",
  MONITOR_LOOTING = "monitor_looting",
  MONITOR_WOW_TOKENS = "monitor_wow_tokens",
  MONITOR_BASIC_MAIL = "monitor_basic_mail",
  MONITOR_TRADES = "monitor_trades",
  MONITOR_MISSION_TABLES = "monitor_mission_tables",

  DEFAULT_TAB = "default_tab_4",
  DEFAULT_TIME_PERIOD = "default_time_period",

  IGNORE_TRANSFERS = "ignore_transfers",

  DEBUG = "debug",
}

Journalator.Config.Defaults = {
  [Journalator.Config.Options.TOOLTIP_SALE_RATE] = false,
  [Journalator.Config.Options.TOOLTIP_FAILURES] = false,
  [Journalator.Config.Options.TOOLTIP_SUCCESSES] = false,
  [Journalator.Config.Options.TOOLTIP_LAST_SOLD] = true,
  [Journalator.Config.Options.TOOLTIP_LAST_BOUGHT] = true,
  [Journalator.Config.Options.TOOLTIP_BOUGHT_STATS] = false,
  [Journalator.Config.Options.TOOLTIP_SOLD_STATS] = false,
  [Journalator.Config.Options.VENDORING_GROUP_JUNK] = true,
  [Journalator.Config.Options.MINIMAP_ICON] = { hide = false },
  [Journalator.Config.Options.SHOW_DETAILED_STATUS] = false,
  [Journalator.Config.Options.MONITOR_AUCTION_HOUSE] = true,
  [Journalator.Config.Options.MONITOR_VENDORING] = true,
  [Journalator.Config.Options.MONITOR_CRAFTING_ORDERS] = true,
  [Journalator.Config.Options.MONITOR_TRADING_POST] = true,
  [Journalator.Config.Options.MONITOR_QUESTING] = true,
  [Journalator.Config.Options.MONITOR_LOOTING] = true,
  [Journalator.Config.Options.MONITOR_WOW_TOKENS] = true,
  [Journalator.Config.Options.MONITOR_BASIC_MAIL] = true,
  [Journalator.Config.Options.MONITOR_TRADES] = true,
  [Journalator.Config.Options.MONITOR_MISSION_TABLES] = true,
  [Journalator.Config.Options.DEFAULT_TAB] = {root = "Summary", child = ""},
  [Journalator.Config.Options.DEFAULT_TIME_PERIOD] = Journalator.Constants.TimePeriods.Month,
  [Journalator.Config.Options.IGNORE_TRANSFERS] = {--[[{character = "Me", realm="My Realm"}]]},
  [Journalator.Config.Options.DEBUG] = false,
}

function Journalator.Config.IsValidOption(name)
  for _, option in pairs(Journalator.Config.Options) do
    if option == name then
      return true
    end
  end
  return false
end

function Journalator.Config.Create(constant, name, defaultValue)
  Journalator.Config.Options[constant] = name

  Journalator.Config.Defaults[Journalator.Config.Options[constant]] = defaultValue

  if JOURNALATOR_CONFIG ~= nil and JOURNALATOR_CONFIG[name] == nil then
    JOURNALATOR_CONFIG[name] = defaultValue
  end
end

function Journalator.Config.Set(name, value)
  if JOURNALATOR_CONFIG == nil then
    error("JOURNALATOR_CONFIG not initialized")
  elseif not Journalator.Config.IsValidOption(name) then
    error("Invalid option '" .. name .. "'")
  else
    JOURNALATOR_CONFIG[name] = value
  end
end

function Journalator.Config.Reset()
  JOURNALATOR_CONFIG = {}
  for option, value in pairs(Journalator.Config.Defaults) do
    JOURNALATOR_CONFIG[option] = value
  end
end

function Journalator.Config.InitializeData()
  if JOURNALATOR_CONFIG == nil then
    Journalator.Config.Reset()
  else
    for option, value in pairs(Journalator.Config.Defaults) do
      if JOURNALATOR_CONFIG[option] == nil then
        JOURNALATOR_CONFIG[option] = value
      end
    end
  end
end

function Journalator.Config.Get(name)
  -- This is ONLY if a config is asked for before variables are loaded
  if JOURNALATOR_CONFIG == nil then
    return Journalator.Config.Defaults[name]
  else
    return JOURNALATOR_CONFIG[name]
  end
end

function Journalator.Config.Show()
  Journalator.Utilities.Message(JOURNALATOR_L_CONFIG_UI_DISABLED)
end
