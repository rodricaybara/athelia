extends Node

## Test de Localización - Día 2
## Valida que las claves de traducción funcionan

func _ready():
	print("\n" + "=".repeat(50))
	print("SPIKE DÍA 2 - TEST LOCALIZACIÓN")
	print("=".repeat(50) + "\n")
	
	test_localization_keys()
	test_language_switching()
	
	print("\n" + "=".repeat(50))
	print("✅ LOCALIZACIÓN VALIDADA")
	print("=".repeat(50) + "\n")


## Test 1: Claves de traducción
func test_localization_keys():
	print("📝 Test 1: Claves de traducción")
	
	# Probar en inglés
	TranslationServer.set_locale("en")
	
	var name_en = tr("ITEM_STAMINA_POTION_SMALL_NAME")
	var desc_en = tr("ITEM_STAMINA_POTION_SMALL_DESC")
	
	assert(name_en != "ITEM_STAMINA_POTION_SMALL_NAME", "Translation not found for EN!")
	assert(name_en == "Small Stamina Potion", "EN name mismatch!")
	print("  ✅ EN: %s" % name_en)
	print("  ✅ EN: %s" % desc_en)
	
	# Probar en español
	TranslationServer.set_locale("es")
	
	var name_es = tr("ITEM_STAMINA_POTION_SMALL_NAME")
	var desc_es = tr("ITEM_STAMINA_POTION_SMALL_DESC")
	
	assert(name_es != "ITEM_STAMINA_POTION_SMALL_NAME", "Translation not found for ES!")
	assert(name_es == "Poción Menor de Estamina", "ES name mismatch!")
	print("  ✅ ES: %s" % name_es)
	print("  ✅ ES: %s" % desc_es)
	
	print()


## Test 2: Cambio de idioma dinámico
func test_language_switching():
	print("📝 Test 2: Cambio dinámico de idioma")
	
	var potion = load("res://data/items/stamina_potion_small.tres") as ItemDefinition
	
	# Inglés
	TranslationServer.set_locale("en")
	var name_en = tr(potion.name_key)
	print("  ✅ Switched to EN: %s" % name_en)
	
	# Español
	TranslationServer.set_locale("es")
	var name_es = tr(potion.name_key)
	print("  ✅ Switched to ES: %s" % name_es)
	
	# Verificar que son diferentes
	assert(name_en != name_es, "Translations should be different!")
	print("  ✅ Idiomas funcionan independientemente")
	
	print()
