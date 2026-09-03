-- displayboard.lua
--
-- Wrapper for a CC:C Bridge "Source Block" peripheral, linked (via
-- Create's Display Link network - same frequency system as Create's
-- own Display Boards) to a physical Create Display Board.
--
-- The Source Block exposes a cut-down `term`-style API: write,
-- setCursorPos, getCursorPos, getSize, clear, clearLine.
-- (https://github.com/tweaked-programs/cccbridge/wiki/Source-Block)

local DisplayBoard = {}
DisplayBoard.__index = DisplayBoard

local function looksLikeSource(p)
    return type(p) == "table" and p.write and p.setCursorPos and p.getSize and p.clear
end

--- Connect to a Source Block.
-- @param nameOrSide (optional) a specific peripheral name or side.
--                    If omitted, every connected peripheral is scanned.
function DisplayBoard.find(nameOrSide)
    local raw

    if nameOrSide then
        raw = peripheral.wrap(nameOrSide)
        if not raw then
            error(("No peripheral found at '%s'"):format(nameOrSide), 2)
        end
        if not looksLikeSource(raw) then
            error(("Peripheral at '%s' doesn't look like a CC:C Bridge Source Block"):format(nameOrSide), 2)
        end
    else
        for _, name in ipairs(peripheral.getNames()) do
            local p = peripheral.wrap(name)
            if looksLikeSource(p) then
                raw = p
                break
            end
        end
        if not raw then
            error("No Source Block found. Place one near the computer and link it (Display Link frequency) to your Display Board.", 2)
        end
    end

    return setmetatable({ p = raw }, DisplayBoard)
end

--- Returns width, height of the linked board, in character cells.
function DisplayBoard:getSize()
    return self.p.getSize()
end

function DisplayBoard:clear()
    self.p.clear()
end

--- Write one line of text at a given row (1-indexed), truncated to
--- the board's width, clearing whatever was there before.
function DisplayBoard:setLine(row, text)
    local w = self.p.getSize()
    text = text or ""
    if #text > w then text = text:sub(1, w) end
    self.p.setCursorPos(1, row)
    self.p.clearLine()
    self.p.write(text)
end

--- Replace the whole board with a list of lines (top to bottom).
--- Lines beyond the board's height are dropped; unused rows are cleared.
function DisplayBoard:setLines(lines)
    local w, h = self.p.getSize()
    for row = 1, h do
        self:setLine(row, lines[row] or "")
    end
end

--- Returns the `width`-wide window of `text` starting at character
--- `offset` (0-indexed), wrapping around with a blank `gap` between
--- repeats - a simple horizontal marquee. If `text` already fits
--- within `width`, it's returned unchanged.
function DisplayBoard.scrollWindow(text, width, offset, gap)
    if #text <= width then return text end
    gap = gap or 3
    local padded = text .. string.rep(" ", gap)
    local total = #padded
    offset = offset % total
    if offset + width <= total then
        return padded:sub(offset + 1, offset + width)
    end
    return padded:sub(offset + 1) .. padded:sub(1, width - (total - offset))
end

--- Like setLines, but any line too long for the board scrolls
--- (marquee-style) instead of being cut off; lines that already fit
--- are shown statically. `offsets` is a table you keep between calls
--- (e.g. {} to start) - this mutates it, advancing each long line by
--- one character per call. Reset it (offsets = {}) whenever `lines`
--- changes to restart the scroll from the beginning.
function DisplayBoard:setLinesScrolling(lines, offsets, gap)
    local w, h = self.p.getSize()
    for row = 1, h do
        local text = lines[row] or ""
        if #text > w then
            offsets[row] = offsets[row] or 0
            self:setLine(row, DisplayBoard.scrollWindow(text, w, offsets[row], gap))
            offsets[row] = offsets[row] + 1
        else
            self:setLine(row, text)
        end
    end
end

return DisplayBoard
