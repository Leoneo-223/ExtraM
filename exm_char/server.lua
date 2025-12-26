local function GetLicense(source)
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:sub(1, 8) == "license:" then
            return identifier
        end
    end
    return nil
end

RegisterServerEvent("ExtraM:SaveCharacter")
AddEventHandler("ExtraM:SaveCharacter", function(characterData)
    local src = source
    local license = GetLicense(src)
    if not license then return end

    local jsonData = json.encode(characterData)

    MySQL.Async.execute(
        "UPDATE extram_characters SET character = @character WHERE license = @license",
        {
            ["@character"] = jsonData,
            ["@license"] = license
        },
        function(rowsChanged)
            print(('Saved character for %s'):format(GetPlayerName(src)))
        end
    )
end)

RegisterServerEvent("ExtraM:ServerLoadCharacter")
AddEventHandler("ExtraM:ServerLoadCharacter", function()
    local src = source
    local license = GetLicense(src)
    if not license then return end

    MySQL.Async.fetchScalar(
        "SELECT character FROM extram_characters WHERE license = @license",
        {
            ["@license"] = license
        },
        function(result)
            if result then
                local characterData = json.decode(result)
                TriggerClientEvent("ExtraM:ClientLoadCharacter", src, characterData)
            else
                TriggerClientEvent("ExtraM:ClientLoadCharacter", src, Character)
            end
        end
    )
end)