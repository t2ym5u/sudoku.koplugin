local _ = require("gettext")

-- ---------------------------------------------------------------------------
-- Grid size configurations
-- ---------------------------------------------------------------------------

local GRID_CONFIGS = {
    { id = "4x4",   n = 4,  box_rows = 2, box_cols = 2, label = "4×4"   },
    { id = "6x6",   n = 6,  box_rows = 2, box_cols = 3, label = "6×6"   },
    { id = "9x9",   n = 9,  box_rows = 3, box_cols = 3, label = "9×9"   },
    { id = "12x12", n = 12, box_rows = 3, box_cols = 4, label = "12×12" },
    { id = "16x16", n = 16, box_rows = 4, box_cols = 4, label = "16×16" },
}

local GRID_CONFIG_MAP = {}
for _, cfg in ipairs(GRID_CONFIGS) do
    GRID_CONFIG_MAP[cfg.id] = cfg
end

local function getGridConfig(id)
    return GRID_CONFIG_MAP[id] or GRID_CONFIG_MAP["9x9"]
end

local DEFAULT_DIFFICULTY = "medium"
local DEFAULT_GRID = "9x9"

-- ---------------------------------------------------------------------------
-- Grid / note utility functions
-- ---------------------------------------------------------------------------

local function emptyGrid(n)
    local grid = {}
    for r = 1, n do
        grid[r] = {}
        for c = 1, n do
            grid[r][c] = 0
        end
    end
    return grid
end

local function copyGrid(src, n)
    local grid = {}
    for r = 1, n do
        grid[r] = {}
        for c = 1, n do
            grid[r][c] = src[r][c]
        end
    end
    return grid
end

local function emptyNotes(n)
    local notes = {}
    for r = 1, n do
        notes[r] = {}
        for c = 1, n do
            notes[r][c] = {}
        end
    end
    return notes
end

local function emptyMarkerGrid(n)
    local grid = {}
    for r = 1, n do
        grid[r] = {}
        for c = 1, n do
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
    for digit = 1, 16 do
        if cell[digit] then
            copy = copy or {}
            copy[digit] = true
        end
    end
    return copy
end

local function copyNotes(src, n)
    local notes = {}
    for r = 1, n do
        notes[r] = {}
        for c = 1, n do
            local dest_cell = {}
            local source_cell = src and src[r] and src[r][c]
            if type(source_cell) == "table" then
                local had_array_values = false
                for _, digit in ipairs(source_cell) do
                    local d = tonumber(digit)
                    if d and d >= 1 and d <= n then
                        dest_cell[d] = true
                        had_array_values = true
                    end
                end
                if not had_array_values then
                    for digit, flag in pairs(source_cell) do
                        local d = tonumber(digit)
                        if d and d >= 1 and d <= n and flag then
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

local function shuffledDigits(n)
    local digits = {}
    for i = 1, n do digits[i] = i end
    for i = n, 2, -1 do
        local j = math.random(i)
        digits[i], digits[j] = digits[j], digits[i]
    end
    return digits
end

local function isValidPlacement(grid, row, col, value, n, box_rows, box_cols)
    for i = 1, n do
        if grid[row][i] == value or grid[i][col] == value then
            return false
        end
    end
    local br = math.floor((row - 1) / box_rows) * box_rows + 1
    local bc = math.floor((col - 1) / box_cols) * box_cols + 1
    for r = br, br + box_rows - 1 do
        for c = bc, bc + box_cols - 1 do
            if grid[r][c] == value then
                return false
            end
        end
    end
    return true
end

local function fillBoard(grid, cell, n, box_rows, box_cols)
    if cell > n * n then
        return true
    end
    local row = math.floor((cell - 1) / n) + 1
    local col = (cell - 1) % n + 1
    local numbers = shuffledDigits(n)
    for _, value in ipairs(numbers) do
        if isValidPlacement(grid, row, col, value, n, box_rows, box_cols) then
            grid[row][col] = value
            if fillBoard(grid, cell + 1, n, box_rows, box_cols) then
                return true
            end
            grid[row][col] = 0
        end
    end
    return false
end

local function generateSolvedBoard(n, box_rows, box_cols)
    local grid = emptyGrid(n)
    fillBoard(grid, 1, n, box_rows, box_cols)
    return grid
end

local function countSolutions(grid, limit, n, box_rows, box_cols)
    local solutions = 0
    local function search(cell)
        if solutions >= limit then
            return
        end
        if cell > n * n then
            solutions = solutions + 1
            return
        end
        local row = math.floor((cell - 1) / n) + 1
        local col = (cell - 1) % n + 1
        if grid[row][col] ~= 0 then
            search(cell + 1)
            return
        end
        for _, value in ipairs(shuffledDigits(n)) do
            if isValidPlacement(grid, row, col, value, n, box_rows, box_cols) then
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

local function createPuzzle(solved_grid, difficulty, n, box_rows, box_cols)
    local puzzle = copyGrid(solved_grid, n)
    local total = n * n
    -- Scale removal targets proportionally to grid size
    local ratios = { easy = 0.43, medium = 0.56, hard = 0.65 }
    local ratio = ratios[difficulty] or ratios.medium
    local removals = math.floor(total * ratio)
    local cells = {}
    for r = 1, n do
        for c = 1, n do
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
            local working = copyGrid(puzzle, n)
            if countSolutions(working, 2, n, box_rows, box_cols) == 1 then
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

function SudokuBoard:new(config)
    local cfg = config or getGridConfig(DEFAULT_GRID)
    local n = cfg.n
    local board = {
        n = n,
        box_rows = cfg.box_rows,
        box_cols = cfg.box_cols,
        grid_id = cfg.id,
        puzzle = emptyGrid(n),
        solution = emptyGrid(n),
        user = emptyGrid(n),
        conflicts = emptyGrid(n),
        notes = emptyNotes(n),
        wrong_marks = emptyMarkerGrid(n),
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
    local n = self.n
    return {
        n = n,
        box_rows = self.box_rows,
        box_cols = self.box_cols,
        grid_id = self.grid_id,
        puzzle = copyGrid(self.puzzle, n),
        solution = copyGrid(self.solution, n),
        user = copyGrid(self.user, n),
        notes = copyNotes(self.notes, n),
        wrong_marks = copyGrid(self.wrong_marks, n),
        selected = { row = self.selected.row, col = self.selected.col },
        difficulty = self.difficulty,
        reveal_solution = self.reveal_solution,
    }
end

function SudokuBoard:load(state)
    if not state or not state.puzzle or not state.solution or not state.user then
        return false
    end
    -- Restore grid config (defaults to 9×9 for old saves)
    self.n = state.n or 9
    self.box_rows = state.box_rows or 3
    self.box_cols = state.box_cols or 3
    self.grid_id = state.grid_id or "9x9"
    local n = self.n
    self.puzzle = copyGrid(state.puzzle, n)
    self.solution = copyGrid(state.solution, n)
    self.user = copyGrid(state.user, n)
    self.notes = copyNotes(state.notes, n)
    self.wrong_marks = state.wrong_marks and copyGrid(state.wrong_marks, n) or emptyMarkerGrid(n)
    self.conflicts = emptyGrid(n)
    self.difficulty = state.difficulty or DEFAULT_DIFFICULTY
    self.undo_stack = {}
    if state.selected then
        self.selected = {
            row = math.max(1, math.min(n, state.selected.row or 1)),
            col = math.max(1, math.min(n, state.selected.col or 1)),
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
    local n, box_rows, box_cols = self.n, self.box_rows, self.box_cols
    local solution = generateSolvedBoard(n, box_rows, box_cols)
    local puzzle = createPuzzle(solution, self.difficulty, n, box_rows, box_cols)
    self.puzzle = puzzle
    self.solution = solution
    self.user = emptyGrid(n)
    self.notes = emptyNotes(n)
    self.wrong_marks = emptyMarkerGrid(n)
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

local function ensureGridValues(grid, n)
    for r = 1, n do
        grid[r] = grid[r] or {}
        for c = 1, n do
            grid[r][c] = grid[r][c] or 0
        end
    end
end

function SudokuBoard:recalcConflicts()
    local n, box_rows, box_cols = self.n, self.box_rows, self.box_cols
    ensureGridValues(self.conflicts, n)
    for r = 1, n do
        for c = 1, n do
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
    for r = 1, n do
        local cells = {}
        for c = 1, n do
            cells[#cells + 1] = { row = r, col = c, value = self:getWorkingValue(r, c) }
        end
        markConflicts(cells)
    end
    for c = 1, n do
        local cells = {}
        for r = 1, n do
            cells[#cells + 1] = { row = r, col = c, value = self:getWorkingValue(r, c) }
        end
        markConflicts(cells)
    end
    local num_box_rows = math.floor(n / box_rows)
    local num_box_cols = math.floor(n / box_cols)
    for box_r = 0, num_box_rows - 1 do
        for box_c = 0, num_box_cols - 1 do
            local cells = {}
            for r = 1, box_rows do
                for c = 1, box_cols do
                    local row = box_r * box_rows + r
                    local col = box_c * box_cols + c
                    cells[#cells + 1] = { row = row, col = col, value = self:getWorkingValue(row, col) }
                end
            end
            markConflicts(cells)
        end
    end
end

function SudokuBoard:setSelection(row, col)
    local n = self.n
    self.selected = { row = math.max(1, math.min(n, row)), col = math.max(1, math.min(n, col)) }
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
    for digit = 1, self.n do
        if cell[digit] then
            return cell
        end
    end
    return nil
end

function SudokuBoard:clearWrongMarks()
    for r = 1, self.n do
        for c = 1, self.n do
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
    for r = 1, self.n do
        for c = 1, self.n do
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
    for r = 1, self.n do
        for c = 1, self.n do
            if self:getWorkingValue(r, c) == 0 then
                remaining = remaining + 1
            end
        end
    end
    return remaining
end

function SudokuBoard:countDigit(digit)
    local count = 0
    for r = 1, self.n do
        for c = 1, self.n do
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
    for r = 1, self.n do
        for c = 1, self.n do
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
    DEFAULT_GRID = DEFAULT_GRID,
    GRID_CONFIGS = GRID_CONFIGS,
    getGridConfig = getGridConfig,
}
