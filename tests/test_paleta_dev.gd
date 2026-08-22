extends GutTest

## O guarda da decisão central da wave 11: **nenhum nó de `game/dev/` pinta cor
## na mão**.
##
## Cor solta é o tipo de coisa que ninguém revisa e que, um ano depois, faz
## "trocar o tema" virar caçada em quinze arquivos. O teste varre o diretório e
## reprova qualquer construtor de `Color` ou hex de seis dígitos fora da
## `paleta.gd` — inclusive em arquivo que ainda nem existe, porque a varredura é
## do diretório, não de uma lista.
##
## É teste de `game/`, e é de propósito: a regra é de apresentação, então não
## teria como morar em `sim/`.

const DIRETORIO: String = "res://game/dev"
## O único arquivo autorizado a declarar cor — é para isso que ele existe.
const DONO_DAS_CORES: String = "paleta.gd"

## `Color(...)`, `Color8(...)` e `Color.NOME` — as três formas de inventar cor.
const PADRAO_COR: String = "Color8?\\s*\\(|Color\\.[A-Z_]{2,}"
## Hex de seis dígitos dentro de aspas: o disfarce de cor em BBCode.
const PADRAO_HEX: String = "\"#?[0-9A-Fa-f]{6}\""


func _arquivos_gd() -> PackedStringArray:
	var achados := PackedStringArray()
	for nome in DirAccess.get_files_at(DIRETORIO):
		if nome.ends_with(".gd") and nome != DONO_DAS_CORES:
			achados.append(nome)
	return achados

func _linhas_com(nome: String, padrao: String) -> Array[String]:
	var regex := RegEx.new()
	regex.compile(padrao)
	var texto := FileAccess.get_file_as_string("%s/%s" % [DIRETORIO, nome])
	var achadas: Array[String] = []
	var numero := 0
	for linha in texto.split("\n"):
		numero += 1
		# Comentário e documentação podem citar hex à vontade — o que não pode é
		# o código usar.
		if linha.strip_edges().begins_with("#"):
			continue
		if regex.search(linha) != null:
			achadas.append("%s:%d %s" % [nome, numero, linha.strip_edges()])
	return achadas


func test_diretorio_tem_arquivos_para_varrer() -> void:
	assert_gt(_arquivos_gd().size(), 0, "varredura vazia esconderia qualquer violação")

func test_nenhum_no_constroi_Color_fora_da_paleta() -> void:
	var violacoes: Array[String] = []
	for nome in _arquivos_gd():
		violacoes.append_array(_linhas_com(nome, PADRAO_COR))
	assert_eq(violacoes, [] as Array[String],
		"cor construída fora da paleta.gd — mova a constante para lá")

func test_nenhum_no_escreve_hex_fora_da_paleta() -> void:
	var violacoes: Array[String] = []
	for nome in _arquivos_gd():
		violacoes.append_array(_linhas_com(nome, PADRAO_HEX))
	assert_eq(violacoes, [] as Array[String],
		"hex em texto fora da paleta.gd — use Paleta.hex(Paleta.ALGUMA)")

func test_paleta_da_um_dono_diferente_para_cada_semantica() -> void:
	# Duas semânticas com a mesma cor apagariam a regra do dono único.
	var donos := [Paleta.VERDE, Paleta.TERRA, Paleta.OURO, Paleta.CEU, Paleta.ALERTA]
	for i in donos.size():
		for j in range(i + 1, donos.size()):
			assert_ne(donos[i], donos[j], "duas semânticas com a mesma cor")

func test_o_solo_seco_e_o_molhado_se_distinguem() -> void:
	# O canal da rega é leitura de relance: claro seco, escuro molhado.
	assert_gt(Paleta.SOLO_SECO.get_luminance(), Paleta.SOLO_MOLHADO.get_luminance(),
		"o canal da rega inverteu — seco tem que ser o claro")

func test_a_pronta_e_mais_clara_que_a_planta() -> void:
	assert_gt(Paleta.PRONTA.get_luminance(), Paleta.PLANTA.get_luminance(),
		"a pronta é maior, mais clara e pulsa — a cor é o terceiro sinal")
