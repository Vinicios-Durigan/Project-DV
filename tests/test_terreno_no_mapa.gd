extends GutTest

## O terreno aparece **no mapa**, não numa coluna de debug.
##
## É a regra travada na wave 12.1: mecânica só está pronta com tela própria,
## ponto no mundo e contagem visível. Para o terreno isso quer dizer que o
## jogador vê o mato avançar durante a noite — sem isso não há como calibrar a
## propagação jogando, que é o número mais incerto desta wave.

var _mundo: MundoEsboco


func before_each() -> void:
	_mundo = MundoEsboco.new()
	_mundo.size = Vector2(800, 400)
	autofree(_mundo)

func _mudou(x: int, y: int, para: String, motivo: String) -> TerrenoMudouEvent:
	var evento := TerrenoMudouEvent.new()
	evento.x = x
	evento.y = y
	evento.de = EstadoTerreno.LIVRE
	evento.para = para
	evento.motivo = motivo
	return evento


# --- A cor de cada cobertura ---

func test_cada_cobertura_tem_a_sua_cor() -> void:
	var vistas: Array[Color] = []
	for cobertura in [EstadoTerreno.MATO, EstadoTerreno.PEDRA, EstadoTerreno.ARVORE,
			EstadoTerreno.TOCO, EstadoTerreno.AGUA]:
		var cor := PaletaTerreno.cor_de(cobertura)
		assert_false(vistas.has(cor), "%s repetiu a cor de outra cobertura" % cobertura)
		vistas.append(cor)

func test_chao_livre_nao_pinta_nada() -> void:
	assert_eq(PaletaTerreno.cor_de(EstadoTerreno.LIVRE), Paleta.NADA,
			"livre é ausência — quem desenha continua usando o canal da terra")
	assert_false(PaletaTerreno.cobre(EstadoTerreno.LIVRE))
	assert_false(PaletaTerreno.cobre(""), "cobertura vazia também é chão")

func test_cobertura_desconhecida_nao_inventa_cor() -> void:
	assert_eq(PaletaTerreno.cor_de("lava"), Paleta.NADA,
			"cobertura que a tela não conhece não pode virar retângulo colorido")


# --- O juice ---

func test_o_mato_da_noite_pisca_sem_swing() -> void:
	_mundo._reage_com_juice(_mudou(2, 2, EstadoTerreno.MATO, TerrenoMudouEvent.POR_INVASAO))
	assert_gt(_mundo._piscadas.size(), 0, "o avanço da noite tem que ser visto")
	assert_eq(_mundo._achatada, 0.0,
			"ninguém deu golpe nenhum — quem trabalhou foi a noite")

func test_limpar_bate_como_toda_ferramenta() -> void:
	_mundo._reage_com_juice(_mudou(2, 2, EstadoTerreno.LIVRE, TerrenoMudouEvent.POR_LIMPEZA))
	assert_gt(_mundo._achatada, 0.0, "capinar é swing, e swing achata o jogador")
	assert_gt(_mundo._piscadas.size(), 0, "e o tile pisca junto")

func test_o_fechamento_do_arado_pisca() -> void:
	_mundo._reage_com_juice(_mudou(3, 3, EstadoTerreno.MATO, TerrenoMudouEvent.POR_FECHAMENTO))
	assert_gt(_mundo._piscadas.size(), 0,
			"perder o preparo sem ver acontecer seria bug silencioso")

func test_a_piscada_do_terreno_termina_sozinha() -> void:
	_mundo._reage_com_juice(_mudou(2, 2, EstadoTerreno.MATO, TerrenoMudouEvent.POR_INVASAO))
	_mundo._avanca_juice(1.0)
	assert_eq(_mundo._piscadas, {}, "efeito que não termina vira mancha na tela")

func test_o_mapa_nao_se_move_por_causa_do_terreno() -> void:
	var antes := _mundo._origem_mapa()
	_mundo._reage_com_juice(_mudou(2, 2, EstadoTerreno.MATO, TerrenoMudouEvent.POR_INVASAO))
	assert_eq(_mundo._origem_mapa(), antes,
			"o mato não sacode a tela — tremida é assinatura da enxada")


# --- O nome que a tela escreve ---

func test_o_nome_da_cobertura_e_legivel() -> void:
	assert_eq(PaletaTerreno.nome_de(EstadoTerreno.ARVORE), "árvore",
			"o id é de máquina; o texto com acento é da tela")
	assert_eq(PaletaTerreno.nome_de(EstadoTerreno.LIVRE), "livre")
