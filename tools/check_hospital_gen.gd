extends SceneTree
## Genera muchos hospitales y cuenta los que no pasan la validación.
## Uso: godot --headless --path . --script res://tools/check_hospital_gen.gd -- [semillas] [--print=semilla,nivel]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--print="):
			var parts := a.trim_prefix("--print=").split(",")
			var rows := HospitalGen.generate(int(parts[0]), int(parts[1]))
			print("\n".join(rows))
			quit()
			return
	var count := 200 if args.is_empty() else int(args[0])
	var start := Time.get_ticks_msec()
	for level in [1, 2, 4]:
		var failed := 0
		for s in count:
			if HospitalGen.generate(s * 7919 + 13, level).is_empty():
				failed += 1
		print("nivel %d: %d de %d semillas sin hospital válido" % [level, failed, count])
	print("tiempo medio %.1f ms" % (float(Time.get_ticks_msec() - start) / (count * 3)))
	quit()
