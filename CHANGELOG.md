# Changelog

All notable changes to this project will be documented in this file.

## [2.2.1] - 2026-07-15

### Fixed
- `require("grid_utils")` collided with the unrelated `grid_utils` module
  used by other game plugins sharing the same Lua VM, which could make the
  plugin fail to load depending on plugin load order. Renamed the shared
  module to `sudoku_grid_utils`.

## [2.2.0] - 2026-07-13

### Added
- "Expert" difficulty tier (~23-25 givens on 9×9), scaled proportionally for
  other grid sizes.

## [2.1.0] - 2026-07-08

### Added
- FR/EN translation via shared `i18n` module: buttons, menus, and status messages
  now appear in French when KOReader language is set to French.

## [2.0.0] - 2026-02-18

### Added
- Grid size selection: 4×4, 6×6, 9×9, 12×12 and 16×16 in a single plugin
- Landscape orientation: keypad and action buttons displayed to the right of the grid
- Digit buttons are greyed out and disabled when all instances of a digit are placed
- Code split into logical modules: `board.lua`, `board_widget.lua`, `screen.lua`


## [1.2.1]

### Fixed
- Notes overlap issue

## [1.2.0]

### Added
- Note mode improvements

## [1.1.0]

### Added
- Undo button

## [1.0.1]

### Fixed
- Selected row is darker; pins are bigger

## [1.0.0]

- Initial release
