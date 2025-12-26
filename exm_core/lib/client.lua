-- client.lua
-- ExtraM client side function library 

ExtraM = ExtraM or {}
ExtraM.Players = ExtraM.Players or {}

---------------------------------------------------------------------------------------
-- BLIPS

RegisterCommand("CreateBlip", function(_, args)
    if #args < 4 then
        ExtraM.ShowHelpNotification("Usage: /CreateBlip name blipid colour scale")
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local blipData = {
        name = args[1],
        id = tonumber(args[2]) or 0,
        color = tonumber(args[3]) or 0,
        scale = tonumber(args[4]) or 1,
        x = coords.x,
        y = coords.y,
        z = coords.z
    }

    TriggerServerEvent("ExtraM:SaveBlipInfo", blipData)
    ExtraM.ShowNotification("Blip saved!")
end, false)

---------------------------------------------------------------------------------------
function ExtraM.ShowHelpNotification(text)
    SetTextComponentFormat("STRING")
    AddTextComponentString(text)
    DisplayHelpTextFromStringLabel(0, false, true, -1)
end

function ExtraM.ShowNotification(text)
    SetNotificationTextEntry("STRING")
    AddTextComponentString(text)
    DrawNotification(false, false)
end

RegisterNetEvent("ExtraM:ShowHelpNotification")
AddEventHandler("ExtraM:ShowHelpNotification", function(text)
    ExtraM.ShowHelpNotification(text)
end)

RegisterNetEvent("ExtraM:ShowNotification")
AddEventHandler("ExtraM:ShowNotification", function(text)
    ExtraM.ShowNotification(text)
end)