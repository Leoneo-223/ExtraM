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