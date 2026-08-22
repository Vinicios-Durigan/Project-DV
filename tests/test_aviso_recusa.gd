extends GutTest

## "Toda recusa diz o porquê" é decisão travada do design system v1: "não deu"
## não existe neste projeto. O toast é quem cumpre isso na tela.
##
## O teste guarda a parte que apodrece sozinha: a tradução de `motivo` — que é
## id de máquina — para a frase que o jogador lê. Motivo novo em `sim/` sem
## frase aqui vira "recusado (motivo_cru)", e este teste falha apontando qual.

var _aviso: AvisoRecusa


func before_each() -> void:
	_aviso = AvisoRecusa.new()
	autofree(_aviso)


func _recusa(motivo: String, acao: String = "WaterPlotAction") -> ActionRejectedEvent:
	var evento := ActionRejectedEvent.new()
	evento.acao = acao
	evento.motivo = motivo
	return evento


func test_todo_motivo_da_sim_tem_frase() -> void:
	# A lista sai das constantes dos sistemas, não de uma cópia à mão: motivo
	# novo entra aqui no dia em que o sistema o declara.
	var motivos: Array[String] = [
		SistemaLocais.MOTIVO_FORA_DO_LOCAL,
		SistemaLocais.MOTIVO_JA_NO_LOCAL,
		SistemaLocais.MOTIVO_DESTINO_DESCONHECIDO,
		FarmSystem.MOTIVO_TILE_NAO_ARADO,
		FarmSystem.MOTIVO_TILE_OCUPADO,
		FarmSystem.MOTIVO_CULTURA_DESCONHECIDA,
		InventorySystem.MOTIVO_ITEM_INSUFICIENTE,
		InventorySystem.MOTIVO_DINHEIRO_INSUFICIENTE,
	]
	for motivo in motivos:
		assert_true(AvisoRecusa.FRASES.has(motivo),
			"motivo '%s' sem frase — o jogador leria o id cru" % motivo)

func test_a_frase_explica_o_porque() -> void:
	var texto := _aviso.frase_de(_recusa(SistemaLocais.MOTIVO_FORA_DO_LOCAL))
	assert_string_contains(texto, "fazenda", "a frase tem que dizer o que houve")

func test_motivo_desconhecido_ainda_diz_alguma_coisa() -> void:
	# O pior toast possível é o que some. Motivo sem frase aparece com o id cru
	# — feio de propósito, para ser corrigido.
	var texto := _aviso.frase_de(_recusa("motivo_que_ninguem_escreveu"))
	assert_string_contains(texto, "motivo_que_ninguem_escreveu")

func test_a_frase_nunca_e_so_nao_deu() -> void:
	for motivo: String in AvisoRecusa.FRASES:
		var texto := String(AvisoRecusa.FRASES[motivo])
		assert_gt(texto.length(), 12, "frase '%s' curta demais para explicar" % motivo)
		assert_false(texto.to_lower().contains("não deu"),
			"'não deu' não existe neste projeto")
