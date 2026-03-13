Journalator.SlashCmd = {}

function Journalator.SlashCmd.Initialize()
  SlashCmdList["Journalator"] = Journalator.SlashCmd.Handler
  SLASH_Journalator1 = "/journalator"
  SLASH_Journalator2 = "/jnr"
end

local INVALID_OPTION_VALUE = "Wrong config value type %s (required %s)"
function Journalator.SlashCmd.Config(optionName, value1, ...)
  if optionName == nil then
    Journalator.Utilities.Message("No config option name supplied")
    for _, name in pairs(Journalator.Config.Options) do
      Journalator.Utilities.Message(name .. ": " .. tostring(Journalator.Config.Get(name)))
    end
    return
  end

  local currentValue = Journalator.Config.Get(optionName)
  if currentValue == nil then
    Journalator.Utilities.Message("Unknown config: " .. optionName)
    return
  end

  if value1 == nil then
    Journalator.Utilities.Message("Config " .. optionName .. ": " .. tostring(currentValue))
    return
  end

  if type(currentValue) == "boolean" then
    if value1 ~= "true" and value1 ~= "false" then
      Journalator.Utilities.Message(INVALID_OPTION_VALUE:format(type(value1), type(currentValue)))
      return
    end
    Journalator.Config.Set(optionName, value1 == "true")
  elseif type(currentValue) == "number" then
    if tonumber(value1) == nil then
      Journalator.Utilities.Message(INVALID_OPTION_VALUE:format(type(value1), type(currentValue)))
      return
    end
    Journalator.Config.Set(optionName, tonumber(value1))
  elseif type(currentValue) == "string" then
    Journalator.Config.Set(optionName, strjoin(" ", value1, ...))
  else
    Journalator.Utilities.Message("Unable to edit option type " .. type(currentValue))
    return
  end
  Journalator.Utilities.Message("Now set " .. optionName .. ": " .. tostring(Journalator.Config.Get(optionName)))
end

function Journalator.SlashCmd.Version()
  Journalator.Utilities.Message(
    BLUE_FONT_COLOR:WrapTextInColorCode("Version: ") .. C_AddOns.GetAddOnMetadata("Journalator", "Version") ..
    LIGHTGRAY_FONT_COLOR:WrapTextInColorCode(", " .. date() .. ", ") ..
    BLUE_FONT_COLOR:WrapTextInColorCode("WoW: ") .. select(4, GetBuildInfo())
  )
end

function Journalator.SlashCmd.Debug(...)
  Journalator.Config.Set(Journalator.Config.Options.DEBUG, not Journalator.Config.Get(Journalator.Config.Options.DEBUG))
  if Journalator.Config.Get(Journalator.Config.Options.DEBUG) then
    Journalator.Utilities.Message("Debug mode on")
  else
    Journalator.Utilities.Message("Debug mode off")
  end
end

local COMMANDS = {
  ["v"] = Journalator.SlashCmd.Version,
  ["version"] = Journalator.SlashCmd.Version,
  ["c"] = Journalator.SlashCmd.Config,
  ["config"] = Journalator.SlashCmd.Config,
  ["d"] = Journalator.SlashCmd.Debug,
  ["debug"] = Journalator.SlashCmd.Debug,
}
function Journalator.SlashCmd.Handler(input)
  if input == "" then
    if Journalator.ToggleView then
      Journalator.ToggleView()
    else
      Journalator.Utilities.Message(JOURNALATOR_L_DISPLAY_DISABLED)
    end
    return
  end

  local split = {strsplit("\a", (input:gsub("%s+","\a")))}

  local root = split[1]
  if COMMANDS[root] ~= nil then
    table.remove(split, 1)
    COMMANDS[root](unpack(split))
  else
    Journalator.Utilities.Message("Unknown command '" .. root .. "'")
  end
end
