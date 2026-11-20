local N = {}

local CHANNELS = { "Message", "Edit", "Ack", "System", "Typing", "Roll", "Overhead", "History" }
for _, name in ipairs(CHANNELS) do
    N[name] = Ext.Net.CreateChannel(ModuleUUID, "NC_" .. name)
end

N.HISTORY_VAR = "ChatHistory"
Ext.Vars.RegisterModVariable(ModuleUUID, N.HISTORY_VAR, { Server = true, Client = false, Persistent = true })

return N
