class_name CombatTokenData
extends RefCounted

## CombatTokenData — snapshot de una ficha de combate (party o enemigo)
##
## Producida por CombatArenaViewModel, consumida por la View para
## rellenar un UICombatToken. Sin lógica propia — solo datos ya resueltos.

var entity_id: String = ""
var is_party: bool = true

var display_initials: String = ""
var type_icon: Texture2D = null
var fill_color: Color = Color.WHITE

var hp_current: int = 0
var hp_max: int = 1
var stamina_current: int = 0
var stamina_max: int = 1

var is_current_turn: bool = false
var is_targeted: bool = false
