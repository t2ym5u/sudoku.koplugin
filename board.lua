local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire_common(name)
    local key = _dir .. "common/" .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. "common/" .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local grid_utils       = lrequire_common("grid_utils")
local puzzle_generator = lrequire_common("puzzle_generator")
local BaseBoard        = lrequire_common("base_board")

local emptyGrid        = grid_utils.emptyGrid
local emptyNotes       = grid_utils.emptyNotes
local emptyMarkerGrid  = grid_utils.emptyMarkerGrid
local copyGrid         = grid_utils.copyGrid
local copyNotes        = grid_utils.copyNotes

local generateSolvedBoard = puzzle_generator.generateSolvedBoard
local createPuzzle        = puzzle_generator.createPuzzle

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
local DEFAULT_GRID       = "9x9"

-- ---------------------------------------------------------------------------
-- SudokuBoard
-- ---------------------------------------------------------------------------

local SudokuBoard = setmetatable({}, { __index = BaseBoard })
SudokuBoard.__index = SudokuBoard

function SudokuBoard:new(config)
    local cfg = config or getGridConfig(DEFAULT_GRID)
    local n   = cfg.n
    local board = {
        n               = n,
        box_rows        = cfg.box_rows,
        box_cols        = cfg.box_cols,
        grid_id         = cfg.id,
        puzzle          = emptyGrid(n),
        solution        = emptyGrid(n),
        user            = emptyGrid(n),
        conflicts       = emptyGrid(n),
        notes           = emptyNotes(n),
        wrong_marks     = emptyMarkerGrid(n),
        selected        = { row = 1, col = 1 },
        difficulty      = DEFAULT_DIFFICULTY,
        reveal_solution = false,
        undo_stack      = {},
    }
    setmetatable(board, self)
    board:recalcConflicts()
    return board
end

function SudokuBoard:serialize()
    local n = self.n
    return {
        n               = n,
        box_rows        = self.box_rows,
        box_cols        = self.box_cols,
        grid_id         = self.grid_id,
        puzzle          = copyGrid(self.puzzle, n),
        solution        = copyGrid(self.solution, n),
        user            = copyGrid(self.user, n),
        notes           = copyNotes(self.notes, n),
        wrong_marks     = copyGrid(self.wrong_marks, n),
        selected        = { row = self.selected.row, col = self.selected.col },
        difficulty      = self.difficulty,
        reveal_solution = self.reveal_solution,
    }
end

function SudokuBoard:load(state)
    if not state or not state.puzzle or not state.solution or not state.user then
        return false
    end
    self.n        = state.n        or 9
    self.box_rows = state.box_rows or 3
    self.box_cols = state.box_cols or 3
    self.grid_id  = state.grid_id  or "9x9"
    local n = self.n
    self.puzzle      = copyGrid(state.puzzle, n)
    self.solution    = copyGrid(state.solution, n)
    self.user        = copyGrid(state.user, n)
    self.notes       = copyNotes(state.notes, n)
    self.wrong_marks = state.wrong_marks and copyGrid(state.wrong_marks, n) or emptyMarkerGrid(n)
    self.conflicts   = emptyGrid(n)
    self.difficulty  = state.difficulty or DEFAULT_DIFFICULTY
    self.undo_stack  = {}
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
    local puzzle   = createPuzzle(solution, self.difficulty, n, box_rows, box_cols)
    self.puzzle          = puzzle
    self.solution        = solution
    self.user            = emptyGrid(n)
    self.notes           = emptyNotes(n)
    self.wrong_marks     = emptyMarkerGrid(n)
    self.selected        = { row = 1, col = 1 }
    self.reveal_solution = false
    self.undo_stack      = {}
    self:recalcConflicts()
end

function SudokuBoard:isGiven(row, col)
    return self.puzzle[row][col] ~= 0
end

function SudokuBoard:getWorkingValue(row, col)
    local given = self.puzzle[row][col]
    if given ~= 0 then return given end
    return self.user[row][col]
end

function SudokuBoard:getDisplayValue(row, col)
    if self.reveal_solution then
        return self.solution[row][col], self:isGiven(row, col)
    end
    if self:isGiven(row, col) then
        return self.puzzle[row][col], true
    end
    local value = self.user[row][col]
    if value == 0 then return nil end
    return value, false
end

function SudokuBoard:clearUndoHistory()
    self.undo_stack = {}
end

function SudokuBoard:isConflict(row, col)
    return self.conflicts[row][col]
end

return {
    SudokuBoard      = SudokuBoard,
    DEFAULT_DIFFICULTY = DEFAULT_DIFFICULTY,
    DEFAULT_GRID     = DEFAULT_GRID,
    GRID_CONFIGS     = GRID_CONFIGS,
    getGridConfig    = getGridConfig,
}
