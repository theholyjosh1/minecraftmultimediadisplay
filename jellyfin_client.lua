-- jellyfin_client.lua
--
-- Backup / manual Jellyfin player for the cinema. Browse or search
-- your Jellyfin library and play something directly on the projector
-- (a WaterFrames display), overriding whatever Ersatz channel is
-- normally looping. If cinema_sign.lua is running, it'll pick this up
-- and switch the display board to show what's playing "FROM JELLYFIN"
-- until you choose "Return to Channel" here.
--
-- Put this file alongside waterframes.lua, jellyfin.lua, ersatz.lua
-- and cinemaconfig.lua on the same computer, then run it.

local WaterFrame = require("waterframes")
local Jellyfin = require("jellyfin")
local Ersatz = require("ersatz")
local cfg = require("cinemaconfig")
local Menu = require("menu")

local OVERRIDE_FILE = "cinema_override.txt"

local function ask(label, default, mask)
    write(label .. (default and (" [" .. default .. "]") or "") .. ": ")
    local input = read(mask)
    if input == "" and default then return default end
    return input
end

local function clear()
    term.clear()
    term.setCursorPos(1, 1)
end

--- Show a scrollable, wrapping picker built from `items`, labelled by
--- `titleFn`, and return the chosen item (or nil if cancelled).
local function chooseFromList(items, titleFn, headerLines)
    local labels = {}
    for i, item in ipairs(items) do labels[i] = titleFn(item) end
    local choice = Menu.pagedChoice(labels, headerLines)
    if not choice then return nil end
    return items[choice]
end

local function setOverride(title)
    local f = fs.open(OVERRIDE_FILE, "w")
    f.write(textutils.serialize({ source = "jellyfin", title = title }))
    f.close()
end

local function clearOverride()
    if fs.exists(OVERRIDE_FILE) then fs.delete(OVERRIDE_FILE) end
end

local function movieTitle(item)
    if item.ProductionYear then
        return ("%s (%s)"):format(item.Name, item.ProductionYear)
    end
    return item.Name
end

local function episodeTitle(show, episode)
    return show.Name .. " - " .. (episode.Name or "Episode")
end

-- ============ Setup ============

local settings = cfg.load()

clear()
print("== CC Jellyfin Client for WaterFrames ==")
print()

settings.jellyfinServer = ask("Jellyfin server URL", settings.jellyfinServer)
settings.jellyfinUsername = ask("Username", settings.jellyfinUsername)
local password = ask("Password", nil, "*")
settings.ersatzBase = ask("Ersatz base URL (for 'Return to Channel')", settings.ersatzBase)
settings.ersatzChannel = ask("Ersatz channel number", settings.ersatzChannel)

local jf = Jellyfin.new(settings.jellyfinServer)
print("Logging in...")
local ok, err = jf:login(settings.jellyfinUsername, password)
if not ok then
    print("Login failed: " .. tostring(err))
    return
end
print("Logged in as " .. settings.jellyfinUsername)

cfg.save({
    jellyfinServer = settings.jellyfinServer,
    jellyfinUsername = settings.jellyfinUsername,
    ersatzBase = settings.ersatzBase,
    ersatzChannel = settings.ersatzChannel,
})

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

-- ============ Main loop ============

while true do
    clear()
    print("== Jellyfin Library ==")
    print("1) Browse Movies")
    print("2) Search")
    print("3) Browse TV Shows")
    print("4) Player controls")
    print("5) Return to Channel")
    print("6) Quit")
    write("> ")
    local action = read()

    if action == "1" or action == "2" then
        local opts = { itemType = "Movie" }
        if action == "2" then
            write("Search term: ")
            opts.searchTerm = read()
            opts.itemType = nil
        end

        local items, listErr = jf:listItems(opts)
        if not items then
            print("Error: " .. tostring(listErr))
            sleep(2)
        elseif #items == 0 then
            print("No results.")
            sleep(1)
        else
            local chosen = chooseFromList(items, function(it) return movieTitle(it) end, { "== Results ==" })
            if chosen then
                local url = jf:streamUrl(chosen.Id)
                local title = movieTitle(chosen)
                print("Loading: " .. title)
                setOverride(title)
                frame:playUrl(url, { loop = false, volume = frame:getVolume() or 80 })
                sleep(2)
            end
        end

    elseif action == "3" then
        local series, seriesErr = jf:listItems({ itemType = "Series" })
        if not series then
            print("Error: " .. tostring(seriesErr))
            sleep(2)
        elseif #series == 0 then
            print("No TV shows found.")
            sleep(1)
        else
            local show = chooseFromList(series, function(it) return it.Name end, { "== TV Shows ==" })

            if show then
                local seasons, seasonErr = jf:listSeasons(show.Id)
                if not seasons then
                    print("Error: " .. tostring(seasonErr))
                    sleep(2)
                elseif #seasons == 0 then
                    print("No seasons found for " .. show.Name)
                    sleep(1)
                else
                    local season = chooseFromList(seasons, function(it) return it.Name end,
                        { "== " .. show.Name .. " - Seasons ==" })

                    if season then
                        local episodes, epErr = jf:listEpisodes(show.Id, season.Id)
                        if not episodes then
                            print("Error: " .. tostring(epErr))
                            sleep(2)
                        elseif #episodes == 0 then
                            print("No episodes found.")
                            sleep(1)
                        else
                            local episode = chooseFromList(episodes, function(it)
                                local num = it.IndexNumber and ("E%02d - "):format(it.IndexNumber) or ""
                                return num .. (it.Name or "Untitled")
                            end, { "== " .. show.Name .. " - " .. season.Name .. " ==" })

                            if episode then
                                local url = jf:streamUrl(episode.Id)
                                local title = episodeTitle(show, episode)
                                print("Loading: " .. title)
                                setOverride(title)
                                frame:playUrl(url, { loop = false, volume = frame:getVolume() or 80 })
                                sleep(2)
                            end
                        end
                    end
                end
            end
        end

    elseif action == "4" then
        clear()
        print("== Player Controls ==")
        print("p) Play/Resume   s) Stop        x) Pause/Unpause")
        print("+) Vol up        -) Vol down    l) Toggle loop")
        print("b) Back")
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
            elseif c == "l" then
                frame:setLoop(true)
                print("Looping enabled.")
            elseif c == "b" then
                break
            end
        end

    elseif action == "5" then
        clearOverride()
        print("Returning to channel " .. settings.ersatzChannel .. "...")
        frame:playUrl(ersatz:streamUrl(), { loop = true })
        sleep(2)

    elseif action == "6" then
        break
    end
end

print("Goodbye!")
