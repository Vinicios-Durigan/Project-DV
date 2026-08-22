class_name EstadoLocais
extends RefCounted

## Em que local cada jogador está — dono exclusivo do SistemaLocais.
##
## A posição em pixel é assunto de `game/` e nunca chega aqui: a sim só sabe o
## **local** (fazenda, cidade), porque é isso que decide regra — regar fora da
## fazenda é recusado, entregar fora da cidade também (wave 12).
##
## Todo campo tem default e entra no snapshot do save (v1) por to_dict/from_dict.
## Save antigo, sem o bloco `locais`, carrega com todo jogador na fazenda e o
## jogo se comporta exatamente como antes da wave 10.

const FAZENDA: String = "fazenda"
const CIDADE: String = "cidade"
const LOCAIS_VALIDOS: Array[String] = [FAZENDA, CIDADE]

const LOCAL_DEFAULT: String = FAZENDA

## player_id (int) -> local (String). Jogador ausente está no default — é o que
## permite co-op nascer sem migração: jogador novo simplesmente ainda não tem
## entrada.
var _jogadores: Dictionary = {}


## Onde o jogador está. Jogador nunca visto está na fazenda.
func local_de(player_id: int) -> String:
	return _jogadores.get(player_id, LOCAL_DEFAULT)

## Move o jogador. Quem valida o destino é o SistemaLocais — o estado só
## guarda; validação em setter esconderia a recusa do fluxo de eventos.
func define_local(player_id: int, local: String) -> void:
	_jogadores[player_id] = local

## O local existe no jogo?
func e_valido(local: String) -> bool:
	return local in LOCAIS_VALIDOS


## Snapshot para o save. Chave de jogador vira string: JSON não tem chave int,
## mesmo formato do bloco `inventory`.
func to_dict() -> Dictionary:
	var jogadores: Dictionary = {}
	for player_id: int in _jogadores:
		jogadores[str(player_id)] = _jogadores[player_id]
	return {"jogadores": jogadores}

## Carrega do save. Campo ausente cai no default; local desconhecido (save
## editado à mão) é descartado — cair no default é mais seguro que carregar um
## lugar que o jogo não conhece.
func from_dict(data: Dictionary) -> void:
	_jogadores = {}
	var jogadores: Dictionary = data.get("jogadores", {})
	for chave: Variant in jogadores:
		var local: String = String(jogadores[chave])
		if e_valido(local):
			_jogadores[int(chave)] = local
