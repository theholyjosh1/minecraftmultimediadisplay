-- ersatz.lua
--
-- Minimal ErsatzTV client for CC:Tweaked: resolves a channel's direct
-- stream URL, and reads its own XMLTV guide to figure out what's
-- "now showing" and "up next". No external XML library - just enough
-- hand-rolled parsing for ErsatzTV's own output.
--
-- ErsatzTV exposes, per instance:
--   {base}/iptv/channel/{number}.m3u   - direct stream for one channel
--   {base}/iptv/channels.m3u           - playlist of all channels
--   {base}/iptv/xmltv.xml              - EPG for every channel

local Ersatz = {}
Ersatz.__index = Ersatz

local function httpGet(url)
    local h, err = http.get(url)
    if not h then return nil, err or "request failed" end
    local body = h.readAll()
    h.close()
    return body
end

local function xmlUnescape(s)
    return (s:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"')
             :gsub("&#39;", "'"):gsub("&apos;", "'"):gsub("&amp;", "&"))
end

-- Days since 1970-01-01 for a civil (Gregorian) date.
-- (Howard Hinnant's well-known days_from_civil algorithm, using
-- math.floor instead of // since CC:Tweaked's Lua predates that operator.)
local function daysFromCivil(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = (y >= 0) and math.floor(y / 400) or math.floor((y - 399) / 400)
    local yoe = y - era * 400
    local mAdj = m + ((m > 2) and -3 or 9)
    local doy = math.floor((153 * mAdj + 2) / 5) + d - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

-- Parses XMLTV's "YYYYMMDDHHMMSS +HHMM" timestamps into a unix epoch (seconds).
local function parseXmltvTime(s)
    if not s then return nil end
    local datePart, offPart = s:match("^%s*(%d+)%s*(.-)%s*$")
    if not datePart or #datePart < 14 then return nil end
    local y, mo, d, h, mi, se = datePart:match("(%d%d%d%d)(%d%d)(%d%d)(%d%d)(%d%d)(%d%d)")
    if not y then return nil end
    y, mo, d, h, mi, se = tonumber(y), tonumber(mo), tonumber(d), tonumber(h), tonumber(mi), tonumber(se)

    local offsetSeconds = 0
    local sign, oh, om = offPart:match("([%+%-])(%d%d)(%d%d)")
    if sign then
        offsetSeconds = (tonumber(oh) * 3600 + tonumber(om) * 60) * (sign == "-" and -1 or 1)
    end

    return daysFromCivil(y, mo, d) * 86400 + h * 3600 + mi * 60 + se - offsetSeconds
end

--- Create an EPG/stream client for one ErsatzTV channel.
-- @param baseUrl e.g. "https://tv.riabhaigh.co.uk"
-- @param channelNumber the channel number as shown in ErsatzTV, e.g. 3
function Ersatz.new(baseUrl, channelNumber)
    baseUrl = (baseUrl or ""):gsub("/+$", "")
    return setmetatable({
        base = baseUrl,
        channelNumber = tostring(channelNumber),
        channelId = nil,
    }, Ersatz)
end

--- The direct stream URL for this channel - what you hand to WaterFrames.
function Ersatz:streamUrl()
    return ("%s/iptv/channel/%s.ts"):format(self.base, self.channelNumber)
end

-- Looks up the XMLTV channel id (tvg-id) for our channel number from
-- the channel playlist. Cached after the first successful lookup.
function Ersatz:resolveChannelId()
    if self.channelId then return self.channelId end

    local body, err = httpGet(self.base .. "/iptv/channels.m3u")
    if not body then return nil, "couldn't fetch channel list: " .. tostring(err) end

    for line in body:gmatch("[^\r\n]+") do
        if line:find("#EXTINF", 1, true) then
            local chno = line:match('tvg%-chno="(.-)"') or line:match('channel%-number="(.-)"')
            if chno == self.channelNumber then
                local id = line:match('tvg%-id="(.-)"')
                if id then
                    self.channelId = id
                    return id
                end
            end
        end
    end

    return nil, ("channel %s not found in channel list"):format(self.channelNumber)
end

--- Returns { now = {title=..., year=...}, next = {title=..., year=...} }
--- for this channel, or nil + an error message.
function Ersatz:nowAndNext()
    local channelId, idErr = self:resolveChannelId()
    if not channelId then return nil, idErr end

    local xml, err = httpGet(self.base .. "/iptv/xmltv.xml")
    if not xml then return nil, "couldn't fetch guide: " .. tostring(err) end

    local nowSec = math.floor(os.epoch("utc") / 1000)

    local programmes = {}
    for attrs, inner in xml:gmatch("<programme%s+(.-)>(.-)</programme>") do
        local chan = attrs:match('channel="(.-)"')
        if chan == channelId then
            local startSec = parseXmltvTime(attrs:match('start="(.-)"'))
            local stopSec = parseXmltvTime(attrs:match('stop="(.-)"'))
            local title = inner:match("<title[^>]*>(.-)</title>")
            local date = inner:match("<date>(.-)</date>")
            local year = date and date:match("(%d%d%d%d)")

            if startSec and stopSec and title then
                programmes[#programmes + 1] = {
                    start = startSec,
                    stop = stopSec,
                    title = xmlUnescape(title),
                    year = year,
                }
            end
        end
    end

    table.sort(programmes, function(a, b) return a.start < b.start end)

    local now, nxt
    for _, p in ipairs(programmes) do
        if p.start <= nowSec and nowSec < p.stop then
            now = p
        elseif p.start > nowSec and not nxt then
            nxt = p
        end
    end

    if not now and not nxt then
        return nil, "no schedule data found for this channel (check the XMLTV guide has generated listings)"
    end

    return { now = now, next = nxt }
end

--- Format a programme entry as e.g. "APOCALYPSE NOW (1978)".
function Ersatz.formatTitle(programme)
    if not programme then return nil end
    if programme.year then
        return ("%s (%s)"):format(programme.title, programme.year)
    end
    return programme.title
end

return Ersatz
