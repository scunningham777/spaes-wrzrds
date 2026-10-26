class_name TileGridView
extends Node2D

# Draws a TileGrid as filled hexes, ported from Unity's TileVisualManager/TileVisual. Must be a
# child of a HexBoard. Draws nothing until a grid is assigned. Every tile is a filled hex
# (hex_color, or ley_color where it resonates with a ley line or is on an activated one); kinds
# whose icon has an entry in ICONS draw that sprite-sheet icon over it. Icons with an entry in ICON_ANIMS step through it, all in sync off one clock. Tile size comes
# from the board's tile_scale. Tiles that cost aether to step onto show the cost as a number and
# a blue dot in their upper left; the landing tile is outlined. The occupied (player's) tile's icon
# sits higher, clear of the player's sprite.

## Sprite sheet that ICONS regions are cut from.
@export var icon_sheet: Texture2D
## Fill of every hex; opaque so icons keep their contrast.
@export var hex_color: Color = Color.BLACK
## Fill of tiles resonating with a ley line (LeyLines.is_resonant) or on an activated one
## (LeyLines.is_active). Deep plum: dark enough that light icons stand out, and a different hue
## from every icon so the dark ones (rust iron, green sapling, grey tower) do too.
@export var ley_color: Color = Color(0.38, 0.03, 0.41)
## Icon pixel scale; matches the wizard sprite's.
@export var icon_scale: float = 4.0
## How far up the icon of the tile the player stands on (occupied) moves, in pixels, to make room
## for the player's sprite below it.
@export var occupied_icon_shift: float = 8.0
## Play the ICON_ANIMS icon animations.
@export var animate_icons: bool = true
## Tapped-tile cooldown number size and color (yellow, to stand out from the white wizard).
@export var cooldown_font_size: int = 16
@export var cooldown_color: Color = Color(1.0, 0.8, 0.2)
## Move cost number size, and the dot beside it.
@export var move_cost_font_size: int = 14
@export var move_cost_dot_color: Color = Color(0.3, 0.6, 1.0)
@export var move_cost_dot_radius: float = 3.5
## Outline around the landing tile.
@export var landing_color: Color = Color(1.0, 0.85, 0.1)
@export var landing_line_width: float = 3.0
## Size of the landing outline relative to the tile.
@export var landing_inset: float = 0.88

# Tile pictures by TileKind.icon: regions in icon_sheet (12px cells, 1px gutters: cell (col, row)
# is at 1 + 13 * col/row).
const ICONS: Dictionary[StringName, Rect2] = {
	&"gold_ore": Rect2(105, 612, 12, 12),  # Cell (8, 47)
	&"water_spring": Rect2(378, 196, 12, 12),  # Cell (29, 15)
	&"iron_deposit": Rect2(378, 40, 12, 12),  # Cell (29, 3)
	&"sapling": Rect2(144, 118, 12, 12),  # Cell (11, 9)
	&"stone_outcrop": Rect2(92, 183, 12, 12),  # Cell (7, 14)
	&"basic_tower": Rect2(443, 508, 12, 12),  # Cell (34, 39)
}

# Per-icon animation: one channel stepped through `values`, `step` seconds per value.
# Channels: x / y (sprite pixels, y-down), scale_y (height factor), alpha, rotation (degrees,
# clockwise). Transforms pivot on the icon's bottom center.
const ICON_ANIMS: Dictionary[StringName, Dictionary] = {
	&"water_spring": {"channel": &"scale_y", "step": 0.75, "values": [1.0, 0.9]},
	&"iron_deposit": {"channel": &"scale_y", "step": 0.75, "values": [1.0, 0.9]},
	&"stone_outcrop": {"channel": &"scale_y", "step": 0.75, "values": [1.0, 0.9]},
	# Two quick flashes, then holds full alpha for the rest of the cycle.
	&"gold_ore": {"channel": &"alpha", "step": 0.2,
		"values": [0.7, 1.0, 0.7, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]},
	&"sapling": {"channel": &"rotation", "step": 0.75, "values": [0.0, 10.0, 0.0, -10.0]},
}

# Channel values when an icon has no animation for that channel.
const ANIM_DEFAULTS: Dictionary[StringName, float] = {
	&"x": 0.0, &"y": 0.0, &"scale_y": 1.0, &"alpha": 1.0, &"rotation": 0.0,
}

var grid: TileGrid:
	set(value):
		if grid != null and grid.tile_changed.is_connected(_on_tile_changed):
			grid.tile_changed.disconnect(_on_tile_changed)
			grid.tapped_changed.disconnect(_on_tapped_changed)
		grid = value
		if grid != null:
			grid.tile_changed.connect(_on_tile_changed)
			grid.tapped_changed.connect(_on_tapped_changed)
		queue_redraw()
## Where the view is looking from (the player's coord). On a wrapping grid each tile is drawn at
## its copy nearest here, so the map wraps around whoever is exploring it.
var view_center: Vector2i = Vector2i.ZERO:
	set(value):
		view_center = value
		queue_redraw()
## The planet's ley lines, or null if it has none.
var ley_lines: LeyLines:
	set(value):
		ley_lines = value
		queue_redraw()
## The tile the player landed on (outlined in landing_color), or null for none.
var landing: Variant = null:
	set(value):
		landing = value
		queue_redraw()
## The tile the player stands on (its icon moves up by occupied_icon_shift), or null for none.
var occupied: Variant = null:
	set(value):
		occupied = value
		queue_redraw()
## Seconds since the animations started.
var anim_time: float = 0.0
## 0..1 progress of the swap animation, if one is playing (see animate_swap).
var swap_progress: float = 1.0:
	set(value):
		swap_progress = value
		queue_redraw()

# Swap being animated: the grid already holds the swapped tiles, so the icon now at _swap_to
# is drawn travelling from _swap_from (on top), and the one now at _swap_from the other way.
var _swapping := false
var _swap_from: Vector2i
var _swap_to: Vector2i
# Greyscale copies of the icons, for tapped tiles; built on first use.
var _grey_icons: Dictionary[StringName, Texture2D] = {}

@onready var board: HexBoard = get_parent() as HexBoard


func has_icon(kind: TileKind) -> bool:
	return icon_sheet != null and ICONS.has(kind.icon)


# The kind's icon as a standalone texture (also for UI), greyscale if tapped; null if it has none.
func icon_texture(kind: TileKind, tapped: bool = false) -> Texture2D:
	if not has_icon(kind):
		return null
	if tapped:
		return _grey_icon(kind.icon)
	var atlas := AtlasTexture.new()
	atlas.atlas = icon_sheet
	atlas.region = ICONS[kind.icon]
	return atlas


func _grey_icon(icon: StringName) -> Texture2D:
	if not _grey_icons.has(icon):
		var image := icon_sheet.get_image()
		if image.is_compressed():
			image.decompress()
		image = image.get_region(Rect2i(ICONS[icon]))
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y)
				var lum := c.get_luminance()
				image.set_pixel(x, y, Color(lum, lum, lum, c.a))
		_grey_icons[icon] = ImageTexture.create_from_image(image)
	return _grey_icons[icon]


# Current value of one animation channel for an icon, or the channel's default.
func anim_value(icon: StringName, channel: StringName) -> float:
	var anim: Dictionary = ICON_ANIMS.get(icon, {})
	if not animate_icons or anim.get("channel") != channel:
		return ANIM_DEFAULTS[channel]
	var values: Array = anim["values"]
	return values[_anim_frame(anim)]


func _anim_frame(anim: Dictionary) -> int:
	var values: Array = anim["values"]
	return floori(anim_time / anim["step"]) % values.size()


func _process(delta: float) -> void:
	if not animate_icons:
		return
	var before := _anim_frames()
	anim_time += delta
	if _anim_frames() != before:
		queue_redraw()


func _anim_frames() -> Array[int]:
	var frames: Array[int] = []
	for anim: Dictionary in ICON_ANIMS.values():
		frames.append(_anim_frame(anim))
	return frames


# Animates the icons of two just-swapped tiles crossing over; the icon that left `from` draws on
# top. Returns the tween so callers can wait on it (e.g. ActionLock.run).
func animate_swap(from: Vector2i, to: Vector2i, seconds: float) -> Tween:
	_swapping = true
	_swap_from = from
	_swap_to = to
	swap_progress = 0.0
	var tween := create_tween()
	tween.tween_property(self, "swap_progress", 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(func() -> void:
		_swapping = false
		queue_redraw())
	return tween


func _on_tile_changed(_coord: Vector2i, _kind: TileKind) -> void:
	queue_redraw()


func _on_tapped_changed(_coord: Vector2i, _remaining: int) -> void:
	queue_redraw()


func _draw() -> void:
	if grid == null:
		return
	var tile := board.corner_points(board.tile_scale)
	tile.remove_at(tile.size() - 1)  # drop the closing point; polygons close themselves
	var swapping_keys := [grid.canonical(_swap_from), grid.canonical(_swap_to)] if _swapping else []
	for coord in grid.tiles:
		var center := board.hex_to_local(grid.nearest(coord, view_center))
		draw_set_transform(center)
		draw_colored_polygon(tile, fill_color(coord))
		draw_set_transform(Vector2.ZERO)
		if not coord in swapping_keys:
			_draw_contents(coord, center, icon_shift(coord))
	if _swapping:
		var from_pos := board.hex_to_local(_swap_from)
		var to_pos := board.hex_to_local(_swap_to)
		# The icon shift travels with the icon, so one leaving the player's tile eases back to center.
		var from_shift := icon_shift(_swap_from)
		var to_shift := icon_shift(_swap_to)
		# Last drawn is on top.
		_draw_contents(_swap_from, to_pos.lerp(from_pos, swap_progress), to_shift.lerp(from_shift, swap_progress))
		_draw_contents(_swap_to, from_pos.lerp(to_pos, swap_progress), from_shift.lerp(to_shift, swap_progress))
	if landing != null and grid.has_tile(landing):
		# Inset, so it still shows inside the player's outline while they stand on it.
		draw_set_transform(board.hex_to_local(grid.nearest(landing, view_center)))
		draw_polyline(board.corner_points(board.tile_scale * landing_inset), landing_color, landing_line_width)
		draw_set_transform(Vector2.ZERO)


# Hex fill for the tile at coord: resonant tiles stand out, everything else is hex_color. The ley
# lines themselves are never drawn.
func fill_color(coord: Vector2i) -> Color:
	if ley_lines != null and (ley_lines.is_active(coord) or ley_lines.is_resonant(grid, coord)):
		return ley_color
	return hex_color


# Offset of the icon on the tile at coord from the tile's center: up on the occupied tile, else none.
func icon_shift(coord: Vector2i) -> Vector2:
	if occupied != null and grid.canonical(coord) == grid.canonical(occupied):
		return Vector2(0.0, -occupied_icon_shift)
	return Vector2.ZERO


# Draws the icon (offset by icon_offset, and tapped cooldown) and move cost of the tile at coord,
# centered on center.
func _draw_contents(coord: Vector2i, center: Vector2, icon_offset: Vector2) -> void:
	var kind := grid.get_tile(coord)
	if has_icon(kind):
		var tapped := grid.is_tapped(coord)
		_draw_icon(kind.icon, center + icon_offset, tapped)
		if tapped:
			_draw_cooldown(grid.cooldown(coord), center)
	if grid.move_cost(coord) > 0:
		_draw_move_cost(grid.move_cost(coord), center)


# Tapped icons are greyscale and hold still.
func _draw_icon(icon: StringName, center: Vector2, tapped: bool) -> void:
	var region := ICONS[icon]
	var icon_size := region.size * icon_scale
	var anim := func(channel: StringName) -> float:
		return ANIM_DEFAULTS[channel] if tapped else anim_value(icon, channel)
	var shift := Vector2(anim.call(&"x"), anim.call(&"y")) * icon_scale
	var pivot := center + Vector2(0.0, icon_size.y / 2.0) + shift  # bottom center
	draw_set_transform(pivot, deg_to_rad(anim.call(&"rotation")), Vector2(1.0, anim.call(&"scale_y")))
	var rect := Rect2(Vector2(-icon_size.x / 2.0, -icon_size.y), icon_size)
	var modulate_color := Color(1.0, 1.0, 1.0, anim.call(&"alpha"))
	if tapped:
		draw_texture_rect(_grey_icon(icon), rect, false, modulate_color)
	else:
		draw_texture_rect_region(icon_sheet, rect, region, modulate_color)
	draw_set_transform(Vector2.ZERO)


# Half the drawn tile's width and height: corner radius across the pointed axis, edge radius
# across the flat one.
func _tile_half() -> Vector2:
	var radii := Vector2(board.layout.size, board.layout.inner_radius()) * board.tile_scale
	return Vector2(radii.y, radii.x) if board.pointy_top else radii


# Actions left, in the tile's lower left (mirroring the move cost above it): clear of the player's
# sprite and outline, and of facing triangles, which sit mid-edge.
func _draw_cooldown(remaining: int, center: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var half := _tile_half()
	var pos := center + Vector2(-0.63 * half.x, 0.70 * half.y)  # baseline start
	var text := str(remaining)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cooldown_font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, cooldown_font_size, cooldown_color)


# Cost number with a blue dot after it, in the tile's upper left.
func _draw_move_cost(cost: int, center: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var half := _tile_half()
	var text := str(cost)
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, move_cost_font_size).x
	var pos := center + Vector2(-0.63 * half.x, -0.38 * half.y)  # baseline start
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, move_cost_font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, move_cost_font_size, Color.WHITE)
	var dot := pos + Vector2(text_width + move_cost_dot_radius + 2.0, -font.get_ascent(move_cost_font_size) * 0.35)
	draw_circle(dot, move_cost_dot_radius + 1.5, Color.BLACK)
	draw_circle(dot, move_cost_dot_radius, move_cost_dot_color)
