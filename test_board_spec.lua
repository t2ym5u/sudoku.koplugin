-- Standalone spec for board.lua. Self-contained: works whether run from
-- inside this plugin's own repo (`busted`) or from the koreader-plugins
-- monorepo -- it never depends on sibling directories outside this folder.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.preload["gettext"] = function()
    return setmetatable({}, { __call = function(_, s) return s end })
end
package.path = DIR .. "common/?.lua;" .. package.path

describe("SudokuBoard", function()
    local SudokuBoard, getGridConfig

    setup(function()
        local Mod = assert(loadfile(DIR .. "board.lua"))()
        SudokuBoard   = Mod.SudokuBoard
        getGridConfig = Mod.getGridConfig
    end)

    describe("getGridConfig", function()
        it("returns correct config for 9x9", function()
            local cfg = getGridConfig("9x9")
            assert.are.equal(9, cfg.n)
            assert.are.equal(3, cfg.box_rows)
            assert.are.equal(3, cfg.box_cols)
        end)

        it("returns correct config for 4x4", function()
            local cfg = getGridConfig("4x4")
            assert.are.equal(4, cfg.n)
            assert.are.equal(2, cfg.box_rows)
            assert.are.equal(2, cfg.box_cols)
        end)

        it("falls back to 9x9 for unknown id", function()
            local cfg = getGridConfig("unknown")
            assert.are.equal(9, cfg.n)
        end)
    end)

    describe("SudokuBoard:new", function()
        it("creates a 9x9 board by default", function()
            local b = SudokuBoard:new()
            assert.are.equal(9, b.n)
            assert.are.equal(3, b.box_rows)
            assert.are.equal(3, b.box_cols)
        end)

        it("creates a 4x4 board when requested", function()
            local b = SudokuBoard:new(getGridConfig("4x4"))
            assert.are.equal(4, b.n)
        end)

        it("starts with empty user grid", function()
            local b = SudokuBoard:new()
            for r = 1, b.n do
                for c = 1, b.n do
                    assert.are.equal(0, b.user[r][c])
                end
            end
        end)
    end)

    describe("generate", function()
        it("fills solution and creates a partial puzzle", function()
            math.randomseed(42)
            local b = SudokuBoard:new()
            b:generate("easy")
            for r = 1, b.n do
                for c = 1, b.n do
                    assert.is_true(b.solution[r][c] > 0,
                        ("solution[%d][%d] should be non-zero"):format(r, c))
                end
            end
        end)

        it("solution is a valid 9x9 sudoku (rows, cols)", function()
            math.randomseed(1)
            local b = SudokuBoard:new()
            b:generate("easy")
            local n = b.n
            for r = 1, n do
                local seen = {}
                for c = 1, n do seen[b.solution[r][c]] = true end
                for d = 1, n do assert.is_true(seen[d], "row " .. r .. " missing " .. d) end
            end
            for c = 1, n do
                local seen = {}
                for r = 1, n do seen[b.solution[r][c]] = true end
                for d = 1, n do assert.is_true(seen[d], "col " .. c .. " missing " .. d) end
            end
        end)
    end)

    describe("setValue / undo", function()
        local function solvedBoard()
            math.randomseed(42)
            local b = SudokuBoard:new(getGridConfig("4x4"))
            b:generate("easy")
            return b
        end

        local function firstFreeCell(b)
            for r = 1, b.n do
                for c = 1, b.n do
                    if not b:isGiven(r, c) then return r, c end
                end
            end
        end

        it("setValue writes to a free cell", function()
            local b = solvedBoard()
            local r, c = firstFreeCell(b)
            b:setSelection(r, c)
            assert.is_true(b:setValue(1))
            assert.are.equal(1, b.user[r][c])
        end)

        it("setValue rejects given cells", function()
            local b = solvedBoard()
            for r = 1, b.n do
                for c = 1, b.n do
                    if b:isGiven(r, c) then
                        b:setSelection(r, c)
                        local ok, reason = b:setValue(1)
                        assert.is_false(ok)
                        assert.is_not_nil(reason)
                        return
                    end
                end
            end
        end)

        it("undo restores previous value", function()
            local b = solvedBoard()
            local r, c = firstFreeCell(b)
            b:setSelection(r, c)
            b:setValue(1)
            assert.is_true(b:canUndo())
            b:undo()
            assert.are.equal(0, b.user[r][c])
        end)
    end)

    describe("isSolved", function()
        it("returns false before any user input", function()
            math.randomseed(42)
            local b = SudokuBoard:new(getGridConfig("4x4"))
            b:generate("easy")
            assert.is_false(b:isSolved())
        end)

        it("returns true when user matches solution", function()
            math.randomseed(42)
            local b = SudokuBoard:new(getGridConfig("4x4"))
            b:generate("easy")
            for r = 1, b.n do
                for c = 1, b.n do
                    if not b:isGiven(r, c) then
                        b.user[r][c] = b.solution[r][c]
                    end
                end
            end
            b:recalcConflicts()
            assert.is_true(b:isSolved())
        end)
    end)

    describe("serialize / load", function()
        it("round-trips board state", function()
            math.randomseed(42)
            local b = SudokuBoard:new(getGridConfig("4x4"))
            b:generate("easy")
            local r, c
            for rr = 1, b.n do
                for cc = 1, b.n do
                    if not b:isGiven(rr, cc) then r, c = rr, cc; break end
                end
                if r then break end
            end
            b:setSelection(r, c)
            b:setValue(2)
            local data = b:serialize()

            local b2 = SudokuBoard:new(getGridConfig("4x4"))
            assert.is_true(b2:load(data))
            assert.are.equal(b.n, b2.n)
            assert.are.equal(2, b2.user[r][c])
        end)

        it("load returns false for invalid data", function()
            local b = SudokuBoard:new()
            assert.is_false(b:load(nil))
            assert.is_false(b:load({}))
        end)
    end)
end)
