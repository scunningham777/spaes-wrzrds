class_name TileGrid
extends RefCounted

# Hexagon-shaped board of tiles, ported from Unity's TileExplore.TileGridManager. Only Empty
# tiles exist for now; Unity's resource types (gold ore, water spring, ...) come later.

enum TileType { EMPTY }

var radius: int
var tiles: Dictionary[Vector2i, TileType] = {}


func _init(p_radius: int = 5) -> void:
	radius = p_radius
	for coord in Hex.hexagon(radius):
		tiles[coord] = TileType.EMPTY


func has_tile(coord: Vector2i) -> bool:
	return tiles.has(coord)


func get_tile(coord: Vector2i) -> TileType:
	return tiles[coord]
