-- server.lua
-- ExtraM server side function library 

ExtraM = ExtraM or {}
ExtraM.Players = ExtraM.Players or {}

---------------------------------------------------------------------------------------
-- LOG TO DISCORD
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
---@param reason string? 
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

    ExtraM.Log(("Gave %d %s to %s | Reason: %s | New value: %d")
        :format(amount, stat, player.name, reason or "N/A", player[stat]))

    return true
end

---@param source number
---@param stat "cash"|"bank"|"xp"
---@param amount number
---@param reason string? 
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

    ExtraM.Log(("Removed %d %s from %s | Reason: %s | New value: %d")
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
                if stat == "cash" then value = ExtraM.Config.StartingCash end
                if stat == "bank" then value = ExtraM.Config.StartingBank end
                if stat == "xp" then value = 0 end
                if stat == "level" then value = ExtraM.Config.StartingLevel end
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
        ExtraM.Log(("Player %s tried to withdraw %d but only has %d in bank"):format(player.name, amount, player.bank), "warn")
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
        ExtraM.Log(("Player %s tried to deposit %d but only has %d in bank"):format(player.name, amount, player.bank), "warn")
        return false
    end

    ExtraM.RemoveStat(source, "cash", amount, "Deposit")
    ExtraM.GiveStat(source, "bank", amount, "Deposit")
    return true
end

---------------------------------------------------------------------------------------
-- BLIPS

RegisterServerEvent("ExtraM:SaveBlipInfo")
AddEventHandler("ExtraM:SaveBlipInfo", function(blipData)
    local src = source
    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local dataPath = resourcePath .. "/data"

    os.execute(("mkdir \"%s\""):format(dataPath))

    local filePath = dataPath .. "/blip_data.json"

    -- Read existing blips
    local blips = {}
    local file = io.open(filePath, "r")
    if file then
        local content = file:read("*a")
        if content ~= "" then
            blips = json.decode(content)
        end
        file:close()
    end

    table.insert(blips, blipData)

    file = io.open(filePath, "w")
    if file then
        file:write(json.encode(blips))
        file:close()
    else
        ExtraM.Log(("Failed to save blips to %s"):format(filePath), "error")
    end

    ExtraM.Log(("Saved blip from player %s"):format(src), "info")
end)

--[[ I only got saving the blip data into the json file, harder part is gonna be to make it show on the map
    An easier approach would be to create a blips.lua and make a table with all blip data and a script to print that 
    shit in a way i can easily copy & paste into the lua file, but i want it to be a more convienient process 
    instead of my switching tabs like a maniac 
]] 