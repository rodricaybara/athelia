class_name LoadingScreen
extends CanvasLayer

## LoadingScreen — Pantalla de carga
## Sin ViewModel: es una pantalla pasiva que solo muestra progreso.
##
## Uso desde SceneOrchestrator:
##   var loading = preload("res://ui/loading_screen/loading_screen.tscn").instantiate()
##   get_tree().root.add_child(loading)
##   loading.start_loading("res://scenes/exploration/exploration_test.tscn")
##
## Cuando la carga termina emite: loading_finished(packed_scene)
## SceneOrchestrator escucha esa señal y activa la escena cargada.

signal loading_finished(packed_scene: PackedScene)

# ============================================
# NODOS
# ============================================

@onready var lbl_loading: Label     = %LblLoading
@onready var progress_bar: ProgressBar = %LoadingBar

# ============================================
# ESTADO INTERNO
# ============================================

var _target_path: String = ""
var _is_loading: bool = false

# ============================================
# CICLO DE VIDA
# ============================================

func _ready() -> void:
	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value     = 0.0
	lbl_loading.text       = tr("LOADING_LABEL")
	print("[LoadingScreen] Ready")


func _process(_delta: float) -> void:
	if not _is_loading:
		return

	var progress: Array = []
	var status: int = ResourceLoader.load_threaded_get_status(_target_path, progress)

	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var pct: float = progress[0] * 100.0 if not progress.is_empty() else 0.0
			progress_bar.value = pct

		ResourceLoader.THREAD_LOAD_LOADED:
			progress_bar.value = 100.0
			_is_loading = false
			var packed := ResourceLoader.load_threaded_get(_target_path) as PackedScene
			if packed:
				print("[LoadingScreen] Load complete: %s" % _target_path)
				loading_finished.emit(packed)
			else:
				push_error("[LoadingScreen] Failed to get loaded resource: %s" % _target_path)

		ResourceLoader.THREAD_LOAD_FAILED:
			_is_loading = false
			push_error("[LoadingScreen] Load failed: %s" % _target_path)

		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_is_loading = false
			push_error("[LoadingScreen] Invalid resource: %s" % _target_path)


# ============================================
# API PÚBLICA
# ============================================

func start_loading(scene_path: String) -> void:
	if _is_loading:
		push_warning("[LoadingScreen] Already loading — ignoring: %s" % scene_path)
		return

	_target_path = scene_path
	progress_bar.value = 0.0
	lbl_loading.text   = tr("LOADING_LABEL")

	var error: int = ResourceLoader.load_threaded_request(scene_path)
	if error != OK:
		push_error("[LoadingScreen] load_threaded_request failed for: %s (error %d)" % [scene_path, error])
		return

	_is_loading = true
	print("[LoadingScreen] Loading started: %s" % scene_path)
