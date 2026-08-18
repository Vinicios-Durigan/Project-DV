extends GutTest

## Conteúdo é id + catálogo: o sistema nunca conhece o item concreto.

const DIR_TEMP: String = "user://test_item_catalog"

func _def(id: String, nome: String = "", preco: int = 0, stack: int = 999) -> ItemDef:
	var def := ItemDef.new()
	def.id = id
	def.nome = nome
	def.preco_venda = preco
	def.stack_max = stack
	return def

func after_each() -> void:
	if DirAccess.dir_exists_absolute(DIR_TEMP):
		var dir := DirAccess.open(DIR_TEMP)
		for nome in dir.get_files():
			dir.remove(nome)
		DirAccess.remove_absolute(DIR_TEMP)


func test_item_def_tem_defaults_seguros() -> void:
	var def := ItemDef.new()
	assert_eq(def.id, "", "sem id até o artista preencher")
	assert_eq(def.nome, "")
	assert_eq(def.preco_venda, 0, "item sem preço não vale nada — nunca quebra")
	assert_eq(def.stack_max, 999, "stack máximo padrão")

func test_catalogo_nasce_vazio() -> void:
	var catalog := ItemCatalog.new()
	assert_eq(catalog.size(), 0)
	assert_eq(catalog.ids(), [])

func test_registra_e_encontra_por_id() -> void:
	var catalog := ItemCatalog.new()
	catalog.register(_def("rabanete", "Rabanete", 35, 999))
	assert_true(catalog.has("rabanete"))
	assert_eq(catalog.get_def("rabanete").nome, "Rabanete")
	assert_eq(catalog.get_def("rabanete").preco_venda, 35)

func test_id_desconhecido_nao_existe() -> void:
	var catalog := ItemCatalog.new()
	assert_false(catalog.has("dragao"))
	assert_null(catalog.get_def("dragao"), "id desconhecido devolve null, não quebra")

func test_registrar_o_mesmo_id_sobrescreve() -> void:
	var catalog := ItemCatalog.new()
	catalog.register(_def("rabanete", "Antigo", 10))
	catalog.register(_def("rabanete", "Novo", 35))
	assert_eq(catalog.size(), 1, "id é chave única")
	assert_eq(catalog.get_def("rabanete").nome, "Novo", "o último registro vale")

func test_def_sem_id_e_ignorada() -> void:
	var catalog := ItemCatalog.new()
	catalog.register(_def(""))
	catalog.register(null)
	assert_eq(catalog.size(), 0, ".tres pela metade não entra no catálogo")

func test_ids_saem_em_ordem_deterministica() -> void:
	var catalog := ItemCatalog.new()
	catalog.register(_def("cenoura"))
	catalog.register(_def("abobora"))
	catalog.register(_def("rabanete"))
	assert_eq(catalog.ids(), ["abobora", "cenoura", "rabanete"], "ordem não depende de inserção")

func test_stack_max_vem_do_catalogo() -> void:
	var catalog := ItemCatalog.new()
	catalog.register(_def("enxada", "Enxada", 0, 1))
	assert_eq(catalog.stack_max_of("enxada"), 1, "ferramenta é item de stack 1")

func test_stack_max_de_id_desconhecido_cai_no_padrao() -> void:
	assert_eq(ItemCatalog.new().stack_max_of("dragao"), 999, "sem definição, vale o padrão")

func test_carrega_tres_do_diretorio() -> void:
	DirAccess.make_dir_recursive_absolute(DIR_TEMP)
	ResourceSaver.save(_def("cenoura", "Cenoura", 65), DIR_TEMP.path_join("cenoura.tres"))
	ResourceSaver.save(_def("abobora", "Abóbora", 180, 50), DIR_TEMP.path_join("abobora.tres"))

	var catalog := ItemCatalog.new()
	var carregados := catalog.load_from_dir(DIR_TEMP)

	assert_eq(carregados, 2, "carregou os dois .tres")
	assert_eq(catalog.get_def("cenoura").preco_venda, 65)
	assert_eq(catalog.stack_max_of("abobora"), 50)

func test_diretorio_inexistente_nao_quebra() -> void:
	var catalog := ItemCatalog.new()
	assert_eq(catalog.load_from_dir("user://nao_existe_mesmo"), 0, "sem conteúdo, catálogo vazio")
	assert_eq(catalog.size(), 0)
