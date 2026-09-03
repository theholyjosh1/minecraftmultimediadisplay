-- custom_channel.lua
--
-- Play an arbitrary custom live stream (e.g. Sky News, or any other
-- IPTV link) on the projector, overriding the Ersatz channel. While
-- playing, cinema_sign.lua shows just that channel's name on the
-- display board. Remembers channels you've used before under
-- cinema.cfg so you don't have to retype the URL each time.

local WaterFrame = require("waterframes")
local Ersatz = require("ersatz")
local cfg = require("cinemaconfig")

local OVERRIDE_FILE = "cinema_override.txt"

local function ask(label, default)
    write(label .. (default and (" [" .. default .. "]") or "") .. ": ")
    local input = read()
    if input == "" and default then return default end
    return input
end

local function clear()
    term.clear()
    term.setCursorPos(1, 1)
end

local function setOverride(name)
    local f = fs.open(OVERRIDE_FILE, "w")
    f.write(textutils.serialize({ source = "custom", name = name }))
    f.close()
end

local function clearOverride()
    if fs.exists(OVERRIDE_FILE) then fs.delete(OVERRIDE_FILE) end
end

-- ============ Setup ============

local settings = cfg.load()
settings.customChannels = settings.customChannels or {}

clear()
print("== Custom Stream Player ==")
print()

settings.ersatzBase = ask("Ersatz base URL (for 'Return to Channel')", settings.ersatzBase)
settings.ersatzChannel = ask("Ersatz channel number", settings.ersatzChannel)
cfg.save({ ersatzBase = settings.ersatzBase, ersatzChannel = settings.ersatzChannel })

local ersatz = Ersatz.new(settings.ersatzBase, settings.ersatzChannel)

print("Looking for the projector (WaterFrames display)...")
local okFrame, frameOrErr = pcall(WaterFrame.find)
if not okFrame then
    print("Could not find a WaterFrames peripheral:")
    print(tostring(frameOrErr))
    return
end
local frame = frameOrErr
print("Connected to display.")
sleep(1)

local function playChannel(name, url)
    print("Loading: " .. name)
    setOverride(name)
    frame:playUrl(url, { loop = true, volume = frame:getVolume() or 80 })
end

-- Shows saved channels and lets you pick one, or bail out to add a new one.
local function chooseSavedChannel()
    if #settings.customChannels == 0 then return nil end
    for i, c in ipairs(settings.customChannels) do
        print(("%d) %s"):format(i, c.name))
    end
    write("Select a number (0 for a new channel): ")
    local choice = tonumber(read())
    if not choice or choice < 1 or choice > #settings.customChannels then return nil end
    return settings.customChannels[choice]
end

-- ============ Main loop ============

while true do
    clear()
    print("== Custom Stream Player ==")
    print("1) Play a channel")
    print("2) Player controls")
    print("3) Return to Ersatz channel")
    print("4) Quit")
    write("> ")
    local action = read()

    if action == "1" then
        clear()
        print("== Saved Channels ==")
        local chosen = chooseSavedChannel()
        if chosen then
            playChannel(chosen.name, chosen.url)
            sleep(2)
        else
            local name = ask("Channel name (e.g. Sky News)")
            local url = ask("Stream URL")
            if name ~= "" and url ~= "" then
                table.insert(settings.customChannels, { name = name, url = url })
                cfg.save({ customChannels = settings.customChannels })
                playChannel(name, url)
                sleep(2)
            end
        end

    elseif action == "2" then
        clear()
        print("== Player Controls ==")
        print("p) Play/Resume   s) Stop        x) Pause/Unpause")
        print("+) Vol up        -) Vol down    b) Back")
        while true do
            write("> ")
            local c = read()
            if c == "p" then
                frame:play()
            elseif c == "s" then
                frame:stop()
            elseif c == "x" then
                if frame:isPaused() then frame:play() else frame:pause() end
            elseif c == "+" then
                print("Volume: " .. frame:setVolume((frame:getVolume() or 0) + 10))
            elseif c == "-" then
                print("Volume: " .. frame:setVolume((frame:getVolume() or 0) - 10))
            elseif c == "b" then
                break
            end
        end

    elseif action == "3" then
        clearOverride()
        print("Returning to channel " .. settings.ersatzChannel .. "...")
        frame:playUrl(ersatz:streamUrl(), { loop = true })
        sleep(2)

    elseif action == "4" then
        break
    end
end

print("Goodbye!")
