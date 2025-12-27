-- client_ui.lua
-- ExtraM Core | Client UI logic

ExtraM = ExtraM or {}
ExtraM.Players = ExtraM.Players or {}

local lastCash, lastBank = 0, 0

---------------------------------------------------------------------------------------
-- UI
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000) -- every 5 seconds

        ExtraM.GetPlayerStat("cash", function(cashValue)
            if cashValue ~= lastCash then
                StatSetInt(`MP0_WALLET_BALANCE`, cashValue, true)
                lastCash = cashValue
            end
        end)

        ExtraM.GetPlayerStat("bank", function(bankValue)
            if bankValue ~= lastBank then
                StatSetInt(`MP0_BANK_BALANCE`, bankValue, true)
                lastBank = bankValue
            end
        end)
    end
end)
