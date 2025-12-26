-- server.lua
-- ExtraM Core | Server logic

ExtraM = ExtraM or {}
ExtraM.Players = ExtraM.Players or {}

---------------------------------------------------------------------------------------
-- HELPER FUNCTIONS
local function GetLicense(source)
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:sub(1, 8) == "license:" then
            return identifier
        end
    end
    return nil
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

    -- check if the player exists in DB
    MySQL.Async.fetchScalar(
        "SELECT license FROM "..ExtraM.Config.Server.PlayerDataTableName.." WHERE license=@license",
        {["@license"]=license},
        function(result)
            if not result then
                -- if player does not exist yet, put them with default stats
                MySQL.Async.execute(
                    "INSERT INTO "..ExtraM.Config.Server.PlayerDataTableName.." (license, name, cash, bank, xp, level, `character`) VALUES (@license,@name,@cash,@bank,@xp,@level,@character)",
                    {
                        ["@license"] = license,
                        ["@name"] = name,
                        ["@cash"] = ExtraM.Config.StartingCash,
                        ["@bank"] = ExtraM.Config.StartingBank,
                        ["@xp"] = 0,
                        ["@level"] = ExtraM.Config.StartingLevel,
                        ["@character"] = json.encode({}) -- empty character table
                    },
                    function()
                        TriggerClientEvent("lbg-openChar", source)
                    end
                )
            else
                -- if player exists, check if they have a character
                MySQL.Async.fetchScalar(
                    "SELECT `character` FROM "..ExtraM.Config.Server.PlayerDataTableName.." WHERE license=@license",
                    {["@license"]=license},
                    function(characterData)
                        -- Check if characterData is nil, empty, or the string "null"
                        if not characterData or characterData == "null" or characterData == "" then
                            TriggerClientEvent("lbg-openChar", source)
                        else
                            -- if character exists, load stats into memory

                            local characterData = json.decode(characterData)
                            TriggerClientEvent("ExtraM:ClientLoadCharacter", source, charData)

                            local statsToLoad = {"cash", "bank", "xp", "level"}
                            local loadedCount = 0

                            ExtraM.Players[source] = {
                                source = source,
                                name = name,
                                license = license,
                                cash = ExtraM.Config.StartingCash,
                                bank = ExtraM.Config.StartingBank,
                                xp = 0,
                                level = ExtraM.Config.StartingLevel,
                                loaded = false,
                                joinedAt = os.time()
                            }

                            for _, stat in ipairs(statsToLoad) do
                                ExtraM.GetPlayerStat(source, stat, function(value)
                                    ExtraM.Players[source][stat] = value
                                    loadedCount = loadedCount + 1

                                    if loadedCount == #statsToLoad then
                                        ExtraM.Players[source].loaded = true
                                        ExtraM.Log(("Player loaded: %s (%s)"):format(name, license))
                                    end
                                end)
                            end
                        end
                    end
                )
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
