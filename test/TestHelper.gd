extends Node

## TestHelper - Script de ayuda para validación manual del spike v3
##
## Ejecuta los flujos de prueba llamando directamente a DialogueSystem,
## exactamente como lo haría un panel de diálogo real.
## El evento narrativo se dispara internamente por DialogueSystem
## vía _trigger_narrative_events → Narrative.apply_event().
##
## Uso: adjuntar al test scene junto al NarrativeDebugPanel.
## Abrir el panel (F12), pulsar las teclas indicadas, observar el estado.
##
## Teclas:
##   1 → Flujo 1: Flag temporal (DLG_TEST_SIMPLE → opción rude)
##   2 → Flujo 2A: Reputación positiva (DLG_TEST_DECISION → opción fair)
##   3 → Flujo 2B: Reputación negativa menor (DLG_TEST_DECISION → opción haggle)
##   4 → Flujo 2C: Reputación negativa fuerte (DLG_TEST_DECISION → opción steal)
##   R → Reiniciar todo (Narrative + Checkpoints)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	
	if not event.is_pressed():
		return

	match event.keycode:
		KEY_1:
			_run_flow_1_temp_flag()
		KEY_2:
			_run_flow_2a_fair()
		KEY_3:
			_run_flow_2b_haggle()
		KEY_4:
			_run_flow_2c_steal()
		KEY_R:
			_run_reset()


# ==============================================
# FLUJO 1: Flag temporal que muere en checkpoint
# ==============================================
# Estado esperado tras ejecutar:
#   Flags: TEMP_RUDE_TO_GUARD = true
# Estado esperado tras aplicar ACT1_END desde el panel:
#   Flags: TEMP_RUDE_TO_GUARD desaparece (no está en flags_preserved)

func _run_flow_1_temp_flag() -> void:
	print("\n[TestHelper] ========================================")
	print("[TestHelper] FLUJO 1: Flag temporal")
	print("[TestHelper] ========================================")

	if not _execute_dialogue("DLG_TEST_SIMPLE", "O2_RUDE"):
		return

	print("[TestHelper] → Esperado: TEMP_RUDE_TO_GUARD aparece en Flags")
	print("[TestHelper] → Siguiente: Aplicar ACT1_END desde el panel")
	print("[TestHelper] → Verificar: TEMP_RUDE_TO_GUARD desaparece")
	print("[TestHelper] ========================================\n")


# ==============================================
# FLUJO 2: Variables dispersas → vector consolidado
# ==============================================
# Ejecutar 2A y 2B (en cualquier orden), luego aplicar ACT1_END.
# Estado esperado tras 2A + 2B:
#   Variables: reputation_act1_fair = 10, reputation_act1_haggle = -5
# Estado esperado tras aplicar ACT1_END:
#   Variables dispersas desaparecen
#   Vector reputation = 5 (10 + (-5)), dentro de rango [-100, 100]

func _run_flow_2a_fair() -> void:
	print("\n[TestHelper] ========================================")
	print("[TestHelper] FLUJO 2A: Reputación — decisión justa (+10)")
	print("[TestHelper] ========================================")

	if not _execute_dialogue("DLG_TEST_DECISION", "O1_FAIR"):
		return

	print("[TestHelper] → Esperado: reputation_act1_fair = 10 aparece en Variables")
	print("[TestHelper] ========================================\n")


func _run_flow_2b_haggle() -> void:
	print("\n[TestHelper] ========================================")
	print("[TestHelper] FLUJO 2B: Reputación — regateo (-5)")
	print("[TestHelper] ========================================")

	if not _execute_dialogue("DLG_TEST_DECISION", "O2_HAGGLE"):
		return

	print("[TestHelper] → Esperado: reputation_act1_haggle = -5 aparece en Variables")
	print("[TestHelper] ========================================\n")


func _run_flow_2c_steal() -> void:
	print("\n[TestHelper] ========================================")
	print("[TestHelper] FLUJO 2C: Reputación — robo (-20)")
	print("[TestHelper] ========================================")

	if not _execute_dialogue("DLG_TEST_DECISION", "O3_STEAL"):
		return

	print("[TestHelper] → Esperado: reputation_act1_steal = -20 aparece en Variables")
	print("[TestHelper] ========================================\n")


# ==============================================
# RESET
# ==============================================

func _run_reset() -> void:
	print("\n[TestHelper] ========================================")
	print("[TestHelper] RESET: Limpiando todo el estado")
	print("[TestHelper] ========================================")

	Narrative.clear_all()
	Checkpoints.reset()

	print("[TestHelper] → Estado narrativo y checkpoints reiniciados")
	print("[TestHelper] → Pulsa Refresh en el panel para ver el cambio")
	print("[TestHelper] ========================================\n")


# ==============================================
# HELPER INTERNO
# ==============================================

## Ejecuta un diálogo completo: inicio → selección de opción → cierre.
## Retorna true si todo fue correcto, false si algo falló.
## Esto es exactamente lo que haría un panel de diálogo real:
##   1. start_dialogue → DialogueSystem carga el diálogo y muestra N1
##   2. select_option → dispara eventos narrativos, navega al siguiente nodo
##   3. Si el nodo destino no tiene opciones → end_dialogue (el panel real
##      detectaría esto y cerraría el diálogo automáticamente)
func _execute_dialogue(dialogue_id: String, option_id: String) -> bool:
	print("[TestHelper] Iniciando diálogo: %s" % dialogue_id)

	if not Dialogue.start_dialogue(dialogue_id):
		push_error("[TestHelper] Falló start_dialogue: %s" % dialogue_id)
		return false

	print("[TestHelper] Seleccionando opción: %s" % option_id)

	if not Dialogue.select_option(option_id):
		push_error("[TestHelper] Falló select_option: %s" % option_id)
		Dialogue.end_dialogue()
		return false

	# Si el diálogo sigue activo tras la selección, significa que navega
	# a un nodo sin opciones (nodo final). Un panel real lo cerraría aquí.
	if Dialogue.is_active():
		print("[TestHelper] Nodo destino sin opciones — cerrando diálogo")
		Dialogue.end_dialogue()

	print("[TestHelper] Diálogo completado correctamente")
	return true
