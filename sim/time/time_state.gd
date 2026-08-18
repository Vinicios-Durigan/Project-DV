class_name TimeState
extends RefCounted

## Estado do relógio, dono exclusivo do TimeSystem.
##
## `minuto` é o minuto do dia (0..1439); 360 = 06:00, hora de acordar. O dia só
## vira quando o TimeSystem encerra o dia (dormir ou colapso), nunca à meia-noite.
##
## Todo campo tem default e entra no snapshot do save (v1) por to_dict/from_dict.

const DIA_DEFAULT: int = 1
const MINUTO_DEFAULT: int = 360
const ESTACAO_DEFAULT: String = "primavera"

var dia: int = DIA_DEFAULT
var minuto: int = MINUTO_DEFAULT
var estacao: String = ESTACAO_DEFAULT

## Snapshot para o save.
func to_dict() -> Dictionary:
	return {
		"dia": dia,
		"minuto": minuto,
		"estacao": estacao,
	}

## Carrega do save. Campo ausente cai no default — é assim que campo novo entra
## sem migração.
func from_dict(data: Dictionary) -> void:
	dia = int(data.get("dia", DIA_DEFAULT))
	minuto = int(data.get("minuto", MINUTO_DEFAULT))
	estacao = String(data.get("estacao", ESTACAO_DEFAULT))
