extends RefCounted
## Geometry and index ranges shared by simulation, tools, soil and UI.
const MAIN_COLUMNS := 7
const MAIN_ROWS := 7
const MAIN_COUNT := MAIN_COLUMNS * MAIN_ROWS
const EXTENDED_COLUMNS := 12
const EXTENDED_ROWS := 4
const EXTENDED_COUNT := EXTENDED_COLUMNS * EXTENDED_ROWS
const TOTAL := MAIN_COUNT + EXTENDED_COUNT
const MAIN_ORIGIN := Vector2(2710,1731)
const MAIN_STEP := Vector2(42,36)
const EXTENDED_ORIGIN := Vector2(2020,3152)
const EXTENDED_STEP := Vector2(43,39)

static func columns(index: int) -> int:
	return MAIN_COLUMNS if index < MAIN_COUNT else EXTENDED_COLUMNS

static func first(index: int) -> int:
	return 0 if index < MAIN_COUNT else MAIN_COUNT

static func end(index: int) -> int:
	return MAIN_COUNT if index < MAIN_COUNT else TOTAL

static func step(index: int) -> Vector2:
	return MAIN_STEP if index < MAIN_COUNT else EXTENDED_STEP

static func position(index: int) -> Vector2:
	var local := index - first(index)
	var width := columns(index)
	var origin := MAIN_ORIGIN if index < MAIN_COUNT else EXTENDED_ORIGIN
	return origin + Vector2(local % width,int(local / width)) * step(index)
