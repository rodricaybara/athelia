@tool
extends EditorScript
## Comprobación manual — Spike 15, Fase A (tokens).
## Uso: abrir este fichero en el editor de scripts de Godot y ejecutarlo con
## Archivo > Ejecutar (Ctrl+Mayús+X). Imprime el resultado en el Output.
## Se puede borrar al cerrar el spike.

const T := preload("res://ui/design_system/tokens/ui_tokens.gd")


func _run() -> void:
	var checks: Array[Dictionary] = [
		{"name": "BG_BASE == COLOR_BG", "ok": T.BG_BASE == T.COLOR_BG},
		{"name": "BG_PANEL == COLOR_PANEL", "ok": T.BG_PANEL == T.COLOR_PANEL},
		{"name": "BG_SURFACE == COLOR_PANEL_ALT", "ok": T.BG_SURFACE == T.COLOR_PANEL_ALT},
		{"name": "BORDER_DEFAULT == COLOR_BORDER", "ok": T.BORDER_DEFAULT == T.COLOR_BORDER},
		{"name": "TEXT_PRIMARY == COLOR_TEXT", "ok": T.TEXT_PRIMARY == T.COLOR_TEXT},
		{"name": "TEXT_MUTED == COLOR_TEXT_MUTED", "ok": T.TEXT_MUTED == T.COLOR_TEXT_MUTED},
		{"name": "COLOR_SLOT_OCCUPIED == COLOR_PANEL_ALT", "ok": T.COLOR_SLOT_OCCUPIED == T.COLOR_PANEL_ALT},
		{"name": "COLOR_TEXT_MUTED == #9A8E78", "ok": T.COLOR_TEXT_MUTED == Color("#9A8E78")},
		{"name": "COLOR_PANEL_ALT == #252220", "ok": T.COLOR_PANEL_ALT == Color("#252220")},
		{"name": "FRAME_MIN_PADDING == SPACE_LG (16)", "ok": T.FRAME_MIN_PADDING == T.SPACE_LG and T.FRAME_MIN_PADDING == 16},
		{"name": "FRAME_CORNER_TEXTURE_PATH existe", "ok": ResourceLoader.exists(T.FRAME_CORNER_TEXTURE_PATH)},
		{"name": "Radios sin tocar (4 y 6)", "ok": T.RADIUS_CARD == 4 and T.RADIUS_PANEL == 6},
	]

	var failures: int = 0
	for check in checks:
		if not check["ok"]:
			failures += 1
			printerr("[Spike15-FaseA] FALLA: %s" % check["name"])

	if failures == 0:
		print("[Spike15-FaseA] OK: %d/%d comprobaciones correctas" % [checks.size(), checks.size()])
	else:
		printerr("[Spike15-FaseA] %d de %d comprobaciones fallan" % [failures, checks.size()])
