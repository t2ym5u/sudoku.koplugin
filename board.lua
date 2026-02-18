local _ = require("gettext")

local DEFAULT_DIFFICULTY = "medium"

-- ---------------------------------------------------------------------------
-- Grid / note utility functions
-- ---------------------------------------------------------------------------

local function emptyGrid()
    local grid = {}
    for r = 1, 9 do
        grid[r] = {}
        for c = 1, 9 do
            grid[r][c] = 0
        end
    end
    return grid
end

local function copyGrid(src)
    local grid = {}
    for r = 1, 9 do
        grid[r] = {}
        for c = 1, 9 do
            grid[r][c] = src[r][c]
        end
    end
    return grid
end

local function emptyNotes()
    local notes = {}
    for r = 1, 9 do
        notes[r] = {}
        for c = 1, 9 do
            notes[r][c] = {}
        end
    end
    return notes
end

local function emptyMarkerGrid()
    local grid = {}
    for r = 1, 9 do
        grid[r] = {}
        for c = 1, 9 do
            grid[r][c] = false
        end
    end
    return grid
end

local function cloneNoteCell(cell)
    if not cell then
        return nil
    end
    local copy = nil
    for digit = 1, 9 do
        if cell[digit] then
            copy = copy or {}
            copy[digit] = true
        end
    end
    return copy
end

local function copyNotes(src)
    local notes = {}
    for r = 1, 9 do
        notes[r] = {}
        for c = 1, 9 do
            local dest_cell = {}
            local source_cell = src and src[r] and src[r][c]
            if type(source_cell) == "table" then
                local had_array_values = false
                for _, digit in ipairs(source_cell) do
                    local d = tonumber(digit)
                    if d and d >= 1 and d <= 9 then
                        dest_cell[d] = true
                        had_array_values = true
                    end
                end
                if not had_array_values then
                    for digit, flag in pairs(source_cell) do
                        local d = tonumber(digit)
                        if d and d >= 1 and d <= 9 and flag then
                            dest_cell[d] = true
                        end
                    end
                end
            end
            notes[r][c] = dest_cell
        end
    end
    return notes
end

-- ---------------------------------------------------------------------------
-- Puzzle generator
-- ---------------------------------------------------------------------------

local function shuffledDigits()
    local digits = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
    for i = #digits, 2, -1 do
        local j = math.random(i)
        digits[i], digits[j] = digits[j], digits[i]
    end
    return digits
end

local function isValidPlacement(grid, row, col, value)
    for i = 1, 9 do
        if grid[row][i] == value or grid[i][col] == value then
            return false
        end
    end
    local box_row = math.floor((row - 1) / 3) * 3 + 1
    local box_col = math.floor((col - 1) / 3) * 3 + 1
    for r = box_row, box_row + 2 do
        for c = box_col, box_col + 2 do
            if grid[r][c] == value then
                return false
            end
        end
    end
    return true
end

local function fillBoard(grid, cell)
    if cell > 81 then
        return true
    end
    local row = math.floor((cell - 1) / 9) + 1
    local col = (cell - 1) % 9 + 1
    local numbers = shuffledDigits()
    for _, value in ipairs(numbers) do
        if isValidPlacement(grid, row, col, value) then
            grid[row][col] = value
            if fillBoard(grid, cell + 1) then
                return true
            end
            grid[row][col] = 0
        end
    end
    return false
end

local function generateSolvedBoard()
    local grid = emptyGrid()
    fillBoard(grid, 1)
    return grid
end

local function countSolutions(grid, limit)
    local solutions = 0
    local function search(cell)
        if solutions >= limit then
            return
        end
        if cell > 81 then
            solutions = solutions + 1
            return
        end
        local row = math.floor((cell - 1) / 9) + 1
        local col = (cell - 1) % 9 + 1
        if grid[row][col] ~= 0 then
            search(cell + 1)
            return
        end
        for _, value in ipairs(shuffledDigits()) do
            if isValidPlacement(grid, row, col, value) then
                grid[row][col] = value
                search(cell + 1)
                grid[row][col] = 0
                if solutions >= limit then
                    return
                end
            end
        end
    end
    search(1)
    return solutions
end

local function createPuzzle(solved_grid, difficulty)
    local puzzle = copyGrid(solved_grid)
    local targets = { easy = 35, medium = 45, hard = 53 }
    local removals = targets[difficulty] or targets.medium
    local cells = {}
    for r = 1, 9 do
        for c = 1, 9 do
            cells[#cells + 1] = { r = r, c = c }
        end
    end
    for i = #cells, 2, -1 do
        local j = math.random(i)
        cells[i], cells[j] = cells[j], cells[i]
    end
    local removed = 0
    for _, cell in ipairs(cells) do
        if removed >= removals then
            break
        end
        local row, col = cell.r, cell.c
        if puzzle[row][col] ~= 0 then
            local backup = puzzle[row][col]
            puzzle[row][col] = 0
            local working = copyGrid(puzzle)
            if countSolutions(working, 2) == 1 then
                removed = removed + 1
            else
                puzzle[row][col] = backup
            end
        end
    end
    return puzzle
end

-- ---------------------------------------------------------------------------
-- SudokuBoard — game state
-- ---------------------------------------------------------------------------

local SudokuBoard = {}
SudokuBoard.__index = SudokuBoard

function SudokuBoard:new()
    local board = {
        puzzle = emptyGrid(),
        solution = emptyGrid(),
        user = emptyGrid(),
        conflicts = emptyGrid(),
        notes = emptyNotes(),
        wrong_marks = emptyMarkerGrid(),
        selected = { row = 1, col = 1 },
        difficulty = DEFAULT_DIFFICULTY,
        reveal_solution = false,
        undo_stack = {},
    }
    setmetatable(board, self)
    board:recalcConflicts()
    return board
end

function SudokuBoard:serialize()
    return {
        puzzle = copyGrid(self.puzzle),
        solution = copyGrid(self.solution),
        user = copyGrid(self.user),
        notes = copyNotes(self.notes),
        wrong_marks = copyGrid(self.wrong_marks),
        selected = { row = self.selected.row, col = self.selected.col },
        difficulty = self.difficulty,
        reveal_solution = self.reveal_solution,
    }
end

function SudokuBoard:load(state)
    if not state or not state.puzzle or not state.solution or not state.user then
        return false
    end
    self.puzzle = copyGrid(state.puzzle)
    self.solution = copyGrid(state.solution)
    self.user = copyGrid(state.user)
    self.notes = copyNotes(state.notes)
    if state.wrong_marks then
        self.wrong_marks = copyGrid(state.wrong_marks)
    else
        self.wrong_marks = emptyMarkerGrid()
    end
    self.difficulty = state.difficulty or DEFAULT_DIFFICULTY
    self.undo_stack = {}
    if state.selected then
        self.selected = {
            row = math.max(1, math.min(9, state.selected.row or 1)),
            col = math.max(1, math.min(9, state.selected.col or 1)),
        }
    else
        self.selected = { row = 1, col = 1 }
    end
    self.reveal_solution = state.reveal_solution or false
    self:recalcConflicts()
    return true
end

function SudokuBoard:generate(difficulty)
    self.difficulty = difficulty or self.difficulty or DEFAULT_DIFFICULTY
    local solution = generateSolvedBoard()
    local puzzle = createPuzzle(solution, self.difficulty)
    self.puzzle = puzzle
    self.solution = solution
    self.user = emptyGrid()
    self.notes = emptyNotes()
    self.wrong_marks = emptyMarkerGrid()
    self.selected = { row = 1, col = 1 }
    self.reveal_solution = false
    self.undo_stack = {}
    self:recalcConflicts()
end

function SudokuBoard:pushUndo(entry)
    if entry then
        self.undo_stack[#self.undo_stack + 1] = entry
    end
end

function SudokuBoard:clearUndoHistory()
    self.undo_stack = {}
end

function SudokuBoard:getWorkingValue(row, col)
    local given = self.puzzle[row][col]
    if given ~= 0 then
        return given
    end
    return self.user[row][col]
end

function SudokuBoard:isGiven(row, col)
    return self.puzzle[row][col] ~= 0
end

local function ensureGridValues(grid)
    for r = 1, 9 do
        grid[r] = grid[r] or {}
        for c = 1, 9 do
            grid[r][c] = grid[r][c] or 0
        end
    end
end

function SudokuBoard:recalcConflicts()
    ensureGridValues(self.conflicts)
    for r = 1, 9 do
        for c = 1, 9 do
            self.conflicts[r][c] = false
        end
    end
    local function markConflicts(cells)
        local map = {}
        for _, cell in ipairs(cells) do
            if cell.value ~= 0 then
                map[cell.value] = map[cell.value] or {}
                table.insert(map[cell.value], cell)
            end
        end
        for _, positions in pairs(map) do
            if #positions > 1 then
                for _, pos in ipairs(positions) do
                    self.conflicts[pos.row][pos.col] = true
                end
            end
        end
    end
    for r = 1, 9 do
        local cells = {}
        for c = 1, 9 do
            cells[#cells + 1] = { row = r, col = c, value = self:getWorkingValue(r, c) }
        end
        markConflicts(cells)
    end
    for c = 1, 9 do
        local cells = {}
        for r = 1, 9 do
            cells[#cells + 1] = { row = r, col = c, value = self:getWorkingValue(r, c) }
        end
        markConflicts(cells)
    end
    for box_row = 0, 2 do
        for box_col = 0, 2 do
            local cells = {}
            for r = 1, 3 do
                for c = 1, 3 do
                    local row = box_row * 3 + r
                    local col = box_col * 3 + c
                    cells[#cells + 1] = { row = row, col = col, value = self:getWorkingValue(row, col) }
                end
            end
            markConflicts(cells)
        end
    end
end

function SudokuBoard:setSelection(row, col)
    self.selected = { row = math.max(1, math.min(9, row)), col = math.max(1, math.min(9, col)) }
end

function SudokuBoard:getSelection()
    return self.selected.row, self.selected.col
end

function SudokuBoard:isShowingSolution()
    return self.reveal_solution
end

function SudokuBoard:toggleSolution()
    self.reveal_solution = not self.reveal_solution
end

function SudokuBoard:setValue(value)
    if self.reveal_solution then
        return false, _("Hide result to keep playing.")
    end
    local row, col = self:getSelection()
    if self:isGiven(row, col) then
        return false, _("This cell is fixed.")
    end
    local prev_value = self.user[row][col]
    local prev_notes = cloneNoteCell(self.notes[row][col])
    local new_value = value or 0

    if prev_value == new_value and not prev_notes then
        if not value then
            return false, _("Cell already empty.")
        end
        return true
    end

    self.user[row][col] = new_value
    self:clearNotes(row, col)
    self:clearWrongMark(row, col)
    self:recalcConflicts()
    if prev_value ~= new_value or prev_notes then
        self:pushUndo{
            type = "value",
            row = row,
            col = col,
            prev_value = prev_value,
            prev_notes = prev_notes,
        }
    end
    return true
end

function SudokuBoard:clearSelection()
    return self:setValue(nil)
end

function SudokuBoard:getDisplayValue(row, col)
    if self.reveal_solution then
        return self.solution[row][col], self:isGiven(row, col)
    end
    if self:isGiven(row, col) then
        return self.puzzle[row][col], true
    end
    local value = self.user[row][col]
    if value == 0 then
        return nil
    end
    return value, false
end

function SudokuBoard:isConflict(row, col)
    return self.conflicts[row][col]
end

function SudokuBoard:clearNotes(row, col)
    if self.notes[row] and self.notes[row][col] then
        self.notes[row][col] = {}
    end
end

function SudokuBoard:getCellNotes(row, col)
    local cell = self.notes[row] and self.notes[row][col]
    if not cell then
        return nil
    end
    for digit = 1, 9 do
        if cell[digit] then
            return cell
        end
    end
    return nil
end

function SudokuBoard:clearWrongMarks()
    for r = 1, 9 do
        for c = 1, 9 do
            self.wrong_marks[r][c] = false
        end
    end
end

function SudokuBoard:clearWrongMark(row, col)
    if self.wrong_marks[row] then
        self.wrong_marks[row][col] = false
    end
end

function SudokuBoard:hasWrongMark(row, col)
    return self.wrong_marks[row] and self.wrong_marks[row][col] or false
end

function SudokuBoard:updateWrongMarks()
    self:clearWrongMarks()
    local has_wrong = false
    for r = 1, 9 do
        for c = 1, 9 do
            local value = self.user[r][c]
            if value ~= 0 and value ~= self.solution[r][c] then
                self.wrong_marks[r][c] = true
                has_wrong = true
            end
        end
    end
    return has_wrong
end

function SudokuBoard:toggleNoteDigit(value)
    if self.reveal_solution then
        return false, _("Hide result to keep playing.")
    end
    local row, col = self:getSelection()
    if self:isGiven(row, col) then
        return false, _("This cell is fixed.")
    end
    if self.user[row][col] ~= 0 then
        return false, _("Clear the cell before adding notes.")
    end
    self.notes[row][col] = self.notes[row][col] or {}
    local prev_cell = cloneNoteCell(self.notes[row][col])
    local was_set = self.notes[row][col][value] and true or false
    if was_set then
        self.notes[row][col][value] = nil
    else
        self.notes[row][col][value] = true
    end
    local now_set = self.notes[row][col][value] and true or false
    if was_set == now_set then
        return true
    end
    self:pushUndo{
        type = "notes",
        row = row,
        col = col,
        prev_notes = prev_cell,
    }
    return true
end

function SudokuBoard:getRemainingCells()
    local remaining = 0
    for r = 1, 9 do
        for c = 1, 9 do
            if self:getWorkingValue(r, c) == 0 then
                remaining = remaining + 1
            end
        end
    end
    return remaining
end

function SudokuBoard:countDigit(digit)
    local count = 0
    for r = 1, 9 do
        for c = 1, 9 do
            if self:getWorkingValue(r, c) == digit then
                count = count + 1
            end
        end
    end
    return count
end

function SudokuBoard:canUndo()
    return self.undo_stack[1] ~= nil
end

function SudokuBoard:undo()
    local entry = table.remove(self.undo_stack)
    if not entry then
        return false, _("Nothing to undo.")
    end
    local row, col = entry.row, entry.col
    if entry.type == "value" then
        self.user[row][col] = entry.prev_value or 0
        self.notes[row][col] = cloneNoteCell(entry.prev_notes) or {}
        self:setSelection(row, col)
        self:recalcConflicts()
        self:clearWrongMark(row, col)
    elseif entry.type == "notes" then
        self.notes[row][col] = cloneNoteCell(entry.prev_notes) or {}
        self:setSelection(row, col)
    end
    return true
end

function SudokuBoard:isSolved()
    if self.reveal_solution then
        return false
    end
    for r = 1, 9 do
        for c = 1, 9 do
            if self:getWorkingValue(r, c) ~= self.solution[r][c] or self.conflicts[r][c] then
                return false
            end
        end
    end
    return true
end

return {
    SudokuBoard = SudokuBoard,
    DEFAULT_DIFFICULTY = DEFAULT_DIFFICULTY,
}
