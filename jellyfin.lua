-- jellyfin.lua
--
-- Minimal Jellyfin REST client for CC:Tweaked, using the built-in `http` API.
-- Supports: username/password login, listing/searching library items,
-- and building a direct-play stream URL you can hand to WaterFrames.

local Jellyfin = {}
Jellyfin.__index = Jellyfin

local DEVICE_NAME = "CC-Tweaked"
local CLIENT_NAME = "CCJellyfinClient"
local CLIENT_VER  = "1.0"

local function deviceId()
    local ok, id = pcall(os.getComputerID)
    return "cc-" .. (ok and id or "unknown")
end

local function authHeader(token)
    local h = ('MediaBrowser Client="%s", Device="%s", DeviceId="%s", Version="%s"')
        :format(CLIENT_NAME, DEVICE_NAME, deviceId(), CLIENT_VER)
    if token then
        h = h .. (', Token="%s"'):format(token)
    end
    return h
end

-- Does a GET or POST and returns (decodedJsonOrNil, errString, httpStatus)
local function request(method, url, body, headers)
    headers = headers or {}
    local handle, err

    if method == "GET" then
        handle, err = http.get(url, headers)
    else
        local payload = body and textutils.serializeJSON(body) or "{}"
        headers["Content-Type"] = "application/json"
        handle, err = http.post(url, payload, headers)
    end

    if not handle then
        return nil, (err or "connection failed"), nil
    end

    local status = handle.getResponseCode and select(1, handle.getResponseCode()) or nil
    local text = handle.readAll()
    handle.close()

    local data = nil
    if text and #text > 0 then
        local ok, decoded = pcall(textutils.unserializeJSON, text)
        if ok then data = decoded end
    end

    return data, nil, status
end

--- Create a client for a given server, e.g. "http://192.168.1.20:8096"
function Jellyfin.new(serverUrl)
    serverUrl = (serverUrl or ""):gsub("/+$", "")
    return setmetatable({ server = serverUrl, token = nil, userId = nil }, Jellyfin)
end

--- Log in with a username/password. Returns true, or false + error message.
function Jellyfin:login(username, password)
    local url = self.server .. "/Users/AuthenticateByName"
    local body = { Username = username, Pw = password or "" }
    local headers = { ["X-Emby-Authorization"] = authHeader(nil) }

    local data, err, status = request("POST", url, body, headers)
    if not data or not data.AccessToken then
        return false, ("login failed (%s)"):format(err or ("HTTP " .. tostring(status)) or "unknown error")
    end

    self.token = data.AccessToken
    self.userId = data.User and data.User.Id
    return true
end

function Jellyfin:authHeaders()
    return {
        ["X-Emby-Authorization"] = authHeader(self.token),
        ["X-Emby-Token"] = self.token,
    }
end

--- List items in the library.
-- opts = { itemType = "Movie"|"Series"|..., parentId = "...", searchTerm = "..." }
function Jellyfin:listItems(opts)
    opts = opts or {}
    local params = { "Recursive=true", "SortBy=SortName", "SortOrder=Ascending" }

    if opts.itemType then params[#params + 1] = "IncludeItemTypes=" .. opts.itemType end
    if opts.parentId then params[#params + 1] = "ParentId=" .. opts.parentId end
    if opts.searchTerm and #opts.searchTerm > 0 then
        params[#params + 1] = "SearchTerm=" .. textutils.urlEncode(opts.searchTerm)
    end
    params[#params + 1] = "Fields=ProductionYear"

    local url = ("%s/Users/%s/Items?%s"):format(self.server, self.userId, table.concat(params, "&"))
    local data, err, status = request("GET", url, nil, self:authHeaders())
    if not data then
        return nil, ("failed to list items (%s)"):format(err or ("HTTP " .. tostring(status)) or "unknown error")
    end
    return data.Items or {}
end

--- List the seasons of a series.
function Jellyfin:listSeasons(seriesId)
    local url = ("%s/Shows/%s/Seasons?userId=%s"):format(self.server, seriesId, self.userId)
    local data, err, status = request("GET", url, nil, self:authHeaders())
    if not data then
        return nil, ("failed to list seasons (%s)"):format(err or ("HTTP " .. tostring(status)) or "unknown error")
    end
    return data.Items or {}
end

--- List the episodes of a series, optionally filtered to one season.
function Jellyfin:listEpisodes(seriesId, seasonId)
    local params = { "userId=" .. self.userId }
    if seasonId then params[#params + 1] = "seasonId=" .. seasonId end

    local url = ("%s/Shows/%s/Episodes?%s"):format(self.server, seriesId, table.concat(params, "&"))
    local data, err, status = request("GET", url, nil, self:authHeaders())
    if not data then
        return nil, ("failed to list episodes (%s)"):format(err or ("HTTP " .. tostring(status)) or "unknown error")
    end
    return data.Items or {}
end

--- Build a direct-play stream URL for an item. WaterFrames can load
--- this straight into setUrl()/playUrl(). No transcoding is requested,
--- so playback quality depends on WaterFrames' own media backend
--- being able to decode the source file's codec.
function Jellyfin:streamUrl(itemId)
    return ("%s/Videos/%s/stream?static=true&api_key=%s"):format(self.server, itemId, self.token)
end

return Jellyfin
