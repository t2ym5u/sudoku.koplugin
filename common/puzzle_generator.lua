local grid_utils = require("sudoku_grid_utils")
local emptyGrid  = grid_utils.emptyGrid
local copyGrid   = grid_utils.copyGrid

local bit    = require("bit")
local bor    = bit.bor
local band   = bit.band
local bnot   = bit.bnot
local lshift = bit.lshift

local function shuffledDigits(n)
    local digits = {}
    for i = 1, n do digits[i] = i end
    for i = n, 2, -1 do
        local j = math.random(i)
        digits[i], digits[j] = digits[j], digits[i]
    end
    return digits
end

-- Build a valid solved grid using the cyclic-shift formula, then randomise it
-- with band/stack/row/col permutations and digit relabelling.  O(n²), no backtracking.
--
-- Formula: grid[r][c] = (box_cols*(r-1 mod box_rows) + floor((r-1)/box_rows) + (c-1)) mod n + 1
-- This is a valid Latin square that also satisfies all box constraints.
local function generateSolvedBoard(n, box_rows, box_cols)
    local num_bands  = n / box_rows   -- number of row bands
    local num_stacks = n / box_cols   -- number of col stacks

    -- Step 1: construct the base grid
    local grid = emptyGrid(n)
    for r = 1, n do
        local k        = (r - 1) % box_rows
        local band_idx = math.floor((r - 1) / box_rows)
        for c = 1, n do
            grid[r][c] = (box_cols * k + band_idx + c - 1) % n + 1
        end
    end

    -- Step 2: shuffle band order
    local band_ord = {}
    for i = 1, num_bands do band_ord[i] = i end
    for i = num_bands, 2, -1 do
        local j = math.random(i)
        band_ord[i], band_ord[j] = band_ord[j], band_ord[i]
    end

    -- Step 3: shuffle rows within each band
    local row_perm = {}
    for bi = 1, num_bands do
        local w = {}
        for i = 1, box_rows do w[i] = i end
        for i = box_rows, 2, -1 do
            local j = math.random(i)
            w[i], w[j] = w[j], w[i]
        end
        local base = (band_ord[bi] - 1) * box_rows
        for i = 1, box_rows do
            row_perm[(bi - 1) * box_rows + i] = base + w[i]
        end
    end

    -- Step 4: shuffle stack order
    local stack_ord = {}
    for i = 1, num_stacks do stack_ord[i] = i end
    for i = num_stacks, 2, -1 do
        local j = math.random(i)
        stack_ord[i], stack_ord[j] = stack_ord[j], stack_ord[i]
    end

    -- Step 5: shuffle cols within each stack
    local col_perm = {}
    for si = 1, num_stacks do
        local w = {}
        for i = 1, box_cols do w[i] = i end
        for i = box_cols, 2, -1 do
            local j = math.random(i)
            w[i], w[j] = w[j], w[i]
        end
        local base = (stack_ord[si] - 1) * box_cols
        for i = 1, box_cols do
            col_perm[(si - 1) * box_cols + i] = base + w[i]
        end
    end

    -- Step 6: random digit relabelling
    local digit_map = shuffledDigits(n)

    -- Step 7: apply all permutations
    local out = emptyGrid(n)
    for r = 1, n do
        local src_r = row_perm[r]
        for c = 1, n do
            out[r][c] = digit_map[grid[src_r][col_perm[c]]]
        end
    end
    return out
end

-- Bitset backtracking solver with MRV (minimum remaining values) heuristic.
-- Does NOT modify grid; returns the number of solutions found (stops at limit).
local function countSolutions(grid, limit, n, box_rows, box_cols)
    local num_stacks = n / box_cols
    local full_mask  = lshift(1, n) - 1

    -- Build constraint bitmasks and collect empty cells
    local row_used = {}
    local col_used = {}
    local box_used = {}
    for i = 1, n do
        row_used[i] = 0
        col_used[i] = 0
        box_used[i] = 0
    end

    local cells = {}
    for r = 1, n do
        local band_base = math.floor((r - 1) / box_rows) * num_stacks
        for c = 1, n do
            local b = band_base + math.floor((c - 1) / box_cols) + 1
            local v = grid[r][c]
            if v ~= 0 then
                local m = lshift(1, v - 1)
                row_used[r] = bor(row_used[r], m)
                col_used[c] = bor(col_used[c], m)
                box_used[b] = bor(box_used[b], m)
            else
                cells[#cells + 1] = { r = r, c = c, b = b }
            end
        end
    end

    local total     = #cells
    local solutions = 0

    local function search(depth)
        if solutions >= limit then return end
        if depth > total then
            solutions = solutions + 1
            return
        end

        -- MRV: pick the empty cell with the fewest legal values
        local best, best_cnt = depth, n + 1
        for i = depth, total do
            local cell = cells[i]
            local free = band(bnot(bor(bor(row_used[cell.r], col_used[cell.c]), box_used[cell.b])), full_mask)
            -- popcount via kernighan bit trick
            local cnt, x = 0, free
            while x > 0 do x = band(x, x - 1); cnt = cnt + 1 end
            if cnt < best_cnt then
                best_cnt = cnt
                best = i
                if cnt == 0 then break end
            end
        end

        if best_cnt == 0 then return end

        cells[depth], cells[best] = cells[best], cells[depth]
        local cell = cells[depth]
        local r, c, b = cell.r, cell.c, cell.b

        local free = band(bnot(bor(bor(row_used[r], col_used[c]), box_used[b])), full_mask)

        while free ~= 0 do
            local m = band(free, -free)          -- isolate lowest set bit
            row_used[r] = bor(row_used[r], m)
            col_used[c] = bor(col_used[c], m)
            box_used[b] = bor(box_used[b], m)

            search(depth + 1)

            row_used[r] = band(row_used[r], bnot(m))
            col_used[c] = band(col_used[c], bnot(m))
            box_used[b] = band(box_used[b], bnot(m))

            free = band(free, free - 1)          -- clear lowest set bit
            if solutions >= limit then break end
        end

        cells[depth], cells[best] = cells[best], cells[depth]
    end

    search(1)
    return solutions
end

-- countSolutions does not modify the grid, so no copy is needed inside the loop.
local function createPuzzle(solved_grid, difficulty, n, box_rows, box_cols)
    local puzzle  = copyGrid(solved_grid, n)
    local total   = n * n
    local ratios  = { easy = 0.43, medium = 0.56, hard = 0.65, expert = 0.72 }
    local ratio   = ratios[difficulty] or ratios.medium
    local removals = math.floor(total * ratio)

    local cells = {}
    for r = 1, n do
        for c = 1, n do cells[#cells + 1] = { r = r, c = c } end
    end
    for i = #cells, 2, -1 do
        local j = math.random(i)
        cells[i], cells[j] = cells[j], cells[i]
    end

    local removed = 0
    for _, cell in ipairs(cells) do
        if removed >= removals then break end
        local row, col = cell.r, cell.c
        if puzzle[row][col] ~= 0 then
            local backup = puzzle[row][col]
            puzzle[row][col] = 0
            if countSolutions(puzzle, 2, n, box_rows, box_cols) == 1 then
                removed = removed + 1
            else
                puzzle[row][col] = backup
            end
        end
    end
    return puzzle
end

return {
    generateSolvedBoard = generateSolvedBoard,
    countSolutions      = countSolutions,
    createPuzzle        = createPuzzle,
}
