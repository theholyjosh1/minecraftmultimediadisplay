-- cinemaconfig.lua
--
-- Tiny shared settings file for the cinema scripts (cinema_sign.lua
-- and jellyfin_client.lua), so both can read/write the same values
-- (Jellyfin server, Ersatz channel, etc.) without clobbering each
-- other's fields. Never stores your Jellyfin password.

local CONFIG_FILE = "cinema.cfg"

local M = {}

function M.load()
    if fs.exists(CONFIG_FILE) then
        local f = fs.open(CONFIG_FILE, "r")
        local ok, data = pcall(textutils.unserialize, f.readAll())
        f.close()
        if ok and type(data) == "table" then return data end
    end
    return {}
end

--- Merge `fields` into the stored config and save. Returns the merged table.
function M.save(fields)
    local current = M.load()
    for k, v in pairs(fields) do
        current[k] = v
    end
    local f = fs.open(CONFIG_FILE, "w")
    f.write(textutils.serialize(current))
    f.close()
    return current
end

return M
