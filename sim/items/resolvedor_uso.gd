class_name ResolvedorUso
extends RefCounted

## A regra do **usar**: dado um jogador e um tile, qual ação isso vira?
##
## É o arquivo que substitui as quatro ferramentas que o playground tinha
## inventado nas teclas 1–4. Não existe mais "modo arar" nem "modo plantar":
## existe o que está na mão, e o `GAMEPLAY §4` já mandava isso desde o começo.
##
## ## A ordem das regras, e por que ela é essa
##
## 1. **Cultura pronta colhe**, seja o que for que esteja na mão. Decisão da
##    wave 11.2: tira um passo do laço mais repetido do jogo — não se troca de
##    item para colher — e combina com o §6, onde colher não tem swing.
##    Rega continua funcionando em cultura **verde**, que é quando ela importa.
## 2. **O que cobre o tile sai primeiro**, se a ferramenta na mão der conta dele
##    (wave 14). Enquanto houver mato ali, arar não é o que o jogador quis
##    dizer — e é isso que faz a enxada capinar sem ganhar tecla nova.
## 3. **Ferramenta na mão** faz o que o `ItemDef.acao_de_uso` dela declara.
## 4. **Semente na mão** planta a cultura daquela semente.
## 5. Nada disso → `null`, e `game/` não despacha nada.
##
## ## Por que devolve a ação em vez de executá-la
##
## A ordem do tick é regra de jogo: Locais → Inventory → Shipping → Farm →
## Time. `PlantCropAction` estende `RemoveItemAction`, então quem cobra a
## semente é o `InventorySystem`. Uma ação criada **dentro** do `FarmSystem`
## já teria passado do Inventory e a semente sairia de graça.
##
## Devolvendo a ação para quem perguntou, ela entra pela porta da frente e
## percorre a fila inteira — sem exceção e sem caso especial.
##
## ## Isto não é um sistema
##
## Ele não trata ação nenhuma e não muda estado: é uma **consulta**, no mesmo
## espírito de `FarmSystem.pode_plantar()`. Por isso não entra na fila do tick.
##
## Lê state de dois donos (inventário e fazenda) porque a pergunta cruza os
## dois. Leitura é livre; escrever é que continua sendo só do dono.

var _inventario: InventoryState
var _farm: FarmState
var _items: ItemCatalog
var _crops: CropCatalog
var _terreno: EstadoTerreno


## O terreno é o quarto state lido, e entrou por último de propósito: sem ele
## injetado o mundo é todo livre, e tudo o que a wave 11.2 decidiu continua
## valendo sem saber que existe mato.
func _init(inventario: InventoryState = null, farm: FarmState = null,
		items: ItemCatalog = null, crops: CropCatalog = null,
		terreno: EstadoTerreno = null) -> void:
	_inventario = inventario if inventario != null else InventoryState.new()
	_farm = farm if farm != null else FarmState.new()
	_items = items if items != null else ItemCatalog.new()
	_crops = crops if crops != null else CropCatalog.new()
	_terreno = terreno if terreno != null else EstadoTerreno.new()


## A ação que "usar neste tile" vira, ou `null` se não há nada a fazer.
##
## `null` não é erro nem recusa: é ausência de ação. Recusa é o que a sim
## responde depois, quando a ação existe mas não pode acontecer — e essa vem
## com motivo, no `ActionRejectedEvent`.
func acao_para(player_id: int, x: int, y: int) -> SimAction:
	if _pode_colher(x, y):
		return _colher(player_id, x, y)

	var item_id := item_na_mao(player_id)
	if item_id.is_empty():
		return null

	var def := _items.get_def(item_id)
	if def == null:
		return null

	# No poço, o gesto é encher — e só quem carrega alguma coisa tem o que
	# encher lá. Vem antes da limpeza porque água não se limpa, e antes de arar
	# porque não se ara dentro do poço.
	if _terreno.cobertura(x, y) == EstadoTerreno.AGUA:
		return _encher(player_id, def, x, y)

	# Antes de qualquer coisa que dependa de terra limpa: se a ferramenta na mão
	# dá conta do que cobre o tile, o gesto é tirar aquilo do caminho.
	if def.alvos_de_limpeza.has(_terreno.cobertura(x, y)):
		return _limpar(player_id, item_id, x, y)

	match def.acao_de_uso:
		ItemDef.ACAO_ARAR:
			return _arar(player_id, x, y)
		ItemDef.ACAO_REGAR:
			return _regar(player_id, x, y)

	return _plantar(player_id, item_id, x, y)


## O item que o jogador tem na mão, ou vazio.
##
## O índice pode apontar além dos stacks que existem — a mochila esvazia e a
## mão fica onde estava, como em qualquer hotbar. Mão vazia é estado legítimo:
## é com ela que se colhe.
func item_na_mao(player_id: int) -> String:
	var inv := _inventario.get_player(player_id)
	if inv.slot_na_mao < 0 or inv.slot_na_mao >= inv.slots.size():
		return ""
	return inv.slots[inv.slot_na_mao].item_id


# --- As quatro respostas ---

## Regra 1. A mesma pergunta que o `FarmSystem` faz — repetida aqui em leitura
## pura para não depender da instância do sistema.
func _pode_colher(x: int, y: int) -> bool:
	var plot := _farm.peek_plot(x, y)
	if not plot.tem_cultura():
		return false
	var def := _crops.get_def(plot.crop_id)
	return def != null and plot.estagio >= def.estagio_pronta()

func _colher(player_id: int, x: int, y: int) -> HarvestCropAction:
	var acao := HarvestCropAction.new()
	acao.player_id = player_id
	acao.x = x
	acao.y = y
	return acao

## Encher no poço. `null` quando não há o que encher — item que não carrega, ou
## já cheio. Estar cheio não é erro; é ausência de gesto, e ausência é silêncio.
func _encher(player_id: int, def: ItemDef, x: int, y: int) -> EncherRegadorAction:
	if def.capacidade_carga <= 0:
		return null
	var slot := _slot_na_mao(player_id)
	if slot == null or slot.carga >= def.capacidade_carga:
		return null
	var acao := EncherRegadorAction.new()
	acao.player_id = player_id
	acao.x = x
	acao.y = y
	return acao

## O slot que o jogador segura, ou `null`. O índice pode apontar além dos slots
## que existem, como em `item_na_mao`.
func _slot_na_mao(player_id: int) -> InventoryState.Slot:
	var inv := _inventario.get_player(player_id)
	return inv.slot_em(inv.slot_na_mao)

## Tirar do caminho o que cobre o tile. Quem já decidiu que a ferramenta serve
## foi o chamador — aqui só se monta a intenção. A recusa de verdade (cobertura
## que essa ferramenta não remove, ou tile já limpo) é do `SistemaTerreno`, que
## responde com motivo.
func _limpar(player_id: int, item_id: String, x: int, y: int) -> LimparTerrenoAction:
	var acao := LimparTerrenoAction.new()
	acao.player_id = player_id
	acao.item_id = item_id
	acao.x = x
	acao.y = y
	return acao

## Arar exige chão livre desde a wave 14: sem isso a enxada araria por baixo da
## pedra, e o jogador plantaria dentro de um matagal.
func _arar(player_id: int, x: int, y: int) -> TillPlotAction:
	if not _terreno.e_livre(x, y):
		return null
	var plot := _farm.peek_plot(x, y)
	if plot.arada or plot.tem_cultura():
		return null
	var acao := TillPlotAction.new()
	acao.player_id = player_id
	acao.x = x
	acao.y = y
	return acao

func _regar(player_id: int, x: int, y: int) -> WaterPlotAction:
	var plot := _farm.peek_plot(x, y)
	if not plot.arada or plot.regada:
		return null
	var acao := WaterPlotAction.new()
	acao.player_id = player_id
	acao.x = x
	acao.y = y
	return acao

## Regra 3. A cultura sai da semente que está na mão — é isto que o playground
## não fazia, e é o bug que o jogo mostrou: com o catálogo inteiro na mochila,
## plantar usava sempre a primeira cultura.
##
## Perguntar antes é obrigatório aqui, e só aqui: `PlantCropAction` estende
## `RemoveItemAction`, então despachar em tile inválido cobraria a semente de
## uma ação que vai ser recusada.
func _plantar(player_id: int, item_id: String, x: int, y: int) -> PlantCropAction:
	var crop_id := _cultura_da_semente(item_id)
	if crop_id.is_empty():
		return null
	var plot := _farm.peek_plot(x, y)
	if not plot.arada or plot.tem_cultura():
		return null

	var acao := PlantCropAction.new()
	acao.player_id = player_id
	acao.crop_id = crop_id
	acao.item_id = item_id
	acao.qtd = 1
	acao.x = x
	acao.y = y
	return acao

## Qual cultura esta semente planta. A ligação já existe no `CropDef`
## (`item_semente`), então nenhum dado novo precisou ser inventado — a varredura
## é do catálogo, que tem cinco entradas.
func _cultura_da_semente(item_id: String) -> String:
	for crop_id in _crops.ids():
		var def := _crops.get_def(crop_id)
		if def != null and def.item_semente_id() == item_id:
			return crop_id
	return ""
