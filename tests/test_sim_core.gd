extends GutTest

## Bases de ação e evento: dados puros, nada de comportamento.

func test_acao_nasce_com_player_zero() -> void:
	var action := SimAction.new()
	assert_eq(action.player_id, 0, "player_id default é 0 (sem singleton do jogador)")

func test_acao_aceita_outro_player() -> void:
	var action := SimAction.new()
	action.player_id = 2
	assert_eq(action.player_id, 2, "player_id é o gancho de co-op futuro")

func test_evento_pode_ser_criado() -> void:
	var event := SimEvent.new()
	assert_not_null(event, "SimEvent é instanciável")

func test_acao_e_evento_sao_hierarquias_separadas() -> void:
	var action: Variant = SimAction.new()
	var event: Variant = SimEvent.new()
	assert_false(action is SimEvent, "ação não é evento")
	assert_false(event is SimAction, "evento não é ação")
