local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local GestureRange = require("ui/gesturerange")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText = require("ui/rendertext")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")

local Screen = Device.screen
local DISPLAY_PINS_ON_GIVEN = true

-- Digits 10-16 display as A-G (10→A, 11→B, …)
local function digitToChar(d)
    return d <= 9 and tostring(d) or string.char(55 + d)
end

-- ---------------------------------------------------------------------------
-- Drawing helpers
-- ---------------------------------------------------------------------------

local function drawLine(bb, x, y, w, h, color)
    bb:paintRect(x, y, w, h, color)
end

local function drawDiagonalLine(bb, x, y, length, dx, dy, color, thickness)
    color = color or Blitbuffer.COLOR_BLACK
    thickness = thickness or 1
    length = math.max(0, length)
    for step = 0, length do
        local px = math.floor(x + dx * step)
        local py = math.floor(y + dy * step)
        bb:paintRect(px, py, thickness, thickness, color)
    end
end

-- ---------------------------------------------------------------------------
-- SudokuBoardWidget — renders the N×N grid
-- ---------------------------------------------------------------------------

local SudokuBoardWidget = InputContainer:extend{
    board = nil,
}

function SudokuBoardWidget:init()
    local n        = self.board and self.board.n        or 9
    local box_rows = self.board and self.board.box_rows or 3
    local box_cols = self.board and self.board.box_cols or 3
    self.n        = n
    self.box_rows = box_rows
    self.box_cols = box_cols

    self.size = math.floor(math.min(Screen:getWidth(), Screen:getHeight()) * 0.82)
    self.dimen = Geom:new{ w = self.size, h = self.size }
    self.paint_rect = Geom:new{ x = 0, y = 0, w = self.size, h = self.size }
    self.number_face = Font:getFace("cfont", math.max(28, math.floor(self.size / 14)))
    self.note_face = Font:getFace("smallinfofont", math.max(16, math.floor(self.size / 28)))
    self.number_face_size = self.number_face.size
    self.number_cell_padding = 0
    self.note_face_size = self.note_face.size
    self.note_mini_padding = 0

    -- Note font: sized to fit in a mini cell (cell / box_cols × cell / box_rows)
    do
        local cell = self.size / n
        local mini_w = cell / box_cols
        local mini_h = cell / box_rows
        local mini   = math.min(mini_w, mini_h)
        local padding = math.max(1, math.floor(mini / 8))
        local safety  = math.max(1, math.floor(mini / 18))
        local max_w = math.max(1, math.floor(mini_w - 2 * padding - safety))
        local max_h = math.max(1, math.floor(mini_h - 2 * padding - safety))
        local size = self.note_face_size
        while size > 8 do
            local face = Font:getFace("smallinfofont", size)
            local m = RenderText:sizeUtf8Text(0, max_w, face, "8", true, false)
            local h = m.y_bottom - m.y_top
            if m.x <= max_w and h <= max_h then
                local final_size = math.max(8, size - 2)
                self.note_face = Font:getFace("smallinfofont", final_size)
                self.note_face_size = final_size
                self.note_mini_padding = padding
                break
            end
            size = size - 1
        end
    end

    -- Number font: sized to fit in a full cell
    do
        local cell = self.size / n
        local padding = math.max(2, math.floor(cell / 9))
        local safety  = math.max(1, math.floor(cell / 20))
        local max_w = math.max(1, math.floor(cell - 2 * padding - safety))
        local max_h = math.max(1, math.floor(cell - 2 * padding - safety))
        local size = self.number_face_size
        while size > 10 do
            local face = Font:getFace("cfont", size)
            local m = RenderText:sizeUtf8Text(0, max_w, face, "8", true, false)
            local h = m.y_bottom - m.y_top
            if m.x <= max_w and h <= max_h then
                local final_size = math.max(10, size - 4)
                self.number_face = Font:getFace("cfont", final_size)
                self.number_face_size = final_size
                self.number_cell_padding = padding
                break
            end
            size = size - 1
        end
    end

    self.ges_events = {
        Tap = {
            GestureRange:new{
                ges = "tap",
                range = function() return self.paint_rect end,
            }
        }
    }
end

function SudokuBoardWidget:getCellFromPoint(x, y)
    local rect = self.paint_rect
    local local_x = x - rect.x
    local local_y = y - rect.y
    if local_x < 0 or local_y < 0 or local_x > rect.w or local_y > rect.h then
        return nil
    end
    local cell_size = rect.w / self.n
    local col = math.floor(local_x / cell_size) + 1
    local row = math.floor(local_y / cell_size) + 1
    if row < 1 or row > self.n or col < 1 or col > self.n then
        return nil
    end
    return row, col
end

function SudokuBoardWidget:onTap(_, ges)
    if not (self.board and ges and ges.pos) then
        return false
    end
    local row, col = self:getCellFromPoint(ges.pos.x, ges.pos.y)
    if not row then
        return false
    end
    self.board:setSelection(row, col)
    if self.onSelectionChanged then
        self.onSelectionChanged(row, col)
    end
    self:refresh()
    return true
end

function SudokuBoardWidget:refresh()
    local rect = self.paint_rect
    UIManager:setDirty(self, function()
        return "ui", Geom:new{ x = rect.x, y = rect.y, w = rect.w, h = rect.h }
    end)
end

function SudokuBoardWidget:paintTo(bb, x, y)
    if not self.board then
        return
    end
    local n        = self.n
    local box_rows = self.box_rows
    local box_cols = self.box_cols
    self.paint_rect = Geom:new{ x = x, y = y, w = self.dimen.w, h = self.dimen.h }
    local cell = self.dimen.w / n
    bb:paintRect(x, y, self.dimen.w, self.dimen.h, Blitbuffer.COLOR_WHITE)
    local sel_row, sel_col = self.board:getSelection()
    local band_highlight = Blitbuffer.COLOR_GRAY_D
    local cell_highlight = Blitbuffer.COLOR_GRAY
    bb:paintRect(x + (sel_col - 1) * cell, y, cell, self.dimen.h, band_highlight)
    bb:paintRect(x, y + (sel_row - 1) * cell, self.dimen.w, cell, band_highlight)
    bb:paintRect(x + (sel_col - 1) * cell, y + (sel_row - 1) * cell, cell, cell, cell_highlight)

    -- Grid lines: thick at box boundaries, thin elsewhere
    for i = 0, n do
        local v_thick = (i % box_cols == 0) and Size.line.thick or Size.line.thin
        local h_thick = (i % box_rows == 0) and Size.line.thick or Size.line.thin
        drawLine(bb, x + math.floor(i * cell), y, v_thick, self.dimen.h, Blitbuffer.COLOR_BLACK)
        drawLine(bb, x, y + math.floor(i * cell), self.dimen.w, h_thick, Blitbuffer.COLOR_BLACK)
    end

    for row = 1, n do
        for col = 1, n do
            local value, is_given = self.board:getDisplayValue(row, col)
            if value then
                local cell_x = x + (col - 1) * cell
                local cell_y = y + (row - 1) * cell
                local color
                if self.board:isShowingSolution() and not is_given then
                    color = Blitbuffer.COLOR_GRAY_4
                elseif is_given then
                    color = Blitbuffer.COLOR_BLACK
                else
                    color = Blitbuffer.COLOR_GRAY_2
                end
                if self.board:isConflict(row, col) then
                    color = Blitbuffer.COLOR_RED
                end
                local text = digitToChar(value)
                local cell_padding = self.number_cell_padding or 0
                local cell_inner = math.max(1, math.floor(cell - 2 * cell_padding))
                local metrics = RenderText:sizeUtf8Text(0, cell_inner, self.number_face, text, true, false)
                local text_w = metrics.x
                local baseline = cell_y + cell_padding + math.floor((cell_inner + metrics.y_top - metrics.y_bottom) / 2)
                local text_x = cell_x + cell_padding + math.floor((cell_inner - text_w) / 2)
                RenderText:renderUtf8Text(bb, text_x, baseline, self.number_face, text, true, false, color)
                if is_given and DISPLAY_PINS_ON_GIVEN then
                    local dot = math.max(1, math.floor(cell / 18))
                    local padding = math.max(1, math.floor(cell / 20))
                    local dot_color = Blitbuffer.COLOR_GRAY_4
                    bb:paintRect(cell_x + padding, cell_y + padding, dot, dot, dot_color)
                    bb:paintRect(cell_x + cell - padding - dot, cell_y + padding, dot, dot, dot_color)
                    bb:paintRect(cell_x + padding, cell_y + cell - padding - dot, dot, dot, dot_color)
                    bb:paintRect(cell_x + cell - padding - dot, cell_y + cell - padding - dot, dot, dot, dot_color)
                elseif self.board:hasWrongMark(row, col) then
                    local padding = math.max(1, math.floor(cell / 12))
                    local diag_len = math.max(0, math.floor(cell - padding * 2))
                    local cross_thickness = math.max(2, math.floor(cell / 18))
                    drawDiagonalLine(bb, cell_x + padding, cell_y + padding, diag_len, 1, 1, Blitbuffer.COLOR_BLACK, cross_thickness)
                    drawDiagonalLine(bb, cell_x + padding, cell_y + cell - padding, diag_len, 1, -1, Blitbuffer.COLOR_BLACK, cross_thickness)
                end
            else
                local notes = self.board:getCellNotes(row, col)
                if notes then
                    -- Mini cells: box_cols per row, box_rows per column
                    local mini_w = cell / box_cols
                    local mini_h = cell / box_rows
                    local mini_padding = self.note_mini_padding or 0
                    local mini_inner_w = math.max(1, math.floor(mini_w - 2 * mini_padding))
                    local mini_inner_h = math.max(1, math.floor(mini_h - 2 * mini_padding))
                    for digit = 1, n do
                        if notes[digit] then
                            local mini_col = (digit - 1) % box_cols
                            local mini_row = math.floor((digit - 1) / box_cols)
                            local mini_x = x + (col - 1) * cell + mini_col * mini_w
                            local mini_y = y + (row - 1) * cell + mini_row * mini_h
                            local note_text = digitToChar(digit)
                            local note_metrics = RenderText:sizeUtf8Text(0, mini_inner_w, self.note_face, note_text, true, false)
                            local note_baseline = mini_y + mini_padding + math.floor((mini_inner_h + note_metrics.y_top - note_metrics.y_bottom) / 2)
                            local note_x = mini_x + mini_padding + math.floor((mini_inner_w - note_metrics.x) / 2)
                            RenderText:renderUtf8Text(bb, note_x, note_baseline, self.note_face, note_text, true, false, Blitbuffer.COLOR_GRAY_4)
                        end
                    end
                end
            end
        end
    end
end

return SudokuBoardWidget
