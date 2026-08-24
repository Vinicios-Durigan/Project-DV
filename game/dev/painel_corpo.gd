class_name PainelCorpo
extends VBoxContainer

## A aba Corpo: o que cada trabalho custa, quanto o dia já cobrou e quantas
## ações ainda cabem antes do desmaio.
##
## ## Por que uma aba, e não só a barra do topo
##
## A barra da barra de status responde "quanto resta", e é só isso que ela
## consegue dizer no canto do olho. A pergunta que decide o dia é outra —
## **quantas aradas ainda cabem?** — e ela precisa da tabela de custos ao lado
## do número. Tabela não cabe numa faixa de 32 pixels.
##
## ## Ela é o instrumento de calibragem da wave
##
## O teto de 200 e a tabela de custos são chute (wave 15, "Em aberto"). O
## número que resolve o chute é o **gasto de hoje, trabalho a trabalho**: se o
## dia inteiro gastou 90, o teto está alto e a estamina não compete com o
## relógio; se a barra zerou às 16:00, ela substituiu o relógio e o teto está
## baixo. É esta tela que mostra isso depois de um dia jogado ponta a ponta.
##
## ## Nenhum custo é calculado aqui
##
## Custo e quantas ações cabem são perguntas de **regra**, e as duas saem do
## `SistemaCorpo` — do mesmo jeito que `cota_de` e `pode_entregar` saem da
## cidade. Este arquivo pergunta e formata; quando a aba e a sim discordarem,
## quem errou é este arquivo (CLAUDE.md).
##
## A única soma deste lado é o gasto do dia, e ela não é regra: é o total do que
## os `EstaminaGastaEvent` já contaram, zerado na virada do dia. A sim não
## guarda diário de cansaço, e inventar um só para a tela seria state paralelo —
## mesma escolha do histórico de sessão do `PainelAmizade`.
##
## ## A mesa (wave 15.1)
##
## A metade de baixo da aba é o que dá para comer **agora**: a comida que está na
## mochila, com o valor já descontado da saciedade do dia. O número cru do
## `.tres` mentiria na terceira refeição, e é justamente essa diferença que cria
## a decisão de quando comer.
##
## A lista não é escrita aqui: ela sai do cruzamento entre a mochila (snapshot) e
## a pergunta `e_comida()` do sistema, que lê o `.tres`. Comida nova aparece
## nesta tela sozinha, como estabelecimento novo aparece na aba Cidade.
##
## O botão pergunta antes de despachar. `ComerAction` estende `RemoveItemAction`,
## então o pão sai da mochila no Inventory antes de o corpo olhar a barra: com a
## barra cheia, um clique errado queimaria 260g em silêncio (receita 2, §4).

## O nome de cada trabalho na tela. Os ids são da sim; o texto é daqui.
const NOMES: Dictionary = {
	SistemaCorpo.PLANTAR: "plantar",
	SistemaCorpo.COLHER: "colher",
	SistemaCorpo.REGAR: "regar",
	SistemaCorpo.ARAR: "arar",
	SistemaCorpo.LIMPAR_MATO: "limpar mato",
	SistemaCorpo.LIMPAR_PEDRA: "quebrar pedra",
	SistemaCorpo.LIMPAR_TOCO: "arrancar toco",
	SistemaCorpo.LIMPAR_ARVORE: "derrubar árvore",
}

## Altura da barra grande, na grade de 4px. Maior que a da barra de status: aqui
## há espaço, e esta é a tela onde se olha o corpo de propósito.
const ALTURA_DA_BARRA: float = 16.0

var _bridge: SimBridge

## O que o dia já cobrou, no total e por trabalho. Zera na virada do dia.
var _gasto_total: int = 0
var _gasto_por_trabalho: Dictionary = {}
var _vezes_por_trabalho: Dictionary = {}

var _barra: MedidorEstamina.Barra
var _corpo: Label
var _dia: Label
var _linhas: Dictionary = {}

## A mesa. As linhas são um bocado reaproveitado, como a fila da aba Cidade:
## comida entra e sai da mochila o dia inteiro, e recriar nó a cada evento
## custaria caro em ×60.
var _mesa: VBoxContainer
var _saciedade: Label
var _aviso: Label
var _ultimo_aviso: String = ""


## Padrão 3: recebe o fio e escuta. Quem entrega é o `PainelMochila` — esta aba
## é conteúdo do modal dele.
func setup(bridge: SimBridge) -> void:
	_bridge = bridge
	_monta()
	_bridge.sim_event.connect(_on_sim_event)
	_atualiza()


# --- Leitura: o que é regra vem do sistema ---

## Os trabalhos que a sim conhece, na ordem dela. A lista não mora nesta tela:
## trabalho novo aparece aqui sozinho.
func trabalhos() -> Array[String]:
	return SistemaCorpo.TRABALHOS

func custo(trabalho: String) -> int:
	var sistema := _sistema()
	return sistema.custo_de(trabalho) if sistema != null else 0

## Quantas ações deste tipo ainda cabem antes do desmaio.
func cabem(trabalho: String) -> int:
	var sistema := _sistema()
	return sistema.acoes_restantes(trabalho, SimFactory.PLAYER_PADRAO) if sistema != null else 0

func estamina() -> int:
	var sistema := _sistema()
	return sistema.estamina_de(SimFactory.PLAYER_PADRAO) if sistema != null else 0

func maxima() -> int:
	var sistema := _sistema()
	return sistema.maxima_de(SimFactory.PLAYER_PADRAO) if sistema != null else 0

## Quanto do corpo resta, de 0 a 1. A conta é do sistema: quem sabe o teto é o
## dono do state.
func fracao() -> float:
	var sistema := _sistema()
	return sistema.fracao_de(SimFactory.PLAYER_PADRAO) if sistema != null else 0.0


# --- Leitura: a mesa ---

## As comidas que estão na mochila agora, em ordem alfabética. A ordem não pode
## depender do slot em que o item caiu — a linha mudaria de lugar a cada colheita.
##
## Quem responde "isto se come?" é o sistema, lendo o `.tres`. Esta tela não tem
## lista de comida escrita em lugar nenhum.
func comidas() -> Array[String]:
	var sistema := _sistema()
	if sistema == null:
		return []
	var achadas: Array[String] = []
	for slot: Variant in _slots():
		if not slot is Dictionary:
			continue
		var item_id := String((slot as Dictionary).get("item_id", ""))
		if item_id.is_empty() or achadas.has(item_id):
			continue
		if sistema.e_comida(item_id):
			achadas.append(item_id)
	achadas.sort()
	return achadas

## Quantas unidades deste item a mochila tem. É contagem do snapshot, não regra.
func quantidade(item_id: String) -> int:
	var total := 0
	for slot: Variant in _slots():
		if not slot is Dictionary:
			continue
		var dados := slot as Dictionary
		if String(dados.get("item_id", "")) == item_id:
			total += int(dados.get("qtd", 0))
	return total

## Quanto esta comida restaura **agora**, com a saciedade do dia já aplicada. A
## conta é do sistema: o número cru do `.tres` mentiria na terceira refeição.
func restaura_agora(item_id: String) -> int:
	var sistema := _sistema()
	return sistema.restauro_de(item_id, SimFactory.PLAYER_PADRAO) if sistema != null else 0

## Qual refeição do dia vem a seguir — a primeira é 1.
func proxima_refeicao() -> int:
	var sistema := _sistema()
	return sistema.proxima_refeicao(SimFactory.PLAYER_PADRAO) if sistema != null else 1

## Quanto a próxima refeição vale, de 0 a 1.
func fator_agora() -> float:
	var sistema := _sistema()
	return sistema.fator_agora(SimFactory.PLAYER_PADRAO) if sistema != null else 1.0

## A sim deixa comer isto agora? A resposta é dela, nunca um `if` daqui.
func pode_comer(item_id: String) -> bool:
	var sistema := _sistema()
	return sistema.pode_comer(SimFactory.PLAYER_PADRAO, item_id) if sistema != null else false

## O que a sim respondeu da última vez que ela disse não.
func ultimo_aviso() -> String:
	return _ultimo_aviso

## Quantas linhas a mesa está desenhando.
func linhas_da_mesa() -> int:
	if _mesa == null:
		return 0
	var visiveis := 0
	for filho in _mesa.get_children():
		if (filho as Control).visible:
			visiveis += 1
	return visiveis


# --- Padrão 2: o botão ---

## Come. Pergunta antes porque esta ação cobra o item no Inventory antes de o
## corpo olhar a barra — despachar com a barra cheia queimaria o pão em silêncio.
func come(item_id: String) -> void:
	if not pode_comer(item_id):
		_mostra_aviso("a sim disse não: pode_comer(%s)" % item_id)
		return
	var acao := ComerAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.item_id = item_id
	acao.qtd = 1
	_bridge.dispatch(acao)


# --- Leitura: o que o dia já cobrou (soma de eventos, não de regra) ---

func gasto_do_dia() -> int:
	return _gasto_total

func gasto_hoje(trabalho: String) -> int:
	return int(_gasto_por_trabalho.get(trabalho, 0))

func vezes_hoje(trabalho: String) -> int:
	return int(_vezes_por_trabalho.get(trabalho, 0))


# --- Texto ---

func nome_de(trabalho: String) -> String:
	return String(NOMES.get(trabalho, trabalho))

## "custa 4 · cabem 12 · hoje 15 (60)". O "hoje" só aparece depois de o trabalho
## ter acontecido: uma coluna de zeros esconderia a linha que interessa.
func texto_da_linha(trabalho: String) -> String:
	var partes: Array[String] = [
		"custa %d" % custo(trabalho),
		"cabem %d" % cabem(trabalho),
	]
	var vezes := vezes_hoje(trabalho)
	if vezes > 0:
		partes.append("hoje %d (%d)" % [vezes, gasto_hoje(trabalho)])
	return " · ".join(partes)

## "180/200" — o número cru, do jeito que a sim o tem.
func texto_do_corpo() -> String:
	return "%d/%d" % [estamina(), maxima()]

## "gasto de hoje: 60 · resta 140". É a linha que calibra o teto de estamina.
func texto_do_dia() -> String:
	return "gasto de hoje: %d · resta %d" % [gasto_do_dia(), estamina()]

## O nome do item na tela. Sai do catálogo, como na aba Cidade.
func nome_do_item(item_id: String) -> String:
	if _bridge == null:
		return item_id
	var def := _bridge.get_item_catalog().get_def(item_id)
	return def.nome if def != null and not def.nome.is_empty() else item_id

## "Pão ×2 · +100". O `+` é o valor **efetivo** desta refeição, não o do `.tres`.
func texto_da_comida(item_id: String) -> String:
	return "%s ×%d · +%d" % [
		nome_do_item(item_id), quantidade(item_id), restaura_agora(item_id),
	]

## "próxima refeição: 2ª · vale 50%". É a linha que decide **quando** comer:
## comer cedo desperdiça a refeição cheia, comer tarde arrisca não chegar lá.
func texto_da_mesa() -> String:
	return "próxima refeição: %dª · vale %d%%" % [
		proxima_refeicao(), roundi(fator_agora() * 100.0),
	]


# --- Montagem ---

func _monta() -> void:
	add_child(_titulo("Corpo"))

	var caixa := VBoxContainer.new()
	caixa.theme_type_variation = &"Grupo"
	add_child(caixa)

	_barra = MedidorEstamina.Barra.new()
	_barra.custom_minimum_size = Vector2(0, ALTURA_DA_BARRA)
	caixa.add_child(_barra)

	_corpo = Label.new()
	_corpo.theme_type_variation = &"Dado"
	caixa.add_child(_corpo)

	_dia = Label.new()
	_dia.theme_type_variation = &"Micro"
	caixa.add_child(_dia)

	add_child(_titulo("O que cada trabalho custa"))
	for trabalho in trabalhos():
		_linhas[trabalho] = _linha(nome_de(trabalho))

	var nota := Label.new()
	nota.theme_type_variation = &"Micro"
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.text = "O CORPO NÃO RECUSA AÇÃO. AO CHEGAR A ZERO O DIA ACABA," \
		+ " E VOCÊ ACORDA COM METADE. ANDAR NÃO CANSA."
	add_child(nota)

	_monta_mesa()

func _monta_mesa() -> void:
	add_child(_titulo("O que dá para comer"))

	_saciedade = Label.new()
	_saciedade.theme_type_variation = &"Dado"
	add_child(_saciedade)

	_mesa = VBoxContainer.new()
	add_child(_mesa)

	_aviso = Label.new()
	_aviso.theme_type_variation = &"Micro"
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_aviso)

## Uma linha da mesa: o que é, quanto vale agora, e o botão. As linhas são
## reaproveitadas — o botão pergunta pelo índice qual comida está nele agora,
## para não reconectar sinal a cada evento.
func _linha_da_mesa(indice: int) -> HBoxContainer:
	var caixa := HBoxContainer.new()

	var rotulo := Label.new()
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.add_child(rotulo)

	var botao := Button.new()
	botao.text = "Comer"
	botao.pressed.connect(_come_a_linha.bind(indice))
	caixa.add_child(botao)

	_mesa.add_child(caixa)
	return caixa

## O clique do botão da linha `indice`. Lê a comida na hora: a mesa muda a cada
## colheita, e um `bind` do id envelheceria junto.
func _come_a_linha(indice: int) -> void:
	var lista := comidas()
	if indice < 0 or indice >= lista.size():
		return
	come(lista[indice])

func _mostra_mesa() -> void:
	var lista := comidas()
	while _mesa.get_child_count() < lista.size():
		_linha_da_mesa(_mesa.get_child_count())

	for i in _mesa.get_child_count():
		var linha := _mesa.get_child(i) as HBoxContainer
		linha.visible = i < lista.size()
		if not linha.visible:
			continue
		(linha.get_child(0) as Label).text = texto_da_comida(lista[i])

	_saciedade.text = texto_da_mesa() if not lista.is_empty() \
		else "nada para comer na mochila"

func _mostra_aviso(texto: String) -> void:
	_ultimo_aviso = texto
	if _aviso != null:
		_aviso.text = texto

func _linha(nome: String) -> Label:
	var caixa := HBoxContainer.new()
	add_child(caixa)

	var rotulo := Label.new()
	rotulo.text = nome
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caixa.add_child(rotulo)

	var dado := Label.new()
	dado.theme_type_variation = &"Dado"
	caixa.add_child(dado)
	return dado

func _titulo(texto: String) -> Label:
	var label := Label.new()
	label.text = texto.to_upper()
	label.theme_type_variation = &"Micro"
	return label


# --- Evento vira tela ---

## O minuto que passa não mexe no corpo: estamina anda por trabalho feito e pela
## virada do dia. Ignorar o tick é o que deixa esta aba de graça em ×60.
func _on_sim_event(event: SimEvent) -> void:
	if event is MinuteTickedEvent:
		return
	if event is EstaminaGastaEvent:
		_anota(event as EstaminaGastaEvent)
	if event is DayEndedEvent:
		_zera_o_dia()
	if event is ActionRejectedEvent:
		var recusa := event as ActionRejectedEvent
		if recusa.acao == "ComerAction":
			_mostra_aviso("a sim recusou ComerAction: %s" % recusa.motivo)
	_atualiza()

## O evento já traz o custo cobrado; esta tela não recalcula nada — ela soma o
## que foi contado.
func _anota(event: EstaminaGastaEvent) -> void:
	if event.player_id != SimFactory.PLAYER_PADRAO:
		return
	_gasto_total += event.custo
	_gasto_por_trabalho[event.trabalho] = gasto_hoje(event.trabalho) + event.custo
	_vezes_por_trabalho[event.trabalho] = vezes_hoje(event.trabalho) + 1

func _zera_o_dia() -> void:
	_gasto_total = 0
	_gasto_por_trabalho = {}
	_vezes_por_trabalho = {}

func _atualiza() -> void:
	if _bridge == null:
		return
	_barra.mostra(fracao(), _cor())
	_corpo.text = texto_do_corpo()
	_dia.text = texto_do_dia()
	for trabalho: String in _linhas:
		(_linhas[trabalho] as Label).text = texto_da_linha(trabalho)
	_mostra_mesa()

## A mesma cor da barra de status, pelas mesmas faixas — duas telas do mesmo
## número não podem discordar sobre quando ele fica vermelho.
func _cor() -> Color:
	var quanto := fracao()
	if quanto <= MedidorEstamina.LIMITE_BEIRA:
		return Paleta.ALERTA
	if quanto <= MedidorEstamina.LIMITE_ATENCAO:
		return Paleta.OURO
	return Paleta.VERDE


# --- De onde vêm os dados ---

## O sistema é dono das perguntas de regra; achar quem responde é problema de
## quem pergunta. `game/` nunca guarda referência de state — só de quem sabe.
func _sistema() -> SistemaCorpo:
	if _bridge == null:
		return null
	for system in _bridge.get_world().get_systems():
		if system is SistemaCorpo:
			return system as SistemaCorpo
	return null

## Os stacks da mochila, crus, como vieram do snapshot — a mesma foto que o save
## grava. Contar item não é regra; o que é regra (o que se come, quanto vale) sai
## do sistema.
func _slots() -> Array:
	if _bridge == null:
		return []
	var inventario: Dictionary = _bridge.get_world().snapshot() \
		.get(SimFactory.CHAVE_INVENTORY, {})
	var jogador: Variant = inventario.get(str(SimFactory.PLAYER_PADRAO), {})
	if not jogador is Dictionary:
		return []
	return (jogador as Dictionary).get("slots", [])
