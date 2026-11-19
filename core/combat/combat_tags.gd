class_name CombatTags
extends RefCounted

## CombatTags — Constantes cerradas del contrato Combat ↔ IA (IA-0c)
##
## Un solo sitio para las etiquetas de las candidatas, los estados aparentes de salud,
## los niveles de amenaza y las condiciones sintéticas. Nadie escribe estas cadenas a
## mano: ni Combat ni la IA.

# Etiquetas de candidata (se DERIVAN de los efectos de la skill, no se declaran)
const TAG_ATTACK: StringName = &"attack"     # algún efecto DAMAGE
const TAG_DEFENSE: StringName = &"defense"   # BUFF de reducción de daño (effect_value.defense_buffs)
const TAG_RECOVER: StringName = &"recover"   # efecto RESTORE
const TAG_FLEE: StringName = &"flee"         # efecto FLEE
const TAG_COSTLY: StringName = &"costly"     # algún coste supera tag_rules.costly_cost_fraction

const ALL_TAGS: Array[StringName] = [TAG_ATTACK, TAG_DEFENSE, TAG_RECOVER, TAG_FLEE, TAG_COSTLY]

# Estado aparente de salud (Combat.get_hp_state)
const HP_HEALTHY: StringName = &"healthy"
const HP_HURT: StringName = &"hurt"
const HP_BADLY_HURT: StringName = &"badly_hurt"

# Amenaza aparente (Combat.estimate_threat)
const THREAT_LOW: StringName = &"low"
const THREAT_MEDIUM: StringName = &"medium"
const THREAT_HIGH: StringName = &"high"

# Condiciones sintéticas de Combat.get_visible_conditions (además de los buffs visibles)
const CONDITION_INCAPACITATED: StringName = &"incapacitated"
const CONDITION_FLED: StringName = &"fled"

# Bando de un combatiente (Combat.get_side, IA-1a)
const SIDE_ALLY: StringName = &"ally"
const SIDE_ENEMY: StringName = &"enemy"
