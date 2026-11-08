class_name LightTextures
extends RefCounted
## Texturas de luz generadas en código y comprobación de línea de visión.
## La intensidad se corta en 5 escalones para que la luz encaje con el pixel art.

const WALL_MASK := 1
const BANDS := 5.0

static var _cache := {}


## Cono que apunta hacia la derecha (+X) desde el centro de la textura.
static func cone(length: float, angle_deg: float) -> ImageTexture:
	var key := "cone_%d_%d" % [int(length), int(angle_deg)]
	if _cache.has(key):
		return _cache[key]
	var size := int(length) * 2
	var center := size / 2.0
	var half := deg_to_rad(angle_deg) / 2.0
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var v := Vector2(x + 0.5 - center, y + 0.5 - center)
			var d := v.length()
			var a := 0.0
			if d < length:
				var edge := clampf((half - absf(v.angle())) / (half * 0.35), 0.0, 1.0)
				a = pow(1.0 - d / length, 0.7) * edge
			# Pequeño halo alrededor de la bombilla.
			a = maxf(a, clampf(1.0 - d / 10.0, 0.0, 1.0) * 0.6)
			img.set_pixel(x, y, Color(1, 1, 1, ceilf(a * BANDS) / BANDS))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func radial(radius: float) -> ImageTexture:
	var key := "radial_%d" % int(radius)
	if _cache.has(key):
		return _cache[key]
	var size := int(radius) * 2
	var center := size / 2.0
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - center, y + 0.5 - center).length()
			var a := pow(clampf(1.0 - d / radius, 0.0, 1.0), 0.8)
			img.set_pixel(x, y, Color(1, 1, 1, ceilf(a * BANDS) / BANDS))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## True si ninguna pared corta el segmento entre los dos puntos.
static func has_line_of_sight(world: World2D, from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, WALL_MASK)
	return world.direct_space_state.intersect_ray(query).is_empty()
