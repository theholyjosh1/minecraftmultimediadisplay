-- menu.lua
--
-- A scrollable, paginated list picker for CC:Tweaked terminals.
-- Long entries wrap onto extra lines instead of being cut off, and
-- when there are more entries than fit on screen you get a small
-- text scrollbar plus n/p paging - so a 20-episode list is fully
-- reachable rather than just showing whatever fit before the
-- terminal scrolled.

local Menu = {}

-- Word-wraps `text` to `width` columns, breaking on spaces where
-- possible (falling back to a hard break for single very long words).
local function wrapText(text, width)
    local lines = {}
    local remaining = text
    while #remaining > width do
        local breakAt = width
        local spacePos = remaining:sub(1, width):find(" [^ ]*$")
        if spacePos and spacePos > 1 then breakAt = spacePos - 1 end
        lines[#lines + 1] = remaining:sub(1, breakAt)
        remaining = remaining:sub(breakAt + 1):gsub("^%s+", "")
    end
    lines[#lines + 1] = remaining
    return lines
end

--- Show a numbered, scrollable list and let the user pick one.
-- @param items list of plain display strings (e.g. episode titles)
-- @param headerLines (optional) list of strings shown above the list
-- @return the 1-based index into `items` that was chosen, or nil if cancelled
function Menu.pagedChoice(items, headerLines)
    headerLines = headerLines or {}
    local w, h = term.getSize()
    local textWidth = math.max(5, w - 2) -- leave a column for the scrollbar
    local headerRows = #headerLines
    local availableRows = math.max(1, h - headerRows - 1) -- last row is the prompt

    -- Wrap every item into one or more display lines, remembering
    -- which item each display line belongs to.
    local displayLines = {}
    for i, text in ipairs(items) do
        local wrapped = wrapText(("%d) %s"):format(i, text), textWidth)
        for _, line in ipairs(wrapped) do
            displayLines[#displayLines + 1] = line
        end
    end

    local totalLines = #displayLines
    local scrollOffset = 0

    while true do
        term.clear()
        term.setCursorPos(1, 1)
        for _, hl in ipairs(headerLines) do print(hl) end

        local visibleEnd = math.min(scrollOffset + availableRows, totalLines)
        for row = scrollOffset + 1, visibleEnd do
            term.setCursorPos(1, headerRows + (row - scrollOffset))
            term.write(displayLines[row])
        end

        -- Simple text scrollbar down the right edge, only when needed.
        if totalLines > availableRows then
            local thumbSize = math.max(1, math.floor(availableRows * availableRows / totalLines))
            local track = math.max(1, availableRows - thumbSize)
            local thumbStart = math.floor((scrollOffset / math.max(1, totalLines - availableRows)) * track)
            for row = 0, availableRows - 1 do
                term.setCursorPos(w, headerRows + 1 + row)
                if row >= thumbStart and row < thumbStart + thumbSize then
                    term.write("#")
                else
                    term.write("|")
                end
            end
        end

        term.setCursorPos(1, h)
        term.clearLine()
        local hint = (totalLines > availableRows) and " (n=next p=prev)" or ""
        write("Number to select, 0 cancel" .. hint .. ": ")
        local input = read()

        if input == "n" and scrollOffset + availableRows < totalLines then
            scrollOffset = scrollOffset + availableRows
        elseif input == "p" and scrollOffset > 0 then
            scrollOffset = math.max(0, scrollOffset - availableRows)
        else
            local choice = tonumber(input)
            if choice == 0 then return nil end
            if choice and choice >= 1 and choice <= #items then return choice end
        end
    end
end

return Menu
