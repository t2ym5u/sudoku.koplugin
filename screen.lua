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

local Device      = require("device")
local Menu        = require("ui/widget/menu")
local UIManager   = require("ui/uimanager")
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

-- ---------------------------------------------------------------------------
-- SudokuScreen
-- ---------------------------------------------------------------------------

local GAME_RULES_EN = _([[
Sudoku — Rules

Fill the 9×9 grid with the digits 1–9.

Each row, each column, and each of the nine 3×3 boxes must contain every digit from 1 to 9 exactly once.

Given digits are fixed and cannot be changed.

Other grid sizes follow the same rules with their own boxes: 4×4, 6×6, 12×12 and 16×16. Beyond 9, the letters A to G stand for 10 to 16.

Tip: use Note mode to pencil in candidate digits before committing.]])

local GAME_RULES_FR = [[
Sudoku — Règles

Remplissez la grille 9×9 avec les chiffres de 1 à 9.

Chaque ligne, chaque colonne et chacun des neuf carrés 3×3 doit contenir tous les chiffres de 1 à 9 exactement une fois.

Les chiffres donnés sont fixes et ne peuvent pas être modifiés.

Les autres tailles de grille (4×4, 6×6, 12×12 et 16×16) suivent les mêmes règles avec leurs propres carrés. Au-delà de 9, les lettres A à G valent 10 à 16.

Conseil : utilisez le mode Note pour inscrire en petit les chiffres candidats avant de vous décider.
]]

local SudokuScreen = BaseScreen:extend{}

function SudokuScreen:buildLayout()
    local title_bar = self:buildTitleBar(_("Sudoku"), function()
        return {
            { text = _("New game"),                    callback = function() self:onNewGame() end },
            { text = self:getGridButtonText(),         callback = function() self:openGridMenu() end },
            { text = self:getDifficultyButtonText(),   callback = function() self:openDifficultyMenu() end },
            { text = self.board:isShowingSolution() and _("Hide solution") or _("Show solution"),
              callback = function() self:toggleSolution() end },
            { text = self.plugin:isDailyCompletedToday() and _("Daily Challenge ✓") or _("Daily Challenge"),
              callback = function()
                  self:closeScreen()
                  self.plugin:showDailyChallenge()
              end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
        }
    end)
    local controls = self:buildKeypadControls()
    self.board_widget = SudokuBoardWidget:new{
        board              = self.board,
        max_size           = self:getBoardMaxSize(title_bar, controls),
        onSelectionChanged = function() self:updateStatus() end,
    }
    self:placeBoard(title_bar, self.board_widget, controls)
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
    return T(_("Difficulty: %1"), label)
end

function SudokuScreen:getGridButtonText()
    return T(_("Size: %1"), self.board.n .. "×" .. self.board.n)
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
        title    = _("Select size"),
        item_table = items,
        width    = math.floor(DeviceScreen:getWidth() * 0.7),
        height   = math.floor(DeviceScreen:getHeight() * 0.9),
        disable_footer_padding = true,
        show_parent = self,
    }
    UIManager:show(menu)
end

-- The Daily Challenge is one fixed puzzle a day: "New game" there leaves it
-- for the regular game instead of overwriting today's puzzle with a random
-- one (which the menu entry used to do).
function SudokuScreen:onNewGame()
    if self.plugin.active_mode == "daily" then
        self:closeScreen()
        self.plugin:showGame()
        return
    end
    common.BaseScreen.onNewGame(self)
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

return SudokuScreen
