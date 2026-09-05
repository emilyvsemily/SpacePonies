class_name PonyGenome
extends Resource

## Internal data structure for a pony's genetic traits — ported from the
## Look Book's `randomGenome()` (docs/index.html), so the game and the
## design-preview generator agree on trait ranges/probabilities. This is
## also the intended foundation for breeding: combining two PonyGenomes
## into a foal is future work, but having a real typed Resource (rather
## than loose variables) is what makes that tractable later.

const LEG_TYPES := ["hooves", "tentacles", "propeller-feet", "rocket-boots"]
const TAIL_TYPES := ["rocket", "whip", "propeller"]
const MANE_STYLES := ["space-mane", "antenna-mane"]
const ABILITIES := ["dash", "gravity-flip", "fart-boost", "teleport-hiccup", "magnet-hooves"]

@export var leg_count: int = 3
@export var leg_type: String = "rocket-boots"
@export var tail_type: String = "rocket"
@export var size: float = 1.0
@export var coat_hue: float = 0.0
@export var mane_hue: float = 0.3
@export var mane_style: String = "space-mane"
@export var coat_pattern: String = "solid"
@export var extra_eyes: bool = false
@export var wings: bool = false
@export var antigrav_horn: bool = true
@export var gills: bool = false
@export var ability: String = "dash"

@export var stat_speed: int = 50
@export var stat_acceleration: int = 50
@export var stat_handling: int = 50
@export var stat_stamina: int = 50
@export var stat_wackiness: int = 30

static func generate_random() -> PonyGenome:
	var g := PonyGenome.new()

	var leg_r := randf()
	g.leg_count = 2 if leg_r < 0.14 else (3 if leg_r < 0.62 else 4)
	g.leg_type = LEG_TYPES[randi() % LEG_TYPES.size()]
	g.tail_type = TAIL_TYPES[randi() % TAIL_TYPES.size()]
	g.size = randf_range(0.8, 1.3)
	g.coat_hue = randf()
	g.mane_hue = fmod(g.coat_hue + randf_range(0.28, 0.72), 1.0)
	g.mane_style = MANE_STYLES[randi() % MANE_STYLES.size()]
	g.coat_pattern = "spotted" if randf() < 0.4 else "solid"
	g.extra_eyes = randf() < 0.3
	g.wings = randf() < 0.35
	g.antigrav_horn = randf() < 0.55
	g.gills = randf() < 0.3
	g.ability = ABILITIES[randi() % ABILITIES.size()]

	var speed := float(randi_range(30, 90))
	var acceleration := float(randi_range(30, 90))
	var handling := float(randi_range(30, 90))
	var stamina := float(randi_range(30, 90))
	var wackiness := float(randi_range(15, 65))

	match g.leg_type:
		"rocket-boots": speed += 12.0
		"propeller-feet": acceleration += 12.0
		"tentacles": handling += 12.0
		"hooves": stamina += 12.0
	if g.leg_count == 2:
		acceleration += 8.0
		handling -= 10.0
	elif g.leg_count == 4:
		handling += 8.0
		stamina += 4.0
	speed *= 0.85 + g.size * 0.2

	var mutations := 0
	if g.extra_eyes: mutations += 1
	if g.wings: mutations += 1
	if g.gills: mutations += 1
	if g.antigrav_horn: mutations += 1
	wackiness += mutations * 7.0
	if g.leg_count == 2: wackiness += 10.0
	if g.leg_type == "tentacles": wackiness += 6.0

	g.stat_speed = _clamp_stat(speed)
	g.stat_acceleration = _clamp_stat(acceleration)
	g.stat_handling = _clamp_stat(handling)
	g.stat_stamina = _clamp_stat(stamina)
	g.stat_wackiness = _clamp_stat(wackiness)

	return g

static func _clamp_stat(v: float) -> int:
	return clampi(int(round(v)), 5, 99)

## HSL -> Color, since the Look Book's palette is authored in HSL and the
## exact hues/saturations/lightnesses only look right converted the same
## way (Godot's Color.from_hsv is HSV, a different color model).
static func hsl_to_color(h: float, s: float, l: float, a: float = 1.0) -> Color:
	h = fposmod(h, 1.0)
	if s <= 0.0:
		return Color(l, l, l, a)
	var q := l * (1.0 + s) if l < 0.5 else l + s - l * s
	var p := 2.0 * l - q
	return Color(
		_hue_to_rgb(p, q, h + 1.0 / 3.0),
		_hue_to_rgb(p, q, h),
		_hue_to_rgb(p, q, h - 1.0 / 3.0),
		a
	)

static func _hue_to_rgb(p: float, q: float, t: float) -> float:
	if t < 0.0: t += 1.0
	if t > 1.0: t -= 1.0
	if t < 1.0 / 6.0: return p + (q - p) * 6.0 * t
	if t < 1.0 / 2.0: return q
	if t < 2.0 / 3.0: return p + (q - p) * (2.0 / 3.0 - t) * 6.0
	return p
