class_name Roles
## Roles del cooperativo. Cada uno multiplica unos valores base del jugador:
## una ventaja y una desventaja. Un multiplicador que falta vale 1.

const NURSE := 0
const RUNNER := 1
const TECHNICIAN := 2
const LOOKOUT := 3

const LIST := [
	{
		"name": "Enfermero/a",
		"pro": "Reanima un 50% más rápido",
		"con": "20% menos de batería",
		"revive": 1.5,
		"battery": 0.8,
	},
	{
		"name": "Corredor/a",
		"pro": "Corre un 20% más rápido y aguanta un 25% más",
		"con": "Hace ruido: el Nonato le prefiere",
		"run": 1.2,
		"stamina": 1.25,
		# El monstruo ve a este jugador a un 60% de su distancia real al elegir presa.
		"lure": 0.6,
	},
	{
		"name": "Técnico/a",
		"pro": "Hace las tareas un 40% más rápido",
		"con": "Se mueve un 10% más lento",
		"repair": 1.4,
		"walk": 0.9,
		"run": 0.9,
	},
	{
		"name": "Vigía",
		"pro": "Linterna un 30% más ancha",
		"con": "Gasta el triple al alumbrar al Nonato",
		"angle": 1.3,
		# Sin rol, alumbrar al monstruo gasta el doble.
		"monster_drain": 1.5,
	},
]


static func count() -> int:
	return LIST.size()


static func clamp_id(role: int) -> int:
	return clampi(role, 0, LIST.size() - 1)


static func role_name(role: int) -> String:
	return LIST[clamp_id(role)]["name"]


## Ventaja y desventaja en dos líneas.
static func effects(role: int) -> String:
	var r: Dictionary = LIST[clamp_id(role)]
	return "+ %s\n- %s" % [r["pro"], r["con"]]


static func mult(role: int, key: String) -> float:
	return float(LIST[clamp_id(role)].get(key, 1.0))
