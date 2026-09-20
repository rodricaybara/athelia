class_name LogEntryData
extends RefCounted

## LogEntryData — una línea del log de combate
##
## text_key se resuelve con tr() en la View; format_args son valores ya
## resueltos (nombres de display, cantidades) para el "%s"/"%d" de la
## plantilla localizada. grade es un valor de SkillRoller.RollResult
## (int), o -1 cuando la línea no tiene grado (DODGE/DEFEND/FLEE/system).

var text_key: String = ""
var format_args: Array = []
var grade: int = -1
