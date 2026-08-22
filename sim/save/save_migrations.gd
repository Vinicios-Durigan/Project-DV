class_name SaveMigrations
extends RefCounted

## Trilho de migração do save: mapa `versão de origem → passo`, aplicado em
## cadeia até a versão atual.
##
## Um passo é uma `Callable(Dictionary) -> Dictionary` que sobe **uma** versão.
## Ele não precisa carimbar nada: quem carimba é o trilho. Save v0 com destino
## v3 passa por 0→1, 1→2 e 2→3, nessa ordem.
##
## Recusar é sempre melhor que carregar torto. Falta de passo, passo quebrado ou
## save de uma versão mais nova que o jogo devolvem `null` — o mesmo `null` do
## `SaveManager` para arquivo ausente, então o chamador tem um caso só a tratar:
## sem dicionário, jogo novo.
##
## Hoje a versão atual é 1 e o trilho de produção está vazio: migrar um save v1
## é identidade. O trilho existe agora para que a primeira mudança de formato
## seja registrar um passo, e não reescrever o load.

var _versao_alvo: int
var _passos: Dictionary = {}

## De que versão sai o passo que entrega as ferramentas. Save v1 é anterior à
## wave 11.2, quando arar e regar passaram a exigir um item na mão.
const VERSAO_ANTES_DAS_FERRAMENTAS: int = 1

## A versão de destino é injetável para o teste provar cadeias longas sem
## precisar que o jogo já tenha chegado nelas.
func _init(versao_alvo: int = SimWorld.SAVE_VERSION) -> void:
	_versao_alvo = versao_alvo
	_registra_passos_de_producao()

## Os passos que o jogo de verdade usa. Teste que injeta a própria versão-alvo
## sobrescreve o que quiser: `register_step` é o último a falar.
func _registra_passos_de_producao() -> void:
	register_step(VERSAO_ANTES_DAS_FERRAMENTAS, _entrega_as_ferramentas)

## v1 → v2: **põe enxada e regador na mochila de quem já tinha partida.**
##
## A wave 11.2 fez arar e regar dependerem do item na mão. Partida nova recebe as
## ferramentas na entrega inicial, mas o save antigo carrega por cima dela — e o
## jogador reabria o jogo sem conseguir arar nem regar, sem nada na tela
## explicando por quê. Isso é o formato do save mudando de um jeito que
## `from_dict` sozinho não resolve, que é exatamente o que a versão existe para
## marcar.
##
## Só entrega o que falta: quem já tem a ferramenta não ganha uma segunda.
## Mochila sem espaço fica sem — melhor um item a menos que um save corrompido,
## e o playground tem botão para recomeçar.
func _entrega_as_ferramentas(data: Dictionary) -> Dictionary:
	var inventario: Dictionary = data.get(SimFactory.CHAVE_INVENTORY, {})
	for chave: Variant in inventario.keys():
		var jogador: Dictionary = inventario[chave]
		var slots: Array = jogador.get("slots", [])
		var capacidade := int(jogador.get("capacity", InventoryState.CAPACITY_PADRAO))

		for item_id in SimFactory.FERRAMENTAS_INICIAIS:
			if _tem_item(slots, item_id) or slots.size() >= capacidade:
				continue
			slots.append({"item_id": item_id, "qtd": 1})

		jogador["slots"] = slots
	return data

func _tem_item(slots: Array, item_id: String) -> bool:
	for entrada: Variant in slots:
		var slot: Dictionary = entrada
		if String(slot.get("item_id", "")) == item_id:
			return true
	return false

## Versão para a qual este trilho migra.
func target_version() -> int:
	return _versao_alvo

## Versão carimbada no dicionário. Sem carimbo é 0: save anterior ao
## versionamento.
static func version_of(data: Dictionary) -> int:
	return int(data.get(SimWorld.CHAVE_VERSAO, 0))

## Registra o passo que sobe de `de_versao` para `de_versao + 1`. Versão fora do
## trilho é ignorada — passo que nunca rodaria só esconderia bug.
func register_step(de_versao: int, passo: Callable) -> void:
	if de_versao < 0 or de_versao >= _versao_alvo or not passo.is_valid():
		return
	_passos[de_versao] = passo

func has_step(de_versao: int) -> bool:
	return _passos.has(de_versao)

## O save chega até a versão atual? Responde sem executar passo nenhum.
func can_migrate(data: Dictionary) -> bool:
	var versao := version_of(data)
	if versao > _versao_alvo:
		return false
	for v: int in range(versao, _versao_alvo):
		if not _passos.has(v):
			return false
	return true

## Sobe o save até a versão atual e devolve o dicionário migrado, ou `null` se
## ele não chega lá. O dicionário de entrada nunca é alterado — o passo mexe
## numa cópia funda.
func migrate(data: Dictionary) -> Variant:
	var versao := version_of(data)
	if versao > _versao_alvo:
		return null

	var atual: Dictionary = data.duplicate(true)
	while versao < _versao_alvo:
		if not _passos.has(versao):
			return null
		var passo: Callable = _passos[versao]
		var saida: Variant = passo.call(atual)
		if not saida is Dictionary:
			return null
		atual = saida
		versao += 1
		atual[SimWorld.CHAVE_VERSAO] = versao

	# sai sempre carimbado, mesmo o save que já estava na versão certa
	atual[SimWorld.CHAVE_VERSAO] = _versao_alvo
	return atual
