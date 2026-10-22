class_name TileGridView
extends Node2D

# Draws a TileGrid as filled hexes, ported from Unity's TileVisualManager/TileVisual. Must be a
# child of a HexBoard. Draws nothing until a grid is assigned. Types with an entry in TILE_ICONS
# draw that sprite-sheet icon over an Empty-colored hex; the rest are plain colored hexes. Icons
# with an entry in TILE_ANIMS step through it, all in sync off one clock.

## Tile size relative to the hex cell; < 1 leaves gaps between tiles (Unity's sprite was 1/1.1).
@export var tile_scale: float = 1.0 / 1.1
## Sprite sheet that TILE_ICONS regions are cut from.
@export var icon_sheet: Texture2D
## Icon pixel scale; matches the wizard sprite's.
@export var icon_scale: float = 4.0
## Play the TILE_ANIMS icon animations.
@export var animate_icons: bool = true
## Tapped-tile cooldown number size, and its baseline's distance above the tile's bottom edge.
@export var cooldown_font_size: int = 16
@export var cooldown_margin: float = 6.0

# Colors from Unity's TileVisual.GetColorForType.
const TILE_COLORS: Dictionary[TileGrid.TileType, Color] = {
	TileGrid.TileType.EMPTY: Color.BLACK,  # Opaque so icons keep their contrast
	TileGrid.TileType.GOLD_ORE: Color(1.0, 0.84, 0.0),  # Gold
	TileGrid.TileType.WATER_SPRING: Color(0.3, 0.6, 1.0),  # Blue
	TileGrid.TileType.IRON_DEPOSIT: Color(0.65, 0.35, 0.3),  # Rust
	TileGrid.TileType.TIMBER: Color(0.4, 0.6, 0.3),  # Green-brown
	TileGrid.TileType.STONE_OUTCROP: Color(0.6, 0.6, 0.6),  # Gray
}

# Regions in icon_sheet (12px cells, 1px gutters: cell (col, row) is at 1 + 13 * col/row).
const TILE_ICONS: Dictionary[TileGrid.TileType, Rect2] = {
	TileGrid.TileType.GOLD_ORE: Rect2(105, 612, 12, 12),  # Cell (8, 47)
	TileGrid.TileType.WATER_SPRING: Rect2(378, 196, 12, 12),  # Cell (29, 15)
	TileGrid.TileType.IRON_DEPOSIT: Rect2(378, 40, 12, 12),  # Cell (29, 3)
	TileGrid.TileType.TIMBER: Rect2(144, 118, 12, 12),  # Cell (11, 9): sapling
	TileGrid.TileType.STONE_OUTCROP: Rect2(92, 183, 12, 12),  # Cell (7, 14)
}

# Per-type icon animation: one channel stepped through `values`, `step` seconds per value.
# Channels: x / y (sprite pixels, y-down), scale_y (height factor), alpha, rotation (degrees,
# clockwise). Transforms pivot on the icon's bottom center.
const TILE_ANIMS: Dictionary[TileGrid.TileType, Dictionary] = {
	TileGrid.TileType.WATER_SPRING: {"channel": &"y", "step": 0.5, "values": [0.0, -1.0, 0.0, 1.0]},
	TileGrid.TileType.IRON_DEPOSIT: {"channel": &"x", "step": 0.5, "values": [0.0, 1.0, 0.0, -1.0]},
	TileGrid.TileType.STONE_OUTCROP: {"channel": &"scale_y", "step": 0.5, "values": [1.0, 0.9]},
	# Two quick flashes, then full alpha for the last 0.5 s.
	TileGrid.TileType.GOLD_ORE: {"channel": &"alpha", "step": 0.125,
		"values": [0.3, 1.0, 0.3, 1.0, 1.0, 1.0, 1.0, 1.0]},
	TileGrid.TileType.TIMBER: {"channel": &"rotation", "step": 0.5, "values": [0.0, 10.0, 0.0, -10.0]},
}

# Channel values when a type has no animation for that channel.
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
var _grey_icons: Dictionary[TileGrid.TileType, Texture2D] = {}

@onready var board: HexBoard = get_parent() as HexBoard


func has_icon(type: TileGrid.TileType) -> bool:
	return icon_sheet != null and TILE_ICONS.has(type)


# The type's icon as a standalone texture (also for UI), greyscale if tapped; null if it has none.
func icon_texture(type: TileGrid.TileType, tapped: bool = false) -> Texture2D:
	if not has_icon(type):
		return null
	if tapped:
		return _grey_icon(type)
	var atlas := AtlasTexture.new()
	atlas.atlas = icon_sheet
	atlas.region = TILE_ICONS[type]
	return atlas


func _grey_icon(type: TileGrid.TileType) -> Texture2D:
	if not _grey_icons.has(type):
		var image := icon_sheet.get_image()
		if image.is_compressed():
			image.decompress()
		image = image.get_region(Rect2i(TILE_ICONS[type]))
		for y in image.get_height():
			for x in image.get_width():
				var c := image.get_pixel(x, y)
				var lum := c.get_luminance()
				image.set_pixel(x, y, Color(lum, lum, lum, c.a))
		_grey_icons[type] = ImageTexture.create_from_image(image)
	return _grey_icons[type]


# Hex fill color; icon tiles sit on the Empty color so the icon stands out.
func color_for(type: TileGrid.TileType) -> Color:
	if has_icon(type):
		return TILE_COLORS[TileGrid.TileType.EMPTY]
	return TILE_COLORS.get(type, Color.WHITE)


# Current value of one animation channel for a type, or the channel's default.
func anim_value(type: TileGrid.TileType, channel: StringName) -> float:
	var anim: Dictionary = TILE_ANIMS.get(type, {})
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
	for anim: Dictionary in TILE_ANIMS.values():
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


func _on_tile_changed(_coord: Vector2i, _type: TileGrid.TileType) -> void:
	queue_redraw()


func _on_tapped_changed(_coord: Vector2i, _remaining: int) -> void:
	queue_redraw()


func _draw() -> void:
	if grid == null:
		return
	var corners := board.layout.corner_offsets()
	var tile := PackedVector2Array()
	for i in corners.size() - 1:  # drop the closing point; polygons close themselves
		tile.append(Vector2(corners[i].x, -corners[i].y) * tile_scale)
	for coord in grid.tiles:
		var center := board.hex_to_local(coord)
		var points := PackedVector2Array()
		for p in tile:
			points.append(center + p)
		var type := grid.get_tile(coord)
		draw_colored_polygon(points, color_for(type))
		if not (_swapping and (coord == _swap_from or coord == _swap_to)):
			_draw_contents(coord, center)
	if _swapping:
		var from_pos := board.hex_to_local(_swap_from)
		var to_pos := board.hex_to_local(_swap_to)
		# Last drawn is on top.
		_draw_contents(_swap_from, to_pos.lerp(from_pos, swap_progress))
		_draw_contents(_swap_to, from_pos.lerp(to_pos, swap_progress))


# Draws the icon (and tapped cooldown) of the tile at coord, centered on center.
func _draw_contents(coord: Vector2i, center: Vector2) -> void:
	var type := grid.get_tile(coord)
	if not has_icon(type):
		return
	var tapped := grid.is_tapped(coord)
	_draw_icon(type, center, tapped)
	if tapped:
		_draw_cooldown(grid.cooldown(coord), center)


# Tapped icons are greyscale and hold still.
func _draw_icon(type: TileGrid.TileType, center: Vector2, tapped: bool) -> void:
	var region := TILE_ICONS[type]
	var icon_size := region.size * icon_scale
	var anim := func(channel: StringName) -> float:
		return ANIM_DEFAULTS[channel] if tapped else anim_value(type, channel)
	var shift := Vector2(anim.call(&"x"), anim.call(&"y")) * icon_scale
	var pivot := center + Vector2(0.0, icon_size.y / 2.0) + shift  # bottom center
	draw_set_transform(pivot, deg_to_rad(anim.call(&"rotation")), Vector2(1.0, anim.call(&"scale_y")))
	var rect := Rect2(Vector2(-icon_size.x / 2.0, -icon_size.y), icon_size)
	var modulate_color := Color(1.0, 1.0, 1.0, anim.call(&"alpha"))
	if tapped:
		draw_texture_rect(_grey_icon(type), rect, false, modulate_color)
	else:
		draw_texture_rect_region(icon_sheet, rect, region, modulate_color)
	draw_set_transform(Vector2.ZERO)


# Actions left, centered just inside the bottom edge: clear of the player outline and of a
# facing triangle poking in from the hex below.
func _draw_cooldown(remaining: int, center: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var width := board.layout.size * 2.0
	var baseline := center.y + board.layout.size * HexLayout.SQRT_3 / 2.0 * tile_scale - cooldown_margin
	var pos := Vector2(center.x - width / 2.0, baseline)
	var text := str(remaining)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, cooldown_font_size, 4, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, cooldown_font_size, Color.WHITE)
