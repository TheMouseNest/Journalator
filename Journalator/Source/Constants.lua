Journalator.Constants = {
  LINK_INTERVAL = 7 * 24 * 60 * 60,

  STORE_SIZE_LIMIT = 1500,
  STORE_PREFIX = "Logs-",

  QUEST_REWARD_DELAY = 2,
  EARLY_REPUTATION_DELAY = 2,

  PET_CAGE_ID = 82800,
  IsClassic = WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE,
}

local SECONDS_IN_A_MONTH = 30 * 24 * 60 * 60
Journalator.Constants.TimePeriods = {
  Month = SECONDS_IN_A_MONTH,
  Text = {
    JOURNALATOR_L_ALL_TIME,
    JOURNALATOR_L_LAST_YEAR,
    JOURNALATOR_L_LAST_6_MONTHS,
    JOURNALATOR_L_LAST_3_MONTHS,
    JOURNALATOR_L_LAST_MONTH,
    JOURNALATOR_L_LAST_WEEK,
    JOURNALATOR_L_SERVER_WEEK,
    JOURNALATOR_L_LAST_DAY,
    JOURNALATOR_L_SERVER_DAY,
    JOURNALATOR_L_LAST_HOUR,
  },
  Values = {
    0,
    SECONDS_IN_A_MONTH * 12,
    SECONDS_IN_A_MONTH * 6,
    SECONDS_IN_A_MONTH * 3,
    SECONDS_IN_A_MONTH,
    7 * 24 * 60 * 60,
    "server_week",
    24 * 60 * 60,
    "server_day",
    60 * 60,
  }
}

Journalator.Constants.TabLayout = {
  {
    name = JOURNALATOR_L_SUMMARY, displayMode="Summary",
    children = {
      {name = JOURNALATOR_L_BY_TYPE, displayMode="ByType"},
      {name = JOURNALATOR_L_BY_CHARACTER, displayMode="ByCharacter"},
      {name = JOURNALATOR_L_BY_DAY, displayMode="ByDay"},
    }
  },
  {
    name = JOURNALATOR_L_AUCTION_HOUSE, displayMode="AuctionHouse",
    children = {
      {name = JOURNALATOR_L_INVOICES, displayMode="Invoices"},
      {name = JOURNALATOR_L_POSTING, displayMode="Posting"},
      {name = JOURNALATOR_L_SALE_RATES, displayMode="SaleRates"},
      {name = JOURNALATOR_L_FAILURES, displayMode="Failures"},
      {name = JOURNALATOR_L_WOW_TOKENS, displayMode="WoWTokens", notClassic = true},
    }
  },
  {
    name = JOURNALATOR_L_VENDORS, displayMode="Vendors",
    children = {
      {name = JOURNALATOR_L_ITEMS, displayMode="Items"},
      {name = JOURNALATOR_L_REPAIRS, displayMode="Repairs"},
      {name = JOURNALATOR_L_TAXIS, displayMode="Taxis"},
      {name = JOURNALATOR_L_TRAINERS, displayMode="TrainingCosts"},
      {name = JOURNALATOR_L_TRADING_POST, displayMode="TradingPost", notClassic = true},
    }
  },
  {
    name = JOURNALATOR_L_CRAFTING_ORDERS, displayMode="CraftingOrders",
    notClassic = true,
    children = {
      {name = JOURNALATOR_L_FULFILLING, displayMode="Fulfilling"},
      {name = JOURNALATOR_L_PLACING, displayMode="Placing"},
      {name = JOURNALATOR_L_SUCCESSES, displayMode="Succeeded"},
      {name = JOURNALATOR_L_FAILURES, displayMode="Failured"},
    }
  },
  {
    name = JOURNALATOR_L_QUESTING, displayMode="Questing",
    children = {
      {name = JOURNALATOR_L_BY_SOURCE, displayMode="ByQuest"},
      {name = JOURNALATOR_L_BY_ITEM, displayMode="ByItem"},
    }
  },
  {
    name = JOURNALATOR_L_LOOTING, displayMode="Looting",
    children = {
      {name = JOURNALATOR_L_BY_SOURCE, displayMode="BySource"},
      {name = JOURNALATOR_L_BY_ITEM, displayMode="ByItem"},
    }
  },
  {
    name = JOURNALATOR_L_MAIL, displayMode="BasicMail",
    children = {
      {name = JOURNALATOR_L_SENT, displayMode="Sent"},
      {name = JOURNALATOR_L_RECEIVED, displayMode="Received"},
    }
  },
  {
    name = JOURNALATOR_L_TRADES, displayMode="Trades",
  },
  {
    name = JOURNALATOR_L_JOURNALATOR, displayMode="Info",
  },
}

if Journalator.Constants.IsClassic then
  -- Include keyring bag
  Journalator.Constants.BagIDs = {-2, 0, 1, 2, 3, 4}
else
  Journalator.Constants.BagIDs = {0, 1, 2, 3, 4, 5}
end

Journalator.Constants.EquipmentSlotCap = 19

Journalator.Constants.MissionTableTypes = {
  Draenor = 1,
  Legion = 2,
  BattleForAzeroth = 3,
  Shadowlands = 4,
}
