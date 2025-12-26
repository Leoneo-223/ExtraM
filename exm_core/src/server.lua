-- server.lua
-- ExtraM Core | Server logic

ExtraM = ExtraM or {}
ExtraM.Players = ExtraM.Players or {}

---------------------------------------------------------------------------------------
-- HELPER FUNCTIONS
-- Get Rockstar license for a player
local function GetLicense(source)
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:sub(1, 8) == "license:" then
            return identifier
        end
    end
    return nil
end

-- Logging function (console + optional Discord webhook)
---@param msg string
---@param level string? ("info", "warn", "error")
function ExtraM.Log(msg, level)
    level = level or "info"

    if ExtraM.Config.DebugMode then
        if level == "info" then
            print(("[ExtraM] %s"):format(msg))
        elseif level == "warn" then
            print(("[ExtraM][WARN] %s"):format(msg))
        elseif level == "error" then
            print(("[ExtraM][ERROR] %s"):format(msg))
        end
    end

    local webhook = ExtraM.Config.Webhooks.DebugLog
    if webhook and webhook ~= "" then
        PerformHttpRequest(webhook, function(err, text, headers) end, "POST", 
            json.encode({
                username = "ExtraM Debug", 
                content = ("`[%s]` %s"):format(level:upper(), msg)
            }), 
            {["Content-Type"] = "application/json"})
    end
end

---------------------------------------------------------------------------------------
-- PLAYER MEMORY ACCESS
--- Returns the player object
---@param source number
---@return table|nil
function ExtraM.GetPlayer(source)
    return ExtraM.Players[source] or nil
end

---------------------------------------------------------------------------------------
-- STATS API (CASH | BANK | XP | LEVEL)
---@param source number
---@param stat "cash"|"bank"|"xp"
---@param amount number
---@param reason string? -- optional description for logging
function ExtraM.GiveStat(source, stat, amount, reason)
    local player = ExtraM.GetPlayer(source)
    if not player then return false end
    if type(amount) ~= "number" or amount <= 0 then return false end
    if stat ~= "cash" and stat ~= "bank" and stat ~= "xp" then return false end

    player[stat] = (player[stat] or 0) + amount

    -- Save to DB
    MySQL.Async.execute(
        ("UPDATE %s SET %s = @value WHERE license = @license"):format(
            ExtraM.Config.Server.PlayerDataTableName, stat
        ),
        {["@value"] = player[stat], ["@license"] = player.license}
    )

    ExtraM.Log(("[ExtraM] Gave %d %s to %s | Reason: %s | New value: %d")
        :format(amount, stat, player.name, reason or "N/A", player[stat]))

    return true
end

---@param source number
---@param stat "cash"|"bank"|"xp"
---@param amount number
---@param reason string? -- optional description for logging
function ExtraM.RemoveStat(source, stat, amount, reason)
    local player = ExtraM.GetPlayer(source)
    if not player then return false end
    if type(amount) ~= "number" or amount <= 0 then return false end
    if stat ~= "cash" and stat ~= "bank" and stat ~= "xp" then return false end

    player[stat] = math.max((player[stat] or 0) - amount, 0)

    -- Save to DB
    MySQL.Async.execute(
        ("UPDATE %s SET %s = @value WHERE license = @license"):format(
            ExtraM.Config.Server.PlayerDataTableName, stat
        ),
        {["@value"] = player[stat], ["@license"] = player.license}
    )

    ExtraM.Log(("[ExtraM] Removed %d %s from %s | Reason: %s | New value: %d")
        :format(amount, stat, player.name, reason or "N/A", player[stat]))

    return true
end

--- Get player stat (async, via callback)
---@param source number
---@param stat "cash"|"bank"|"xp"|"level"
---@param cb function
function ExtraM.GetPlayerStat(source, stat, cb)
    local player = ExtraM.GetPlayer(source)
    if not player then cb(false); return end
    if stat ~= "cash" and stat ~= "bank" and stat ~= "xp" and stat ~= "level" then cb(false); return end

    if player[stat] ~= nil then
        cb(player[stat])
        return
    end

    -- Load from DB
    local license = player.license
    MySQL.Async.fetchScalar(
        ("SELECT %s FROM %s WHERE license = @license"):format(stat, ExtraM.Config.Server.PlayerDataTableName),
        {["@license"] = license},
        function(result)
            local value = result
            if not value then
                if stat == "cash" then value = ExtraM.Config.Server.StartingCash end
                if stat == "bank" then value = ExtraM.Config.Server.StartingBank end
                if stat == "xp" then value = 0 end
                if stat == "level" then value = ExtraM.Config.Server.StartingLevel end
            end
            player[stat] = value
            cb(value)
        end
    )
end

function ExtraM.Withdraw(source, amount)
    local player = ExtraM.GetPlayer(source)
    if not player or amount <= 0 then return false end

    if player.bank < amount then
        ExtraM.Log(("[ExtraM][WARN] Player %s tried to withdraw %d but only has %d in bank")
            :format(player.name, amount, player.bank), "warn")
        return false
    end

    ExtraM.RemoveStat(source, "bank", amount, "Withdrawal")
    ExtraM.GiveStat(source, "cash", amount, "Withdrawal")
    return true
end

function ExtraM.Deposit(source, amount)
    local player = ExtraM.GetPlayer(source)
    if not player or amount <= 0 then return false end

    if player.bank < amount then
        ExtraM.Log(("[ExtraM][WARN] Player %s tried to withdraw %d but only has %d in bank")
            :format(player.name, amount, player.bank), "warn")
        return false
    end

    ExtraM.RemoveStat(source, "cash", amount, "Deposit")
    ExtraM.GiveStat(source, "bank", amount, "Deposit")
    return true
end

---------------------------------------------------------------------------------------
-- PLAYER JOIN / DROP HANDLERS
AddEventHandler("playerJoining", function()
    local source = source
    local name = GetPlayerName(source)
    local license = GetLicense(source)

    if not license then
        DropPlayer(source, "No valid license found")
        return
    end

    -- First, check if the player exists in DB
    MySQL.Async.fetchScalar(
        "SELECT license FROM "..ExtraM.Config.Server.PlayerDataTableName.." WHERE license=@license",
        {["@license"]=license},
        function(result)
            if not result then
                -- Player does not exist yet, insert them
                MySQL.Async.execute(
                    "INSERT INTO "..ExtraM.Config.Server.PlayerDataTableName.." (license, name, cash, bank, xp, level) VALUES (@license,@name,@cash,@bank,@xp,@level)",
                    {
                        ["@license"]=license,
                        ["@name"]=name,
                        ["@cash"]=ExtraM.Config.Server.StartingCash,
                        ["@bank"]=ExtraM.Config.Server.StartingBank,
                        ["@xp"]=0,
                        ["@level"]=ExtraM.Config.Server.StartingLevel
                    }
                )
            end

            -- Initialize player in memory
            ExtraM.Players[source] = {
                source = source,
                name = name,
                license = license,
                cash = ExtraM.Config.Server.StartingCash,
                bank = ExtraM.Config.Server.StartingBank,
                xp = 0,
                level = ExtraM.Config.Server.StartingLevel,
                loaded = false,
                joinedAt = os.time()
            }

            local player = ExtraM.Players[source]
            local statsToLoad = {"cash", "bank", "xp", "level"}
            local loadedCount = 0

            -- Load stats from DB
            for _, stat in ipairs(statsToLoad) do
                ExtraM.GetPlayerStat(source, stat, function(value)
                    player[stat] = value
                    loadedCount = loadedCount + 1

                    if loadedCount == #statsToLoad then
                        player.loaded = true
                        ExtraM.Log(("Player loaded: %s (%s)"):format(player.name, player.license))
                    end
                end)
            end
        end
    )
end)

AddEventHandler("playerDropped", function(reason)
    local source = source
    local player = ExtraM.GetPlayer(source)
    if player then
        ExtraM.Log(("Player dropped: %s | Reason: %s"):format(player.name, reason))
        ExtraM.Players[source] = nil
    end
end)

---------------------------------------------------------------------------------------
-- SERVER EVENTS
RegisterNetEvent("ExtraM:GiveStat")
AddEventHandler("ExtraM:GiveStat", function(stat, amount, reason)
    local src = source
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    if stat ~= "cash" and stat ~= "bank" and stat ~= "xp" then return end

    ExtraM.GiveStat(src, stat, amount, reason)
end)

RegisterNetEvent("ExtraM:RemoveStat")
AddEventHandler("ExtraM:RemoveStat", function(stat, amount, reason)
    local src = source
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end
    if stat ~= "cash" and stat ~= "bank" and stat ~= "xp" then return end

    ExtraM.RemoveStat(src, stat, amount, reason)
end)

RegisterNetEvent("ExtraM:GetPlayerStat")
AddEventHandler("ExtraM:GetPlayerStat", function(stat)
    local src = source
    if stat ~= "cash" and stat ~= "bank" and stat ~= "xp" and stat ~= "level" then return end

    ExtraM.GetPlayerStat(src, stat, function(value)
        TriggerClientEvent("ExtraM:ReturnPlayerStat", src, stat, value)
    end)
end)

RegisterNetEvent("ExtraM:Withdraw")
AddEventHandler("ExtraM:Withdraw", function(amount)
    local src = source
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    ExtraM.Withdraw(src, amount)
end)

RegisterNetEvent("ExtraM:Deposit")
AddEventHandler("ExtraM:Deposit", function(amount)
    local src = source
    amount = tonumber(amount)
    if not amount or amount <= 0 then return end

    ExtraM.Deposit(src, amount)
end)

---------------------------------------------------------------------------------------
-- DEBUG COMMANDS
if ExtraM.Config.DebugMode then
    RegisterCommand("givestat", function(source, args, rawCommand)
        local player = ExtraM.GetPlayer(source)
        if not player then return end

        local stat = args[1]
        local amount = tonumber(args[2])
        if not stat or not amount then
            print("Usage: /givestat [cash|bank|xp] [amount]")
            return
        end

        if ExtraM.GiveStat(source, stat, amount, "Debug Command") then
            print(("[DEBUG] Gave %d %s to %s"):format(amount, stat, player.name))
        end
    end, false)

    RegisterCommand("removestat", function(source, args, rawCommand)
        local player = ExtraM.GetPlayer(source)
        if not player then return end

        local stat = args[1]
        local amount = tonumber(args[2])
        if not stat or not amount then
            print("Usage: /removestat [cash|bank|xp] [amount]")
            return
        end

        if ExtraM.RemoveStat(source, stat, amount, "Debug Command") then
            print(("[DEBUG] Removed %d %s from %s"):format(amount, stat, player.name))
        end
    end, false)

    RegisterCommand("mystats", function(source, args, rawCommand)
        local player = ExtraM.GetPlayer(source)
        if not player then return end
        print(("[DEBUG] %s's stats | Cash: %d | Bank: %d | XP: %d | Level: %d")
            :format(player.name, player.cash, player.bank, player.xp, player.level))
    end, false)

end
