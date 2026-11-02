class_name ItemDetailData
extends RefCounted

## ItemDetailData (Spike 19b-2)
##
## Datos del panel de detalle de un ítem, ya listos para pintar. Antes eran
## clases internas de InventoryViewModel (DetailData, ModLine, CompareLine);
## viven aquí para que el inventario y Party compartan el mismo cálculo sin
## que ninguno dependa del otro (ver ItemDetailBuilder).
##
## Solo datos: sin lógica, sin acceso a sistemas.


## Una línea de modificador del detalle ("Armadura", "+3")
class ModLine:
	var label: String = ""            ## ya traducido
	var text: String = ""             ## "+3", "-1", "x1.20", "= 5"
	var value: float = 0.0


## Una línea de comparación ("Armadura", "+1")
class CompareLine:
	var label: String = ""            ## ya traducido
	var text: String = ""
	var delta: float = 0.0            ## > 0 mejora, < 0 empeora (la View elige el color)


# --- Spike 17 ---
var item_def: ItemDefinition = null
var quantity: int = 0
var is_equipped: bool = false

# --- Spike 18 ---
var category_id: String = ""
var category_name: String = ""
var modifier_lines: Array[ModLine] = []

## Comparación: solo para EQUIPMENT no equipado con un slot válido
var has_comparison: bool = false
var compare_slot_id: String = ""
var compare_slot_free: bool = false      ## el slot está libre: no hay con qué comparar
var compare_against_name: String = ""    ## nombre traducido de lo equipado
var compare_lines: Array[CompareLine] = []  ## vacío + has_comparison = sin diferencias
