class_name Detection
extends RefCounted

# One detect mode session: the player guesses the elements of the unknown tiles in an area (the
# ring around them), Wordle-style. Guesses belong to a kind, so guessing for one tile guesses for
# every tile of its kind. Submitting scores each guessed kind: exactly its elements makes it known
# (TileGrid.set_kind_known, planet-wide); some of them, extras or not, makes its tiles partial
# until the next submit; none leaves them as they were.
#
# The elements to guess from are those on the area's unknown tiles when the session starts, in
# alphabetical order. Each stays in the list, but once no unknown tile in the area has it, it
# can't be guessed any more (is_available) and leftover guesses of it are dropped.

## Selection, guesses, or results changed.
signal changed

## Elements past this many in the list can't be guessed (one number key each).
const MAX_ELEMENTS := 10

var grid: TileGrid
## Stored copies of the area's coords.
var area: Array[Vector2i] = []
## The elements to guess from, alphabetical by display name.
var elements: Array[StringName] = []
## The tile guesses go to (a stored copy); starts on the area's first coord (the player's).
var selected: Vector2i
## Kind id -> guessed elements, in list order.
var guesses: Dictionary[StringName, Array] = {}
## Stored copies of the tiles the last submit found partly right.
var partial: Dictionary[Vector2i, bool] = {}


# p_area's first coord is selected to start with.
func _init(p_grid: TileGrid, p_area: Array[Vector2i]) -> void:
	grid = p_grid
	for c in p_area:
		area.append(grid.canonical(c))
	selected = area[0]
	for c in targets():
		for element in grid.get_tile(c).elements:
			if not element in elements:
				elements.append(element)
	elements.sort_custom(func(a: StringName, b: StringName) -> bool:
		return Items.display_name(a) < Items.display_name(b))


# Number key for the element at index in the list: 1-9, then 0.
static func number(index: int) -> int:
	return (index + 1) % 10


# The area's unknown tiles: the ones guesses can go to.
func targets() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(area.filter(func(c: Vector2i) -> bool: return grid.has_tile(c) and not grid.is_known(c)))
	return result


func is_target(coord: Vector2i) -> bool:
	return grid.canonical(coord) in targets()


func in_area(coord: Vector2i) -> bool:
	return grid.canonical(coord) in area


# Whether nothing's left to detect.
func is_done() -> bool:
	return targets().is_empty()


# Whether element can still be guessed: an unknown tile in the area has it.
func is_available(element: StringName) -> bool:
	return element in elements and targets().any(func(c: Vector2i) -> bool:
		return element in grid.get_tile(c).elements)


# Moves the selection to coord; false (no change) unless it's an unknown tile in the area.
func select(coord: Vector2i) -> bool:
	if not is_target(coord):
		return false
	selected = grid.canonical(coord)
	changed.emit()
	return true


# The elements guessed for the tile at coord, in list order.
func guessed(coord: Vector2i) -> Array[StringName]:
	var result: Array[StringName] = []
	if grid.has_tile(coord):
		result.assign(guesses.get(grid.get_tile(coord).id, []))
	return result


# Guesses the element at index in the list for the selected tile's kind, or takes that guess back.
# False (no change) if the selected tile is known or the element can't be guessed.
func toggle(index: int) -> bool:
	if index < 0 or index >= mini(elements.size(), MAX_ELEMENTS) or not is_target(selected):
		return false
	var element := elements[index]
	if not is_available(element):
		return false
	var kind := grid.get_tile(selected)
	var kind_guesses := guessed(selected)
	if element in kind_guesses:
		kind_guesses.erase(element)
	else:
		kind_guesses.append(element)
		kind_guesses.sort_custom(func(a: StringName, b: StringName) -> bool:
			return elements.find(a) < elements.find(b))
	if kind_guesses.is_empty():
		guesses.erase(kind.id)
	else:
		guesses[kind.id] = kind_guesses
	changed.emit()
	return true


func is_partial(coord: Vector2i) -> bool:
	return partial.has(grid.canonical(coord))


# Scores every guessed kind in the area (see the top). Returns the kinds it made known.
func submit() -> Array[TileKind]:
	partial.clear()
	var learned: Array[TileKind] = []
	var kinds: Array[TileKind] = []
	for c in targets():
		if not grid.get_tile(c) in kinds:
			kinds.append(grid.get_tile(c))
	for kind in kinds:
		var kind_guesses: Array = guesses.get(kind.id, [])
		var right := kind_guesses.filter(func(e: StringName) -> bool: return e in kind.elements)
		if right.size() == kind.elements.size() and kind_guesses.size() == right.size():
			learned.append(kind)
		elif not right.is_empty():
			for c in targets():
				if grid.get_tile(c) == kind:
					partial[c] = true
	for kind in learned:
		guesses.erase(kind.id)
		grid.set_kind_known(kind)
	# Guesses of elements nothing unknown has any more are wrong, and can't be taken back by hand.
	for id: StringName in guesses.keys():
		var kept: Array = guesses[id].filter(is_available)
		if kept.is_empty():
			guesses.erase(id)
		else:
			guesses[id] = kept
	changed.emit()
	return learned
