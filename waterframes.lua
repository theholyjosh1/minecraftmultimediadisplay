-- waterframes.lua
--
-- Thin wrapper around the peripheral exposed by the
-- "WaterFrames Computercraft Compat" mod:
--   https://modrinth.com/mod/waterframes-computercraft-compat
--
-- Exposed peripheral methods (per the mod's own docs):
--   getUrl / setUrl          - the video URL currently loaded
--   getTick / setTick        - current playback position (in ticks)
--   getMaxTick                - length of the loaded media, in ticks
--   pause / play / stop
--   getPaused
--   getVolume / setVolume     - 0-100
--   getTransparency / setTransparency -- 0-255
--   loop(bool)                 - whether the media repeats
--
-- This wrapper doesn't hardcode a peripheral "type" string (that can
-- vary a bit between mod/game versions) - instead it scans connected
-- peripherals for the expected methods, so it should keep working
-- even if the type name changes.

local WaterFrame = {}
WaterFrame.__index = WaterFrame

local function looksLikeFrame(p)
    return type(p) == "table" and p.getUrl and p.setUrl and p.play and p.stop
end

--- Connect to a WaterFrames display.
-- @param nameOrSide (optional) a specific peripheral name or side
--                    (e.g. "top", "left", "waterframes:frame_0").
--                    If omitted, every connected peripheral is scanned
--                    for one that looks like a WaterFrames display.
function WaterFrame.find(nameOrSide)
    local raw

    if nameOrSide then
        raw = peripheral.wrap(nameOrSide)
        if not raw then
            error(("No peripheral found at '%s'"):format(nameOrSide), 2)
        end
        if not looksLikeFrame(raw) then
            error(("Peripheral at '%s' doesn't expose the WaterFrames API"):format(nameOrSide), 2)
        end
    else
        for _, name in ipairs(peripheral.getNames()) do
            local p = peripheral.wrap(name)
            if looksLikeFrame(p) then
                raw = p
                break
            end
        end
        if not raw then
            error("No WaterFrames display found. Place a computer next to (or wire a modem to) a frame/projector, or pass its side/name to WaterFrame.find().", 2)
        end
    end

    return setmetatable({ p = raw }, WaterFrame)
end

function WaterFrame:setUrl(url) self.p.setUrl(url) end
function WaterFrame:getUrl() return self.p.getUrl() end

function WaterFrame:play() self.p.play() end
function WaterFrame:stop() self.p.stop() end
function WaterFrame:pause() self.p.pause() end
function WaterFrame:isPaused() return self.p.getPaused() end

function WaterFrame:setVolume(v)
    v = math.max(0, math.min(100, v))
    self.p.setVolume(v)
    return v
end
function WaterFrame:getVolume() return self.p.getVolume() end

function WaterFrame:setTransparency(v)
    v = math.max(0, math.min(255, v))
    self.p.setTransparency(v)
    return v
end
function WaterFrame:getTransparency() return self.p.getTransparency() end

function WaterFrame:setLoop(loop) self.p.loop(loop) end

function WaterFrame:getTick() return self.p.getTick() end
function WaterFrame:getMaxTick() return self.p.getMaxTick() end
function WaterFrame:setTick(t) self.p.setTick(t) end

--- Convenience: load a URL and start playing it in one call.
-- opts = { loop = bool, volume = 0-100 }
function WaterFrame:playUrl(url, opts)
    opts = opts or {}
    self.p.setUrl(url)
    if opts.loop ~= nil then self.p.loop(opts.loop) end
    if opts.volume ~= nil then self:setVolume(opts.volume) end
    self.p.play()
end

return WaterFrame
