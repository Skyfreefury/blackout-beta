class_name ShopCounter
extends Node2D
## Mostrador de la sala tienda (maps/shop.txt, símbolo K). Muestra un objeto de Shop sobre la
## mesa con su precio encima. Con el jugador cerca se ve también el nombre. E compra (Player).

## Distancia desde el centro del mostrador a la que E compra.
const RANGE := 24.0
const ICONS := {
	"battery": preload("res://art/sprites/shop_battery.png"),
	"shoes": preload("res://art/sprites/shop_shoes.png"),
	"bag": preload("res://art/sprites/shop_bag.png"),
	"medkit": preload("res://art/sprites/shop_medkit.png"),
	"dart": preload("res://art/sprites/shop_dart.png"),
}
const PRICE_COLOR := Color("e8c547")
const NO_MONEY_COLOR := Color("8f3a3a")
const DONE_COLOR := Color("6b7d6a")

var item := ""

var _icon := Sprite2D.new()
var _price := Label.new()
var _name := Label.new()
var _bounce := 0.0


func _ready() -> void:
	add_to_group("shop_counters")
	_icon.texture = ICONS.get(item)
	_icon.position = Vector2(0, -4)
	add_child(_icon)
	var glow := PointLight2D.new()
	glow.texture = LightTextures.radial(20.0)
	glow.color = Color(1.0, 0.9, 0.7)
	glow.energy = 0.7
	add_child(glow)
	for label in [_price, _name]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(80, 10)
		label.add_theme_font_size_override("font_size", 8)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(label)
	_price.position = Vector2(-40, -22)
	_name.position = Vector2(-40, 8)
	_name.add_theme_color_override("font_color", Color("c9d1d3"))
	Net.shop_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	_bounce = maxf(_bounce - delta * 4.0, 0.0)
	_icon.position.y = -4.0 - sin(_bounce * PI) * 4.0
	var near := false
	for p: Player in get_tree().get_nodes_in_group("players"):
		if p.is_local() and p.global_position.distance_to(global_position) <= RANGE:
			near = true
	_name.visible = near


## Lo llama el jugador local con E. Compra si hay banco; el anfitrión confirma la compra.
func buy() -> void:
	var id := multiplayer.get_unique_id()
	var owned := Net.upgrade_level(id, item)
	if owned >= Shop.ITEMS[item].max or Net.bank < Shop.price(item, owned):
		Sfx.play_ui("ui_click", -6.0)
		return
	Net.buy(item)
	Sfx.play_ui("battery")
	_bounce = 1.0


func _refresh() -> void:
	var id := multiplayer.get_unique_id()
	var owned := Net.upgrade_level(id, item)
	var top: int = Shop.ITEMS[item].max
	var cost := Shop.price(item, owned)
	_name.text = "%s %d/%d  E comprar" % [Shop.ITEMS[item].name, owned, top]
	if owned >= top:
		_price.text = "Completo"
		_price.add_theme_color_override("font_color", DONE_COLOR)
	else:
		_price.text = "%d €" % cost
		_price.add_theme_color_override("font_color", PRICE_COLOR if Net.bank >= cost else NO_MONEY_COLOR)
