-- cinema_sign.lua
--
-- Runs the cinema: loads your ErsatzTV channel onto the WaterFrames
-- projector and loops it, and keeps a Create Display Board (via a
-- CC:C Bridge Source Block) showing one of three things, depending
-- on what's actually playing:
--   - Ersatz channel (default): "NOW SHOWING / UP NEXT" from its EPG.
--   - A movie/episode played manually via jellyfin_client.lua:
--     "NOW SHOWING: <title>" / "FROM JELLYFIN".
--   - A custom stream played via custom_channel.lua (e.g. a live news
--     channel): just the channel's name, e.g. "SKY NEWS".
--
-- jellyfin_client.lua and custom_channel.lua signal which of the
-- latter two is active by writing cinema_override.txt; this reverts
-- to the normal EPG view once you choose "Return to Channel" in
-- either of those.
--
-- Intended to run continuously - e.g. in its own multishell tab, or
-- set as the computer's startup program - alongside the other two
-- scripts being run occasionally for manual playback.

local WaterFrame = require("waterframes")
local DisplayBoard = require("displayboard")
local Ersatz = require("ersatz")
local cfg = require("cinemaconfig")

local OVERRIDE_FILE = "cinema_override.txt"
local POLL_SECONDS = 15    -- how often to refresh the EPG / recheck for manual override
local SCROLL_SECONDS = 0.75 -- how often to step the marquee scroll for long titles
local REFRESH_EVERY_N_TICKS = math.max(1, math.floor(POLL_SECONDS / SCROLL_SECONDS))

local function ask(label, default)
    write(label .. (default and (" [" .. default .. "]") or "") .. ": ")
    local input = read()
    if input == "" and default then return default end
    return input
end

local function readOverride()
    if not fs.exists(OVERRIDE_FILE) then return nil end
    local f = fs.open(OVERRIDE_FILE, "r")
    local ok, data = pcall(textutils.unserialize, f.readAll())
    f.close()
    if ok and type(data) == "table" then return data end
    return nil
end

-- ============ Setup ============

local settings = cfg.load()

print("== Cinema Sign Setup ==")
settings.ersatzBase = ask("Ersatz base URL (e.g. https://tv.riabhaigh.co.uk)", settings.ersatzBase)
settings.ersatzChannel = ask("Ersatz channel number", settings.ersatzChannel)
cfg.save({ ersatzBase = settings.ersatzBase, ersatzChannel = settings.ersatzChannel })

local ersatz = Ersatz.new(settings.ersatzBase, settings.ersatzChannel)

print("Finding the projector (WaterFrames display)...")
local okFrame, frame = pcall(WaterFrame.find)
if not okFrame then
    print("Could not find a WaterFrames display: " .. tostring(frame))
    return
end

print("Finding the display board (CC:C Bridge Source Block)...")
local okBoard, board = pcall(DisplayBoard.find)
if not okBoard then
    print("Could not find a Source Block: " .. tostring(board))
    return
end

print(("Loading channel %s onto the projector..."):format(settings.ersatzChannel))
frame:playUrl(ersatz:streamUrl(), { loop = true })

print("Cinema sign running. Ctrl+T to stop this program.")
print()

-- ============ Main loop ============
--
-- `lines` is recomputed on the slow (POLL_SECONDS) cadence - it needs
-- network calls to Ersatz/reads the override file. Rendering to the
-- board happens on the fast (SCROLL_SECONDS) cadence, using whatever
-- `lines` currently holds, so long titles scroll smoothly in between
-- data refreshes.

local function computeLines()
    local override = readOverride()

    if override and override.source == "custom" and override.name then
        return { override.name }
    end

    if override and override.title and (override.source == "jellyfin" or not override.source) then
        return {
            "NOW SHOWING:",
            override.title,
            "",
            "FROM JELLYFIN",
        }
    end

    local info, err = ersatz:nowAndNext()
    if info then
        local lines = {
            "NOW SHOWING:",
            info.now and Ersatz.formatTitle(info.now) or "(no data)",
        }
        if info.next then
            lines[#lines + 1] = "UP NEXT:"
            lines[#lines + 1] = Ersatz.formatTitle(info.next)
        end
        return lines
    end

    return { "NOW SHOWING:", "-- guide unavailable --" }
end

local lines = computeLines()
local scrollOffsets = {}
local tick = 0

while true do
    board:setLinesScrolling(lines, scrollOffsets)

    sleep(SCROLL_SECONDS)
    tick = tick + 1

    if tick >= REFRESH_EVERY_N_TICKS then
        tick = 0
        lines = computeLines()
        scrollOffsets = {} -- restart any scrolling titles from the beginning
    end
end
