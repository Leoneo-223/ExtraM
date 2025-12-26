-- client.lua
-- ExtraM Core | Client logic
ExtraM = ExtraM or {}

---------------------------------------------------------------------------------------
-- REQUEST PLAYER STATS (async callback)
function ExtraM.GetPlayerStat(stat, cb)
    RegisterNetEvent("ExtraM:ReturnPlayerStat", function(returnedStat, value)
        if returnedStat == stat then
            cb(value)
        end
    end)

    TriggerServerEvent("ExtraM:GetPlayerStat", stat)
end

---------------------------------------------------------------------------------------
-- GIVE PLAYER STAT
function ExtraM.GiveStat(stat, amount, reason)
    TriggerServerEvent("ExtraM:GiveStat", stat, amount, reason or "Client Request")
end

---------------------------------------------------------------------------------------
-- REMOVE PLAYER STAT
function ExtraM.RemoveStat(stat, amount, reason)
    TriggerServerEvent("ExtraM:RemoveStat", stat, amount, reason or "Client Request")
end

---------------------------------------------------------------------------------------
-- WITHDRAW
function ExtraM.Withdraw(amount)
    TriggerServerEvent("ExtraM:Withdraw", amount)
end

---------------------------------------------------------------------------------------
-- DEPOSIT
function ExtraM.Deposit(amount)
    TriggerServerEvent("ExtraM:Deposit", amount)
end
