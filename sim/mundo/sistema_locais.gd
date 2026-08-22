class_name SistemaLocais
extends SimSystem

## Dono do `EstadoLocais`: processa `ViajarAction` e barra ação fora de lugar.
##
## **Só se age onde se está** (decisão de presença, wave 10). Este sistema
## registra ANTES de todos os outros no tick central, e a posição não é
## detalhe: `PlantCropAction` estende `RemoveItemAction`, então se o carimbo de
## rejeição viesse depois do Inventory, a semente seria debitada de uma ação
## que ia ser recusada.
##
## O mapa ação → local exigido mora aqui, centralizado, de propósito (decisão
## da wave 10): nenhum sistema existente precisou mudar. Se o mapa crescer
## demais quando a cidade tiver as próprias ações, revisita-se na wave 12.

const MOTIVO_FORA_DO_LOCAL: String = "fora_do_local"
const MOTIVO_JA_NO_LOCAL: String = "ja_no_local"
const MOTIVO_DESTINO_DESCONHECIDO: String = "destino_desconhecido"

var _estado: EstadoLocais


func _init(estado: EstadoLocais) -> void:
	_estado = estado


func handle(action: SimAction) -> Array[SimEvent]:
	if action.rejeitada:
		return []
	if action is ViajarAction:
		return _viaja(action)
	return _gateia(action)


## Onde o jogador está — leitura pura, para teste e para a wave 12.
func local_de(player_id: int) -> String:
	return _estado.local_de(player_id)


## Muda o local do jogador. Viajar não cobra nada: o custo é o tempo de relógio
## que passou na caminhada, já pago quando a ação chega aqui.
func _viaja(action: ViajarAction) -> Array[SimEvent]:
	if not _estado.e_valido(action.destino):
		return [_rejeita(action, MOTIVO_DESTINO_DESCONHECIDO)]
	var de: String = _estado.local_de(action.player_id)
	if de == action.destino:
		return [_rejeita(action, MOTIVO_JA_NO_LOCAL)]

	_estado.define_local(action.player_id, action.destino)
	var evento := JogadorViajouEvent.new()
	evento.player_id = action.player_id
	evento.de = de
	evento.para = action.destino
	return [evento]

## Barra a ação cujo local exigido não é onde o jogador está. Ação sem local
## exigido (dormir, cheats, inventário) passa reta — o gate é invisível para
## quem está no lugar certo.
func _gateia(action: SimAction) -> Array[SimEvent]:
	var exigido: String = _local_exigido(action)
	if exigido.is_empty():
		return []
	if _estado.local_de(action.player_id) == exigido:
		return []
	return [_rejeita(action, MOTIVO_FORA_DO_LOCAL)]

## O mapa ação → local. As quatro ações de fazenda exigem estar na fazenda; as
## duas da cidade exigem estar na cidade.
##
## Ele continua morando aqui, e não espalhado pelos sistemas, porque as duas
## ações da wave 12 couberam em duas linhas — o mapa não cresceu a ponto de
## justificar cada sistema declarar o próprio local. Quando crescer, o lugar de
## revisitar isto é este comentário.
func _local_exigido(action: SimAction) -> String:
	if action is TillPlotAction \
			or action is PlantCropAction \
			or action is WaterPlotAction \
			or action is HarvestCropAction:
		return EstadoLocais.FAZENDA
	if action is EntregarAction or action is RetirarAction:
		return EstadoLocais.CIDADE
	return ""

## Carimba a rejeição e monta o aviso. Mesmo contrato do FarmSystem: `motivo`
## é id de máquina; quem fala com o jogador é `game/`.
func _rejeita(action: SimAction, motivo: String) -> ActionRejectedEvent:
	action.rejeitada = true
	var evento := ActionRejectedEvent.new()
	evento.player_id = action.player_id
	evento.acao = action.get_script().get_global_name()
	evento.motivo = motivo
	return evento
