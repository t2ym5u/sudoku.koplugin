local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end
local function lrequire_common(name)
    local key = _dir .. "common/" .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. "common/" .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local ButtonTable = require("ui/widget/buttontable")
local Device      = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Menu        = require("ui/widget/menu")
local Size        = require("ui/size")
local UIManager   = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan  = require("ui/widget/verticalspan")
local _           = require("i18n")
local T           = require("ffi/util").template

local board_module      = lrequire("board")
local SudokuBoardWidget = lrequire("board_widget")

local common          = lrequire_common("base_screen")
local BaseScreen      = common.BaseScreen
local DIFFICULTY_ORDER  = common.DIFFICULTY_ORDER
local DIFFICULTY_LABELS = common.DIFFICULTY_LABELS
local generateWithProgress = common.generateWithProgress

local DeviceScreen = Device.screen

-- Digits 10+ display as A-G (must match board_widget)
local function digitToChar(d)
    return d <= 9 and tostring(d) or string.char(55 + d)
end

-- ---------------------------------------------------------------------------
-- SudokuScreen
-- ---------------------------------------------------------------------------

local GAME_RULES_EN = _([[
Sudoku — Rules

Fill the 9×9 grid with the digits 1–9.

Each row, each column, and each of the nine 3×3 boxes must contain every digit from 1 to 9 exactly once.

Given digits are fixed and cannot be changed.

Tip: use Note mode to pencil in candidate digits before committing.]])

local GAME_RULES_FR = [[
Sudoku — Règles

Remplissez la grille 9×9 avec les chiffres de 1 à 9.

Chaque ligne, chaque colonne et chacun des neuf carrés 3×3 doit contenir tous les chiffres de 1 à 9 exactement une fois.

Les chiffres donnés sont fixes et ne peuvent pas être modifiés.

Conseil : utilisez le mode Note pour inscrire en petit les chiffres candidats avant de vous décider.
]]

local SudokuScreen = BaseScreen:extend{}

function SudokuScreen:buildLayout()
    local is_landscape = DeviceScreen:getWidth() > DeviceScreen:getHeight()
    local sw = DeviceScreen:getWidth()
    local sh = DeviceScreen:getHeight()

    -- In portrait mode, cap the board size so that the full layout (buttons +
    -- board + status + keypad) fits within the screen height.
    local max_board_size
    if not is_landscape then
        local btn_row_h    = Size.item.height_default + 2 * Size.padding.buttontable
        local frame_h      = (Size.padding.large + Size.margin.default) * 2
        local span         = Size.span.vertical_large
        local keypad_rows  = self.board.box_rows + 1   -- digit rows + utility row
        local status_h     = 2 * Size.item.height_default  -- budget for 2 status lines
        local non_board_h  = 5 * span + btn_row_h + status_h + keypad_rows * btn_row_h + frame_h
        max_board_size = sh - non_board_h
    end

    self.board_widget = SudokuBoardWidget:new{
        board              = self.board,
        max_size           = max_board_size,
        onSelectionChanged = function() self:updateStatus() end,
    }

    local board_frame = FrameContainer:new{
        padding = Size.padding.large,
        margin  = Size.margin.default,
        self.board_widget,
    }

    local board_frame_size  = self.board_widget.size + (Size.padding.large + Size.margin.default) * 2
    local right_panel_width = sw - board_frame_size - Size.span.horizontal_default
    local button_width = is_landscape
        and math.max(right_panel_width - Size.span.horizontal_default, 100)
        or  math.floor(sw * 0.9)
    local keypad_width = is_landscape and button_width or math.floor(sw * 0.75)

    -- Title bar with Options menu
    local title_bar = self:buildTitleBar(_("Sudoku"), function()
        return {
            { text = _("New game"),                    callback = function() self:onNewGame() end },
            { text = self.plugin:isDailyCompletedToday() and _("Daily Challenge ✓") or _("Daily Challenge"),
              callback = function()
                  self:closeScreen()
                  self.plugin:showDailyChallenge()
              end },
            { text = self:getGridButtonText(),         callback = function() self:openGridMenu() end },
            { text = self:getDifficultyButtonText(),   callback = function() self:openDifficultyMenu() end },
            { text = self.board:isShowingSolution() and _("Hide result") or _("Show result"),
              callback = function() self:toggleSolution() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
        }
    end)

    -- Digit keypad
    local n        = self.board.n
    local box_rows = self.board.box_rows
    local box_cols = self.board.box_cols
    local keypad_rows = {}
    local digit = 1
    for _ = 1, box_rows do
        local row = {}
        for _ = 1, box_cols do
            local d = digit
            row[#row + 1] = {
                id = "digit_" .. d, text = digitToChar(d),
                callback = function() self:onDigit(d) end,
            }
            digit = digit + 1
        end
        keypad_rows[#keypad_rows + 1] = row
    end
    keypad_rows[#keypad_rows + 1] = {
        { id = "note_button", text = self:getNoteButtonText(),
          callback = function() self:toggleNoteMode() end },
        { text = _("Erase"),  callback = function() self:onErase() end },
        { text = _("Check"),  callback = function() self:checkProgress() end },
        { id = "undo_button", text = _("Undo"),
          callback = function() self:onUndo() end },
    }
    local keypad = ButtonTable:new{
        width = keypad_width, shrink_unneeded_width = true, buttons = keypad_rows,
    }
    self.note_button  = keypad:getButtonById("note_button")
    self.undo_button  = keypad:getButtonById("undo_button")
    self.digit_buttons = {}
    for d = 1, n do
        self.digit_buttons[d] = keypad:getButtonById("digit_" .. d)
    end

    if is_landscape then
        local right_panel = VerticalGroup:new{
            align = "center",
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            keypad,
        }
        local content = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            right_panel,
        }
        self:buildLandscapeLayout(title_bar, content)
    else
        local content = VerticalGroup:new{
            align = "center",
            board_frame,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
        }
        self:buildPortraitLayout(title_bar, content, keypad)
    end
    self:ensureShowButtonState()
    self:updateNoteButton()
    self:updateUndoButton()
    self:updateDigitButtons()
    self:updateDifficultyButton()
    self:updateGridButton()
    self:updateStatus()
end

-- ---------------------------------------------------------------------------
-- Sudoku-specific button helpers
-- ---------------------------------------------------------------------------

function SudokuScreen:getDifficultyButtonText()
    local label = DIFFICULTY_LABELS[self.board.difficulty] or self.board.difficulty
    return T(_("Diff: %1"), label)
end

function SudokuScreen:getGridButtonText()
    return T(_("Grid: %1"), self.board.n .. "×" .. self.board.n)
end

function SudokuScreen:updateGridButton()
    if not self.grid_button then return end
    self.grid_button:setText(self:getGridButtonText(), self.grid_button.width)
end

-- ---------------------------------------------------------------------------
-- Sudoku-specific menus
-- ---------------------------------------------------------------------------

function SudokuScreen:openDifficultyMenu()
    local menu
    local function selectDifficulty(level)
        if level ~= self.board.difficulty then
            generateWithProgress(self.board, level)
            self.plugin:saveState()
            self.board_widget:refresh()
            self:ensureShowButtonState()
            self:updateDigitButtons()
            self:updateStatus(T(_("Started a %1 game."), DIFFICULTY_LABELS[level] or level))
        else
            self:updateStatus()
        end
        self:updateDifficultyButton()
        if menu then UIManager:close(menu) end
        return true
    end
    local items = {}
    for _, level in ipairs(DIFFICULTY_ORDER) do
        items[#items + 1] = {
            text    = DIFFICULTY_LABELS[level] or level,
            checked = (level == self.board.difficulty),
            callback = function() return selectDifficulty(level) end,
        }
    end
    menu = Menu:new{
        title    = _("Select difficulty"),
        item_table = items,
        width    = math.floor(DeviceScreen:getWidth() * 0.7),
        height   = math.floor(DeviceScreen:getHeight() * 0.9),
        disable_footer_padding = true,
        show_parent = self,
    }
    UIManager:show(menu)
end

function SudokuScreen:openGridMenu()
    local menu
    local function selectGrid(cfg)
        if cfg.id ~= self.board.grid_id then
            UIManager:close(menu)
            self:onGridChange(cfg.id)
        else
            if menu then UIManager:close(menu) end
        end
        return true
    end
    local items = {}
    for _, cfg in ipairs(board_module.GRID_CONFIGS) do
        items[#items + 1] = {
            text    = cfg.label,
            checked = (cfg.id == self.board.grid_id),
            callback = function() return selectGrid(cfg) end,
        }
    end
    menu = Menu:new{
        title    = _("Select grid size"),
        item_table = items,
        width    = math.floor(DeviceScreen:getWidth() * 0.7),
        height   = math.floor(DeviceScreen:getHeight() * 0.9),
        disable_footer_padding = true,
        show_parent = self,
    }
    UIManager:show(menu)
end

function SudokuScreen:onGridChange(grid_id)
    local prev_difficulty = self.board.difficulty
    local cfg  = board_module.getGridConfig(grid_id)
    self.board = board_module.SudokuBoard:new(cfg)
    generateWithProgress(self.board, prev_difficulty)
    self.plugin.board = self.board
    self.plugin:saveState()
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

-- ---------------------------------------------------------------------------
-- Status bar
-- ---------------------------------------------------------------------------

function SudokuScreen:updateStatus(message)
    local status
    if message then
        status = message
    else
        local remaining = self.board:getRemainingCells()
        local row, col  = self.board:getSelection()
        status = T(_("Selected: %1,%2  ·  Empty cells: %3"), row, col, remaining)
        if self.board:isShowingSolution() then
            status = status .. "\n" .. _("Result is being shown; editing is disabled.")
        elseif self.board:isSolved() then
            status = _("Congratulations! Puzzle solved.")
        elseif self.note_mode then
            status = status .. "\n" .. _("Note mode is ON.")
        end
    end
    self.status_text:setText(status)
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

return SudokuScreen
