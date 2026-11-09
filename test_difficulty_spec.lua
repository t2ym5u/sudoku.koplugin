-- Difficulty guarantees of the grids this game deals, through its own
-- board.lua (docs/dev/TESTING.md, "Difficulty specs"): for each size and
-- level, on fixed seeds, the grid builds in reasonable time, has one
-- solution, and sudoku-common's logic_solver finishes it by deduction alone
-- (it has no trial step) within the level's technique tier; Easy needs only
-- the singles; the levels are distinct and in order on averages; a seed
-- gives the same grid, and generation never reads the clock.
-- sudoku-common/test_difficulty_floor_spec.lua covers the generator itself.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.preload["gettext"] = function()
    return setmetatable({}, { __call = function(_, s) return s end })
end
package.path = DIR .. "common/?.lua;" .. DIR .. "?.lua;" .. package.path

local Mod = assert(loadfile(DIR .. "board.lua"))()
local LS  = require("logic_solver")
local PG  = require("puzzle_generator")

-- ---------------------------------------------------------------------------
-- What this game offers
-- ---------------------------------------------------------------------------

local GAME   = "Sudoku"
local LEVELS = { "easy", "medium", "hard", "expert" }
-- seeds per level; max_secs is a generous bound for plain Lua 5.5 with the
-- bit shim (the worst grid measured 2026-11-09 is ~10x below it).
local SHAPES = {
    { id = "4x4",   seeds = 6, max_secs = 2 },
    { id = "6x6",   seeds = 6, max_secs = 2 },
    { id = "9x9",   seeds = 8, max_secs = 6 },
    { id = "12x12", seeds = 3, max_secs = 15 },
    { id = "16x16", seeds = 4, max_secs = 30 },
}
local function newBoard(shape)
    return Mod.SudokuBoard:new(Mod.getGridConfig(shape.id))
end
-- Board fields besides the digits that a seed must reproduce.
local DECOR = {}
-- Level pairs known not to separate: "<size> <lower><<upper>" -> finding.
local KNOWN = {
    -- Up to sudoku-common 1.9.0, 16x16 Expert dealt the very same grids as
    -- Hard (0 cells differed on 4/4 seeds); 1.10.0 stops 16x16 Hard earlier.
}

-- ---------------------------------------------------------------------------

local function lcg(seed)
    local state = seed
    return function(i)
        state = (1103515245 * state + 12345) % 2147483648
        return state % i + 1
    end
end

local function extraRegions(b)
    return b.getExtraRegions and b:getExtraRegions() or nil
end

local runs = {}
local function run(shape, level)
    local key = shape.id .. " " .. level
    if runs[key] then return runs[key] end
    local out = {}
    for seed = 1, shape.seeds do
        math.randomseed(seed)
        local b = newBoard(shape)
        local t0 = os.clock()
        b:generate(level, lcg(seed * 7919 + 11))
        local secs = os.clock() - t0
        local res = LS.solve(b.puzzle, b.n, b.box_rows, b.box_cols, extraRegions(b),
                             { max_tier = LS.DIFFICULTY_TIER[level] })
        local clues = 0
        for r = 1, b.n do
            for c = 1, b.n do
                if b.puzzle[r][c] ~= 0 then clues = clues + 1 end
            end
        end
        out[#out + 1] = { b = b, res = res, steps = PG.nonSingleSteps(res.counts),
                          clues = clues, secs = secs }
    end
    runs[key] = out
    return out
end

local function averages(shape, level)
    local steps, clues = 0, 0
    local gs = run(shape, level)
    for _, g in ipairs(gs) do
        steps, clues = steps + g.steps, clues + g.clues
    end
    return steps / #gs, clues / #gs
end

describe(GAME .. " difficulty", function()

    it("rates its levels with rising technique tiers and dig ratios", function()
        for i = 2, #LEVELS do
            local lo, hi = LEVELS[i - 1], LEVELS[i]
            assert.is_true(LS.DIFFICULTY_TIER[hi] > LS.DIFFICULTY_TIER[lo], lo .. " < " .. hi)
            -- nil = no ratio cap (dig as deep as logic allows): last level only.
            assert.is_not_nil(PG.DIG_RATIOS[lo])
            if PG.DIG_RATIOS[hi] then
                assert.is_true(PG.DIG_RATIOS[hi] > PG.DIG_RATIOS[lo], lo .. " < " .. hi)
            end
        end
    end)

    for _, shape in ipairs(SHAPES) do
        for _, level in ipairs(LEVELS) do
            it(shape.id .. " " .. level .. ": builds in time, one solution, pure logic within its tier",
               function()
                for _, g in ipairs(run(shape, level)) do
                    local b, res = g.b, g.res
                    assert.is_true(g.secs < shape.max_secs, ("took %.2f s"):format(g.secs))
                    assert.is_true(res.solved, "logic_solver stuck")
                    assert.are.same(b.solution, res.grid)
                    assert.is_true(res.max_tier <= LS.DIFFICULTY_TIER[level])
                    for r = 1, b.n do
                        for c = 1, b.n do
                            if b.puzzle[r][c] ~= 0 then
                                assert.are.equal(b.solution[r][c], b.puzzle[r][c])
                            end
                        end
                    end
                    -- Deduction alone implies one solution; count it outright
                    -- where that is cheap (the counter's slow path for extra
                    -- regions takes minutes on some Expert grids).
                    if b.n <= 9 and not extraRegions(b) then
                        assert.are.equal(1, PG.countSolutions(b.puzzle, 2, b.n, b.box_rows,
                                                              b.box_cols, extraRegions(b)))
                    end
                end
            end)
        end

        it(shape.id .. " easy needs only the singles", function()
            for _, g in ipairs(run(shape, "easy")) do
                assert.is_true(g.res.max_tier <= LS.TIER.SINGLES)
                assert.are.equal(0, g.steps)
            end
        end)

        local floored = newBoard(shape).n >= PG.FLOOR_MIN_N
        for i = 2, #LEVELS do
            local lo, hi = LEVELS[i - 1], LEVELS[i]
            local key = shape.id .. " " .. lo .. "<" .. hi
            local body = function()
                local lo_steps, lo_clues = averages(shape, lo)
                local hi_steps, hi_clues = averages(shape, hi)
                local msg = ("%s steps %.2f -> %.2f, clues %.2f -> %.2f")
                    :format(key, lo_steps, hi_steps, lo_clues, hi_clues)
                assert.is_true(hi_clues < lo_clues, msg)
                -- 4x4 and 6x6 have no room past the singles: clues only.
                if floored then assert.is_true(hi_steps > lo_steps, msg) end
            end
            local name = shape.id .. " " .. hi .. " is harder than " .. lo .. " on average"
            if KNOWN[key] then
                pending(name .. " -- " .. KNOWN[key], body)
            else
                it(name, body)
            end
        end

        if floored then
            it(shape.id .. " medium and up meet their floor past the singles on most grids", function()
                for i = 2, #LEVELS do
                    local floor, met, gs = PG.FLOORS[LEVELS[i]], 0, run(shape, LEVELS[i])
                    for _, g in ipairs(gs) do
                        if g.steps >= floor.steps
                            or (floor.or_tier and g.res.max_tier >= floor.or_tier) then
                            met = met + 1
                        end
                        -- Even a miss is never a grid the singles finish alone.
                        assert.is_true(g.steps >= 1, LEVELS[i] .. " grid needs only singles")
                    end
                    assert.is_true(met >= #gs * 0.5, LEVELS[i] .. ": floor met " .. met .. "/" .. #gs)
                end
            end)
        end
    end

    it("deals the same grid for the same seed, without reading the clock", function()
        local clock, time = os.clock, os.time
        local ok, err = pcall(function()
            os.clock = function() error("generation read os.clock") end
            os.time  = function() error("generation read os.time") end
            local shape = SHAPES[1]
            for _, s in ipairs(SHAPES) do
                if s.id == "9x9" then shape = s end
            end
            for _, level in ipairs(LEVELS) do
                for seed = 101, 102 do
                    local a, b = newBoard(shape), newBoard(shape)
                    math.randomseed(seed)
                    a:generate(level, lcg(seed))
                    math.randomseed(seed)
                    b:generate(level, lcg(seed))
                    assert.are.same(a.puzzle, b.puzzle)
                    assert.are.same(a.solution, b.solution)
                    for _, field in ipairs(DECOR) do
                        assert.are.same(a[field], b[field])
                    end
                    -- The digits depend on the seed alone, not on math.random's
                    -- state (the Daily Challenge passes its own seed).
                    local c = newBoard(shape)
                    math.randomseed(seed + 5000)
                    c:generate(level, lcg(seed))
                    assert.are.same(a.puzzle, c.puzzle)
                    assert.are.same(a.solution, c.solution)
                end
            end
        end)
        os.clock, os.time = clock, time
        assert.is_true(ok, err)
    end)
end)
