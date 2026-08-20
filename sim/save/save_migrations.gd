class_name SaveMigrations
extends RefCounted

## Trilho de migração do save: mapa `versão de origem → passo`, aplicado em
## cadeia até a versão atual.
##
## Um passo é uma `Callable(Dictionary) -> Dictionary` que sobe **uma** versão.
## Ele não precisa carimbar nada: quem carimba é o trilho. Save v0 com destino
## v3 passa por 0→1, 1→2 e 2→3, nessa ordem.
##
## Recusar é sempre melhor que carregar torto. Falta de passo, passo quebrado ou
## save de uma versão mais nova que o jogo devolvem `null` — o mesmo `null` do
## `SaveManager` para arquivo ausente, então o chamador tem um caso só a tratar:
## sem dicionário, jogo novo.
##
## Hoje a versão atual é 1 e o trilho de produção está vazio: migrar um save v1
## é identidade. O trilho existe agora para que a primeira mudança de formato
## seja registrar um passo, e não reescrever o load.

var _versao_alvo: int
var _passos: Dictionary = {}

## A versão de destino é injetável para o teste provar cadeias longas sem
## precisar que o jogo já tenha chegado nelas.
func _init(versao_alvo: int = SimWorld.SAVE_VERSION) -> void:
	_versao_alvo = versao_alvo

## Versão para a qual este trilho migra.
func target_version() -> int:
	return _versao_alvo

## Versão carimbada no dicionário. Sem carimbo é 0: save anterior ao
## versionamento.
static func version_of(data: Dictionary) -> int:
	return int(data.get(SimWorld.CHAVE_VERSAO, 0))

## Registra o passo que sobe de `de_versao` para `de_versao + 1`. Versão fora do
## trilho é ignorada — passo que nunca rodaria só esconderia bug.
func register_step(de_versao: int, passo: Callable) -> void:
	if de_versao < 0 or de_versao >= _versao_alvo or not passo.is_valid():
		return
	_passos[de_versao] = passo

func has_step(de_versao: int) -> bool:
	return _passos.has(de_versao)

## O save chega até a versão atual? Responde sem executar passo nenhum.
func can_migrate(data: Dictionary) -> bool:
	var versao := version_of(data)
	if versao > _versao_alvo:
		return false
	for v: int in range(versao, _versao_alvo):
		if not _passos.has(v):
			return false
	return true

## Sobe o save até a versão atual e devolve o dicionário migrado, ou `null` se
## ele não chega lá. O dicionário de entrada nunca é alterado — o passo mexe
## numa cópia funda.
func migrate(data: Dictionary) -> Variant:
	var versao := version_of(data)
	if versao > _versao_alvo:
		return null

	var atual: Dictionary = data.duplicate(true)
	while versao < _versao_alvo:
		if not _passos.has(versao):
			return null
		var passo: Callable = _passos[versao]
		var saida: Variant = passo.call(atual)
		if not saida is Dictionary:
			return null
		atual = saida
		versao += 1
		atual[SimWorld.CHAVE_VERSAO] = versao

	# sai sempre carimbado, mesmo o save que já estava na versão certa
	atual[SimWorld.CHAVE_VERSAO] = _versao_alvo
	return atual
