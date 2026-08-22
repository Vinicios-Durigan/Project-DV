extends GutTest

## O regador acaba — e o quanto ainda tem mora no **slot**, não no jogador.
##
## ## Por que no slot
##
## Com dois regadores na mochila (o velho e o do ferreiro, que vem na wave dele),
## um número guardado no jogador teria que pertencer a um dos dois. Pertencendo
## ao slot, cada um carrega o seu desde o primeiro dia, e trocar de mão não
## mistura nada.
##
## ## Carga é estado, capacidade é balanceamento
##
## `Slot.carga` é quanto tem agora e vai no save; `ItemDef.capacidade_carga` é
## quanto cabe, e é um número que o designer edita no `.tres` sem tocar em
## código. Capacidade **zero** descreve corretamente tudo o que já existe: a
## enxada não carrega água, o trigo não carrega nada.
##
## ## Sem migração
##
## Campo novo com default 0. Save de antes desta wave abre com o regador vazio,
## o jogador enche no primeiro poço e nunca percebe que faltava um número.

var _estado: InventoryState


func before_each() -> void:
	_estado = InventoryState.new()


# --- O campo ---

func test_slot_nasce_sem_carga() -> void:
	assert_eq(InventoryState.Slot.new().carga, 0,
			"tudo o que já existe carrega zero — é o default que preserva o passado")

func test_slot_com_item_continua_nascendo_sem_carga() -> void:
	assert_eq(InventoryState.Slot.new("regador", 1).carga, 0,
			"regador novo vem vazio: encher é a primeira ida ao poço")

func test_carga_nao_faz_slot_vazio_parecer_cheio() -> void:
	var slot := InventoryState.Slot.new()
	slot.carga = 5
	assert_true(slot.vazio(),
			"posição sem item é livre, tenha o número que tiver sobrado nela")

func test_esvaziar_leva_a_carga_junto() -> void:
	var slot := InventoryState.Slot.new("regador", 1)
	slot.carga = 9
	slot.esvazia()
	assert_eq(slot.carga, 0,
			"a água era do regador que estava ali — não fica de herança para o próximo")


# --- A capacidade, no .tres ---

func test_item_comum_nao_carrega_nada() -> void:
	assert_eq(ItemDef.new().capacidade_carga, 0,
			"capacidade zero descreve a enxada, o trigo e todo o resto")

func test_o_regador_do_jogo_tem_capacidade() -> void:
	var items := ItemCatalog.new()
	items.load_from_dir()
	assert_gt(items.get_def("regador").capacidade_carga, 0,
			"sem isso a mecânica inteira fica desligada no conteúdo")

func test_so_o_regador_carrega() -> void:
	var items := ItemCatalog.new()
	items.load_from_dir()
	var carregam: Array[String] = []
	for id in items.ids():
		if items.get_def(id).capacidade_carga > 0:
			carregam.append(id)
	assert_eq(carregam, ["regador"] as Array[String],
			"item que carrega sem ter para onde despejar seria número morto")


# --- Save ---

func test_a_carga_viaja_no_save() -> void:
	var inv := _estado.get_player(0)
	inv.slots[0] = InventoryState.Slot.new("regador", 1)
	inv.slots[0].carga = 7

	var outro := InventoryState.new()
	outro.from_dict(_estado.to_dict())

	assert_eq(outro.get_player(0).slots[0].carga, 7,
			"dormir com meio regador e acordar com ele cheio seria água de graça")

func test_save_de_antes_da_wave_abre_com_o_regador_vazio() -> void:
	var antigo := {
		"0": {
			"slots": [{"item_id": "regador", "qtd": 1}],
			"capacity": 24,
			"dinheiro": 500,
			"slot_na_mao": 0,
		},
	}
	_estado.from_dict(antigo)

	var slot := _estado.get_player(0).slots[0]
	assert_eq(slot.item_id, "regador", "o regador continua na mochila")
	assert_eq(slot.carga, 0,
			"campo ausente cai no default — sem migração, e o jogador só precisa"
			+ " passar no poço")

func test_carga_negativa_no_save_e_lixo() -> void:
	_estado.from_dict({"0": {"slots": [{"item_id": "regador", "qtd": 1, "carga": -3}]}})
	assert_eq(_estado.get_player(0).slots[0].carga, 0, "não se deve água ao poço")
