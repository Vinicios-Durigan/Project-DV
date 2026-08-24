class_name ExperienciaGanhaEvent
extends SimEvent

## Um trabalho ensinou. Sai junto de cada gesto consumado, na mesma batida do
## `EstaminaGastaEvent` — o mesmo golpe cansa e ensina, e são dois eventos porque
## são dois donos.
##
## Evento gordo: leva o trabalho que ensinou, o ofício onde o XP entrou e o
## acumulado depois da soma, para o diário do playground contar a história sem
## abrir o state de ninguém. "+4" sozinho não diz se o jogador arou ou colheu.

var player_id: int = 0
## O ofício que praticou (`lavoura`, `campo`).
var oficio: String = ""
## O trabalho que ensinou, do vocabulário do `SistemaCorpo` (`arar`, `regar`, …).
var trabalho: String = ""
## Quanto este gesto valeu — o mesmo número que ele custou de estamina.
var xp: int = 0
## O acumulado do ofício depois desta soma.
var total: int = 0
