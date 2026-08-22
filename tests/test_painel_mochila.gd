extends GutTest

## O painel da mochila: o inventário em tela cheia, no Tab.
##
## Os testes daqui cobrem as três coisas que quebram calado num painel modal:
## a capacidade que some da tela, o clique que vira ação errada, e o mundo que
## continua andando atrás do painel.

var _bridge: SimBridge
var _playground: Playground
var _painel: PainelMochila


func before_each() -> void:
	_bridge = SimBridge.new()
	_bridge.auto_tick = false
	add_child_autofree(_bridge)
	await get_tree().process_frame
	for filho in _bridge.get_children():
		var janela := filho as PlaygroundWindow
		if janela != null:
			_playground = janela.get_node("Playground") as Playground
	_painel = _playground.get_node("PainelMochila") as PainelMochila


func _da_item(item_id: String, qtd: int) -> void:
	var acao := AddItemAction.new()
	acao.player_id = SimFactory.PLAYER_PADRAO
	acao.item_id = item_id
	acao.qtd = qtd
	_bridge.dispatch(acao)


func test_nasce_fechado() -> void:
	assert_false(_painel.aberto(), "o painel não pode nascer por cima do mundo")

func test_tab_abre_e_fecha() -> void:
	_painel.alterna()
	assert_true(_painel.aberto())
	_painel.alterna()
	assert_false(_painel.aberto())


# --- Hotbar ---

func test_a_hotbar_fica_visivel_com_o_painel_fechado() -> void:
	# É ela que responde "o que está na minha mão?" sem interromper o jogo.
	assert_false(_painel.aberto(), "o painel começa fechado")
	assert_true(_painel.hotbar_visivel(), "e a hotbar continua na tela")

func test_a_hotbar_mostra_os_oito_primeiros_slots() -> void:
	# GAMEPLAY §4: hotbar de 8 slots. A mochila tem 24 — a hotbar é a fatia de
	# cima dela, não uma segunda mochila.
	assert_eq(_painel.slots_da_hotbar(), PainelMochila.SLOTS_HOTBAR)

func test_a_mao_comeca_na_enxada() -> void:
	assert_eq(_painel.item_na_mao(), "enxada",
		"slot 0 da entrega inicial — dá para arar sem abrir nada")

func test_equipar_troca_o_item_na_mao() -> void:
	_painel.equipa(1)
	assert_eq(_painel.item_na_mao(), "regador", "o slot 1 é o regador")
	assert_eq(_painel.slot_na_mao(), 1)

## A tecla e o clique passam pelo mesmo caminho: uma `EquiparSlotAction`. Se um
## dia divergirem, é porque alguém mexeu no state por fora.
func test_equipar_e_uma_acao_da_sim() -> void:
	_painel.equipa(2)
	var jogador: Dictionary = _bridge.get_world().snapshot() \
		.get(SimFactory.CHAVE_INVENTORY, {}).get("0", {})
	assert_eq(int(jogador.get("slot_na_mao", -1)), 2,
		"a mão tem que estar no snapshot — é ele que vai para o save")

## O slot na mão precisa se distinguir de relance — sem ler o texto. Se o
## destaque some, a hotbar deixa de responder "o que este clique vai fazer?", e
## aí ela não serve para nada.
func test_o_slot_na_mao_tem_destaque_proprio() -> void:
	_painel.equipa(1)
	var quadrados := _painel._hotbar.get_children()

	assert_eq((quadrados[1] as Button).theme_type_variation, &"SlotNaMao",
		"o slot da mão perdeu o destaque")
	assert_ne((quadrados[0] as Button).theme_type_variation, &"SlotNaMao",
		"dois slots destacados ao mesmo tempo")

func test_o_destaque_fica_mesmo_com_a_mao_vazia() -> void:
	# Mão vazia é um lugar legítimo — é com ela que se colhe.
	_painel.equipa(PainelMochila.SLOTS_HOTBAR - 1)
	var ultimo := _painel._hotbar.get_child(PainelMochila.SLOTS_HOTBAR - 1) as Button
	assert_eq(ultimo.theme_type_variation, &"SlotNaMao")

func test_equipar_slot_vazio_esvazia_a_mao() -> void:
	_painel.equipa(PainelMochila.SLOTS_HOTBAR - 1)
	assert_eq(_painel.item_na_mao(), "", "slot sem item é mão vazia, e mão vazia colhe")

func test_o_mundo_congela_com_o_painel_aberto() -> void:
	# Andar ou arar atrás de um painel modal é o tipo de bug que só aparece
	# quando alguém está distraído — e aí ninguém sabe reproduzir.
	var mundo := _playground.get_mundo()
	_painel.alterna()
	assert_true(mundo.congelado(), "o mundo continuou vivo atrás do painel")
	_painel.alterna()
	assert_false(mundo.congelado(), "o mundo não descongelou ao fechar")

func test_a_mochila_mostra_os_slots_vazios() -> void:
	# Capacidade só vira decisão quando é vista antes de encher.
	_painel.abre()
	var capacidade := _painel.capacidade()
	assert_gt(capacidade, 0, "sem capacidade não há o que mostrar")
	assert_eq(_painel.slots_desenhados(), capacidade,
		"a grade tem que ter um quadrado por slot, cheio ou vazio")

## Quanto o painel está mostrando de um item, somando os stacks. A partida
## começa com 5 sementes na mochila (GAMEPLAY §5), então contar em absoluto
## daria falso: o que importa é o que mudou.
func _na_mochila(item_id: String) -> int:
	var total := 0
	for entrada: Variant in _painel.slots_ocupados():
		var slot: Dictionary = entrada
		if String(slot.get("item_id", "")) == item_id:
			total += int(slot.get("qtd", 0))
	return total

func _no_caixote(item_id: String) -> int:
	var total := 0
	for entrada: Variant in _painel.itens_do_caixote():
		var item: Dictionary = entrada
		if String(item.get("item_id", "")) == item_id:
			total += int(item.get("qtd", 0))
	return total


func test_o_item_aparece_no_slot_com_a_quantidade() -> void:
	var antes := _na_mochila("semente_cenoura")
	_da_item("semente_cenoura", 4)
	_painel.abre()

	assert_eq(_na_mochila("semente_cenoura"), antes + 4,
		"o painel não mostrou o que entrou na mochila")

func test_clicar_na_mochila_manda_para_o_caixote() -> void:
	_da_item("semente_cenoura", 4)
	_painel.abre()
	var antes := _na_mochila("semente_cenoura")

	_painel.transfere_da_mochila("semente_cenoura", 4)

	assert_eq(_na_mochila("semente_cenoura"), antes - 4, "não saiu da mochila")
	assert_eq(_no_caixote("semente_cenoura"), 4, "não chegou no caixote")

func test_clicar_no_caixote_traz_de_volta() -> void:
	_da_item("semente_cenoura", 4)
	_painel.abre()
	var antes := _na_mochila("semente_cenoura")
	_painel.transfere_da_mochila("semente_cenoura", 4)

	_painel.transfere_do_caixote("semente_cenoura", 4)

	assert_eq(_no_caixote("semente_cenoura"), 0, "não saiu do caixote")
	assert_eq(_na_mochila("semente_cenoura"), antes, "não voltou para a mochila")

## Desde a wave 11.3 a lista tem sempre `capacity` posições, então o que muda
## ao ganhar um item é quantas estão ocupadas — não o tamanho da lista.
func _slots_com_item() -> int:
	var total := 0
	for entrada: Variant in _painel.slots_ocupados():
		var slot: Dictionary = entrada
		if not String(slot.get("item_id", "")).is_empty():
			total += 1
	return total

func test_o_painel_acompanha_a_sim_sem_perguntar_duas_vezes() -> void:
	# Tudo o que ele mostra sai do snapshot — a mesma foto que o save grava.
	_painel.abre()
	var antes := _slots_com_item()
	_da_item("semente_cenoura", 2)
	assert_eq(_slots_com_item(), antes + 1,
		"o painel aberto não reagiu ao evento da sim")

# --- Arrastar ---

## O gesto que o playtest pediu duas vezes: pôr o item **onde se quer**. Aqui o
## teste chama `move` direto; o arrastar de verdade é o Godot chamando o mesmo
## método pelo `_drop_data`.
func test_arrastar_leva_o_item_para_o_slot_escolhido() -> void:
	_painel.abre()
	assert_eq(_painel.item_no_slot(0), "enxada", "a enxada começa no slot 0")

	_painel.move(0, 5)

	assert_eq(_painel.item_no_slot(5), "enxada", "o item não foi para onde foi solto")
	assert_eq(_painel.item_no_slot(0), "", "e a origem não ficou livre")

func test_arrastar_para_slot_ocupado_troca_os_dois() -> void:
	_painel.abre()

	_painel.move(0, 1)

	assert_eq(_painel.item_no_slot(0), "regador", "os dois tinham que trocar")
	assert_eq(_painel.item_no_slot(1), "enxada")

## O quadrado é arrastável de verdade — não é um `Button` comum com um clique
## disfarçado. Sem isso o gesto simplesmente não existe para o Godot.
func test_o_quadrado_da_hotbar_sabe_o_proprio_endereco() -> void:
	var terceiro := _painel._hotbar.get_child(2) as SlotArrastavel
	assert_not_null(terceiro, "o slot da hotbar tem que ser arrastável")
	assert_eq(terceiro.indice, 2, "sem endereço, soltar não sabe para onde ir")

func test_slot_vazio_nao_e_origem_mas_e_destino() -> void:
	# Soltar num buraco é o gesto mais comum de todos; arrastar o vazio não é
	# gesto nenhum.
	var vazio := _painel._hotbar.get_child(PainelMochila.SLOTS_HOTBAR - 1) as SlotArrastavel
	assert_false(vazio.tem_item, "slot vazio não começa arrasto")
	assert_true(vazio._can_drop_data(Vector2.ZERO, {"slot_de": 0}), "mas recebe o que for solto")

## A hotbar e a mochila são os mesmos slots, então arrastar de uma para a outra
## é mover entre índices — não existe um segundo inventário para dessincronizar.
func test_arrastar_da_mochila_para_a_hotbar_e_o_mesmo_movimento() -> void:
	_da_item("semente_cenoura", 3)
	_painel.abre()
	var origem := _slot_de("semente_cenoura")

	_painel.move(origem, 4)

	assert_eq(_painel.item_no_slot(4), "semente_cenoura",
		"o item não chegou na tecla 5")

func _slot_de(item_id: String) -> int:
	var slots: Array = _painel.slots_ocupados()
	for i in slots.size():
		var slot: Dictionary = slots[i]
		if String(slot.get("item_id", "")) == item_id:
			return i
	return -1

func test_o_dinheiro_e_o_mesmo_da_barra() -> void:
	var moedas := AddMoneyAction.new()
	moedas.player_id = SimFactory.PLAYER_PADRAO
	moedas.valor = 100
	_bridge.dispatch(moedas)
	_painel.abre()

	assert_string_contains(_painel._dinheiro.text, "g",
		"o dinheiro do painel sai com a unidade, como na barra")

func test_o_status_panel_nao_lista_mais_a_mochila() -> void:
	# Duas telas para a mesma coisa é uma para desatualizar.
	var painel := _playground.get_node(
		"Raiz/Corpo/Rail/RolagemRail/ColunaRail/StatusPanel") as StatusPanel
	assert_null(painel.get("_lista_mochila"),
		"a lista velha continua no rail — agora quem mostra é o Tab")


# --- os ícones ------------------------------------------------------------

const ICONE_DE_TESTE: String = "res://tests/dados/icone_de_teste.png"

## Procura a imagem dentro de um slot. O ícone é um filho do botão, e não o
## `icon` dele, porque o texto do botão fica no meio do quadrado — e no meio ele
## cobriria o desenho.
func _imagem_no_slot(slot: Control) -> TextureRect:
	for filho in slot.get_children():
		var imagem := filho as TextureRect
		if imagem != null:
			return imagem
	return null

## O jogador já começa com enxada e regador nos primeiros slots — procurar pelo
## item é o que mantém o teste válido quando a entrega inicial mudar.
func _quadrado_de(item_id: String) -> Button:
	return _painel._mochila.get_child(_slot_de(item_id)) as Button

func _com_icone(item_id: String) -> void:
	_bridge.get_item_catalog().get_def(item_id).sprite = ICONE_DE_TESTE
	Icones.esquece_tudo()

## O slot mostra o desenho quando o `.tres` do item aponta um.
func test_slot_com_arte_mostra_o_icone() -> void:
	_com_icone("trigo")
	_da_item("trigo", 3)
	_painel.abre()

	var imagem := _imagem_no_slot(_quadrado_de("trigo"))
	assert_not_null(imagem, "o slot desenha o sprite do item")
	assert_not_null(imagem.texture)

## E continua legível enquanto a arte não chegou — que é o estado da maioria dos
## itens hoje. O playground não pode depender de arte para ser jogável.
func test_slot_sem_arte_continua_mostrando_o_nome() -> void:
	Icones.esquece_tudo()
	_da_item("cenoura", 2)
	_painel.abre()

	var slot: Button = _quadrado_de("cenoura")
	assert_null(_imagem_no_slot(slot), "sem sprite no .tres, sem imagem")
	assert_string_contains(slot.text, "Cenoura", "o nome escrito não sai de cena")
	assert_string_contains(slot.text, "2")

## Pixel art de 16px num slot de 72px é ampliada 4×. Qualquer filtro que não
## seja nearest borra o desenho — e borrado ele deixa de ser pixel art.
func test_o_icone_nao_borra_ao_ser_ampliado() -> void:
	_com_icone("trigo")
	_da_item("trigo", 1)
	_painel.abre()

	var imagem := _imagem_no_slot(_quadrado_de("trigo"))
	assert_eq(imagem.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(imagem.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"o sprite não estica — um regador alto continua alto")

## E é ampliada em escala **inteira**. `nearest` não borra, mas num aumento de
## 3,25× ele desenha umas colunas do sprite com 3px e outras com 4px: o contorno
## fica mordido e a arte parece mal desenhada estando perfeita no arquivo. É a
## mesma proibição do zoom não-inteiro da câmera (GAMEPLAY §2), aplicada ao slot.
func test_o_icone_e_ampliado_em_escala_inteira() -> void:
	_com_icone("trigo")
	_da_item("trigo", 1)
	_painel.abre()

	var imagem := _imagem_no_slot(_quadrado_de("trigo"))
	var sprite := imagem.texture.get_size()
	var escala := imagem.custom_minimum_size.x / sprite.x
	assert_eq(escala, floorf(escala), "escala quebrada é o que deixa o pixel torto")
	assert_gt(escala, 1.0, "e o ícone ainda precisa encher o slot")
	assert_eq(imagem.custom_minimum_size.y / sprite.y, escala,
		"a mesma escala nos dois eixos — senão o sprite deforma")

## Na hotbar vale igual, com o quadrado menor.
func test_o_icone_da_hotbar_tambem_e_escala_inteira() -> void:
	_com_icone("trigo")
	_da_item("trigo", 1)

	var imagem := _imagem_no_slot(_painel._hotbar.get_child(_slot_de("trigo")) as Control)
	var escala := imagem.custom_minimum_size.x / imagem.texture.get_size().x
	assert_eq(escala, floorf(escala), "o slot menor não é desculpa para pixel torto")

## O clique é do botão, não da imagem: um `TextureRect` que come o mouse faria
## o slot parar de responder justamente quando ele tem item.
func test_o_icone_nao_rouba_o_clique_do_slot() -> void:
	_com_icone("trigo")
	_da_item("trigo", 5)
	_painel.abre()

	assert_eq(_imagem_no_slot(_quadrado_de("trigo")).mouse_filter,
		Control.MOUSE_FILTER_IGNORE)

## Na hotbar o número da tecla nunca sai — é ele que liga o quadrado ao dedo, e
## é o que se olha no meio de uma corrida.
func test_a_hotbar_mostra_o_icone_sem_perder_o_numero_da_tecla() -> void:
	_com_icone("trigo")
	_da_item("trigo", 4)

	var indice := _slot_de("trigo")
	var slot: Button = _painel._hotbar.get_child(indice) as Button
	assert_not_null(_imagem_no_slot(slot), "o sprite entrou")
	assert_eq(slot.text, str(indice + 1), "e a tecla continua escrita")
