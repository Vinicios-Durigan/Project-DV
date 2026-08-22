extends GutTest

## Conteúdo é id + catálogo: nenhum sistema conhece cultura concreta.
##
## `dias_por_estagio` diz quantos dias regados a planta fica em cada estágio
## antes de sair dele. O último estágio (pronta) não sai sozinho — sai na
## colheita. Logo estágios = tamanho da lista + 1, e o ciclo é a soma.

const DIR_TEMP: String = "user://test_crop_catalog"

func _def(id: String, nome: String = "", dias: Array[int] = [] as Array[int]) -> CropDef:
	var def := CropDef.new()
	def.id = id
	def.nome = nome
	def.dias_por_estagio = dias
	return def

func after_each() -> void:
	if DirAccess.dir_exists_absolute(DIR_TEMP):
		var dir := DirAccess.open(DIR_TEMP)
		for nome in dir.get_files():
			dir.remove(nome)
		DirAccess.remove_absolute(DIR_TEMP)


func test_crop_def_tem_defaults_seguros() -> void:
	var def := CropDef.new()
	assert_eq(def.id, "", "sem id até o artista preencher")
	assert_eq(def.nome, "")
	assert_eq(def.dias_por_estagio, [] as Array[int])
	assert_eq(def.preco_semente, 0)
	assert_eq(def.rende_por_colheita, 1)
	assert_false(def.colheitas_infinitas, "cultura padrão morre na colheita")
	assert_false(def.bloqueia_movimento, "default preserva o comportamento antigo")
	assert_eq(def.sprites_estagios, [] as Array[String])

func test_estagios_derivam_da_lista_de_dias() -> void:
	var def := _def("rabanete", "Rabanete", [1, 1, 2] as Array[int])
	assert_eq(def.total_estagios(), 4, "3 dias de saída = 4 estágios (0,1,2,pronta)")
	assert_eq(def.estagio_pronta(), 3, "a pronta é o último estágio")
	assert_eq(def.dias_ate_pronta(), 4, "o ciclo é a soma da lista")

func test_dias_do_estagio_fora_da_lista_nao_quebra() -> void:
	var def := _def("rabanete", "Rabanete", [1, 1, 2] as Array[int])
	assert_eq(def.dias_do_estagio(0), 1)
	assert_eq(def.dias_do_estagio(2), 2)
	assert_eq(def.dias_do_estagio(3), 0, "o estágio pronta não sai sozinho")
	assert_eq(def.dias_do_estagio(-1), 0, "índice inválido não quebra")

func test_rebrota_volta_ao_estagio_anterior_a_pronta() -> void:
	var def := _def("morango", "Morango", [2, 2, 4] as Array[int])
	assert_eq(def.estagio_rebrota(), 2, "volta um estágio antes da pronta")
	assert_eq(def.dias_do_estagio(def.estagio_rebrota()), 4, "e leva 4 dias para produzir de novo")

func test_cultura_sem_estagios_nasce_pronta() -> void:
	var def := _def("magica")
	assert_eq(def.estagio_pronta(), 0, "lista vazia: já nasce pronta, nunca trava")
	assert_eq(def.estagio_rebrota(), 0)
	assert_eq(def.dias_ate_pronta(), 0)

func test_ids_de_item_caem_na_convencao() -> void:
	var def := _def("rabanete", "Rabanete")
	assert_eq(def.item_semente_id(), "semente_rabanete", "convenção quando o campo está vazio")
	assert_eq(def.item_colheita_id(), "rabanete", "o fruto usa o id da cultura")

func test_ids_de_item_explicitos_ganham_da_convencao() -> void:
	var def := _def("morango", "Morango")
	def.item_semente = "muda_morango"
	def.item_colheita = "fruto_morango"
	assert_eq(def.item_semente_id(), "muda_morango")
	assert_eq(def.item_colheita_id(), "fruto_morango")

func test_catalogo_nasce_vazio() -> void:
	var catalog := CropCatalog.new()
	assert_eq(catalog.size(), 0)
	assert_eq(catalog.ids(), [])

func test_registra_e_encontra_por_id() -> void:
	var catalog := CropCatalog.new()
	catalog.register(_def("rabanete", "Rabanete", [1, 1, 2] as Array[int]))
	assert_true(catalog.has("rabanete"))
	assert_eq(catalog.get_def("rabanete").nome, "Rabanete")

func test_id_desconhecido_nao_existe() -> void:
	var catalog := CropCatalog.new()
	assert_false(catalog.has("dragao"))
	assert_null(catalog.get_def("dragao"), "id desconhecido devolve null, não quebra")

func test_registrar_o_mesmo_id_sobrescreve() -> void:
	var catalog := CropCatalog.new()
	catalog.register(_def("rabanete", "Antigo"))
	catalog.register(_def("rabanete", "Novo"))
	assert_eq(catalog.size(), 1, "id é chave única")
	assert_eq(catalog.get_def("rabanete").nome, "Novo")

func test_def_sem_id_e_ignorada() -> void:
	var catalog := CropCatalog.new()
	catalog.register(_def(""))
	catalog.register(null)
	assert_eq(catalog.size(), 0, ".tres pela metade não entra no catálogo")

func test_ids_saem_em_ordem_deterministica() -> void:
	var catalog := CropCatalog.new()
	catalog.register(_def("morango"))
	catalog.register(_def("abobora"))
	catalog.register(_def("cenoura"))
	assert_eq(catalog.ids(), ["abobora", "cenoura", "morango"], "ordem não depende de inserção")

func test_carrega_tres_do_diretorio() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_TEMP)
	ResourceSaver.save(_def("cenoura", "Cenoura", [2, 2, 2] as Array[int]), DIR_TEMP.path_join("cenoura.tres"))
	ResourceSaver.save(_def("abobora", "Abóbora", [4, 4, 5] as Array[int]), DIR_TEMP.path_join("abobora.tres"))

	var catalog := CropCatalog.new()
	var carregados := catalog.load_from_dir(DIR_TEMP)

	assert_eq(carregados, 2, "carregou os dois .tres")
	assert_eq(catalog.get_def("cenoura").dias_ate_pronta(), 6)
	assert_eq(catalog.get_def("abobora").dias_ate_pronta(), 13)

func test_diretorio_inexistente_nao_quebra() -> void:
	var catalog := CropCatalog.new()
	assert_eq(catalog.load_from_dir("user://nao_existe_mesmo"), 0, "sem conteúdo, catálogo vazio")
	assert_eq(catalog.size(), 0)
