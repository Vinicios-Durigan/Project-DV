extends GutTest

## O juice da wave 11: tremida, achatada, piscada, arco e pulso.
##
## Testar "está bonito?" não dá — isso se resolve jogando. O que dá para testar
## é o que quebraria o jogo em silêncio:
##
## 1. **Juice não mexe em regra.** Todo efeito termina sozinho e some; nenhum
##    deles guarda estado que a sim precise saber.
## 2. **Juice não move o alvo.** A tremida sacode o desenho, mas a origem que
##    traduz mouse em tile fica parada. Sem isso, um clique durante a tremida
##    poderia arar o canteiro do lado — e o bug seria intermitente, do pior
##    tipo.

var _mundo: MundoEsboco


func before_each() -> void:
	_mundo = MundoEsboco.new()
	_mundo.size = Vector2(800, 400)
	autofree(_mundo)


func _tilled(x: int, y: int) -> PlotTilledEvent:
	var evento := PlotTilledEvent.new()
	evento.x = x
	evento.y = y
	return evento

func _harvested(x: int, y: int) -> CropHarvestedEvent:
	var evento := CropHarvestedEvent.new()
	evento.x = x
	evento.y = y
	return evento


func test_arar_sacode_a_tela() -> void:
	assert_eq(_mundo._tremida, 0.0, "nasce parado")
	_mundo._reage_com_juice(_tilled(2, 3))
	assert_gt(_mundo._tremida, 0.0, "arar tinha que sacudir")

func test_a_tremida_nao_move_o_alvo_do_clique() -> void:
	var antes := _mundo._origem_mapa()
	_mundo._reage_com_juice(_tilled(2, 3))
	_mundo._avanca_juice(0.016)
	assert_eq(_mundo._origem_mapa(), antes,
		"a origem da mira andou — clique durante a tremida acertaria outro tile")
	assert_ne(_mundo._origem_desenho(), antes, "mas o desenho tinha que ter sacudido")

func test_todo_efeito_termina_sozinho() -> void:
	_mundo._reage_com_juice(_tilled(1, 1))
	_mundo._reage_com_juice(_harvested(2, 2))
	# Um segundo é mais que qualquer duração declarada.
	_mundo._avanca_juice(1.0)

	assert_eq(_mundo._tremida, 0.0, "tremida presa")
	assert_eq(_mundo._achatada, 0.0, "achatada presa")
	assert_eq(_mundo._piscadas, {}, "piscada presa")
	assert_eq(_mundo._voos, [] as Array[Dictionary], "quadradinho preso no ar")

func test_colher_manda_um_quadradinho_voando() -> void:
	_mundo._reage_com_juice(_harvested(4, 1))
	assert_eq(_mundo._voos.size(), 1, "a colheita voa em arco até o jogador")
	assert_eq(_mundo._voos[0]["de"], Vector2i(4, 1), "sai do canteiro colhido")

func test_crescer_pisca_mas_nao_da_swing() -> void:
	# Manhã-espetáculo: quem trabalhou foi a noite, não o jogador.
	var cresceu := CropGrewEvent.new()
	cresceu.x = 0
	cresceu.y = 0
	_mundo._reage_com_juice(cresceu)
	assert_gt(float(_mundo._piscadas.get("0:0", 0.0)), 0.0, "o canteiro tinha que piscar")
	assert_eq(_mundo._achatada, 0.0, "ninguém deu swing na cascata da manhã")

func test_o_swing_mantem_os_pes_no_chao() -> void:
	var corpo := Rect2(Vector2(100, 100), Vector2(20, 40))
	_mundo._reage_com_juice(_tilled(0, 0))
	var achatado := _mundo._achata(corpo)

	assert_almost_eq(achatado.end.y, corpo.end.y, 0.01, "o corpo afundou no chão")
	assert_lt(achatado.size.y, corpo.size.y, "não achatou")
	assert_gt(achatado.size.x, corpo.size.x, "achatar sem alargar não tem peso")

func test_parado_nao_e_andando() -> void:
	# É a única pergunta que o medidor do dia faz a este nó.
	assert_false(_mundo.esta_andando(), "sem tecla apertada, ninguém anda")
