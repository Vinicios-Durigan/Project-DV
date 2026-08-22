# GAMEPLAY — Vertical Slice

Decisões fechadas em 2026-08-17. Este documento é a fonte de verdade do design do
slice. Waves de implementação derivam daqui.

**Visão em uma frase:** um farming sim de loop diário — arar, plantar, regar,
dormir, colher, vender — construído como *loop padrão extensível*: cada mecânica
futura (pesca, stamina, clima, co-op) nasce como módulo novo sem tocar no que
existe. Parecido com o gênero, não um clone: o diferencial é sensorial (a rotina
tem ritmo e a manhã é espetáculo) e, a médio prazo, espacial.

---

## 1. Movimento e controle

| Decisão | Valor | Motivo | Sacrifica |
|---|---|---|---|
| Movimento | Livre em pixel; **interação** em grid | Grid-locked parece datado e briga com analógico; quem precisa de grid é a ferramenta | Precisão absoluta — mitigada pelo retículo |
| Velocidade | 4.5 tiles/s (72 px/s) | Atravessar a área útil em ≤10s; andar não pode virar custo | Sensação de fazenda vasta |
| Mapa do slice | 40×30 tiles, cultivável ~20×15 | É o que a velocidade sustenta sem montaria/teleporte | — |
| Seleção de tile | **Facing-based**: tile à frente do personagem, retículo desenhado no chão | Funciona igual em teclado, gamepad e co-op futuro | Agilidade do mouse-hover (pode virar override depois) |
| Retículo | Sempre visível com ferramenta na mão; muda de cor se ação inválida | Zero ambiguidade sobre o alvo | — |
| Lock de ação | Sim, ~0.3s por swing, **com input buffer** (apertar durante o lock enfileira) | Peso, sincronia animação↔efeito, evita "arar andando" | Agilidade |
| Segurar botão | Auto-repeat respeitando o cooldown do swing | Regar 40 tiles em clique unitário é RSI | Deliberação por tile (irrelevante) |
| Input primário | Teclado, gamepad-ready; mouse fora do slice | Decisão de plataforma tomada | Conforto de mouse no PC |

## 2. Câmera e apresentação

- **Resolução base 640×360**, tiles **16×16**, personagem **16×32**. Escala inteira: ×3 = 1080p, ×6 = 4K, filtro nearest.
- Follow com lerp exponencial (speed ~8), **sem deadzone** (deadzone é coisa de platformer), clamp nos limites do mapa.
- Pixel snapping: viewport interno na base + stretch `viewport` + `snap_2d_transforms_to_pixel`. Física e câmera em float, só o render snapa.
- Se o feel ficar "distante": zoom 2× da câmera (inteiro, seguro) — decisão adiável, sem retrabalho de arte.
- **Proibido para sempre:** zoom não-inteiro.

## 3. Tempo

- **1 min de jogo = 0.75s real.** Tick da sim = 1 min de jogo. Relógio de HUD anda em passos de 10 min.
- Dia útil 06:00→02:00 = **15 min reais**. Estação de 28 dias ≈ 7h de gameplay.
- Às 02:00 acordado: **colapso** — mesma sequência de dormir, com `cause = COLLAPSED` no evento. Sem penalidade no slice; a causa viaja no evento para fadiga/morte/hospital futuros.
- **Crescimento na virada do dia**, nunca contínuo. Determinismo, save trivial, "dormir = progresso" é a recompensa do loop.

**Sequência de dormir (ordem é regra de jogo):**
1. Caixote vende → linhas do resumo + dinheiro
2. Culturas regadas avançam estágio; flag de rega reseta
3. Calendário avança (dia 28 → resumo de estação, volta ao dia 1, culturas no chão morrem)
4. Autosave
5. Fade in 06:00 com resumo na tela

A ordem de registro dos sistemas no tick central implementa essa sequência
(venda antes de crescimento antes de calendário). Mudar a ordem muda regra de jogo.

## 4. Regras do mundo

- Cultura **não regada pausa** o crescimento (não morre). Morte pune demais sem mitigação (sprinkler futuro).
- Culturas **não bloqueiam** movimento por padrão; `CropDef.bloqueia_movimento: bool` (default `false`) liga por cultura. As 4 iniciais: `false`.
- **Hotbar 8 slots**, teclas 1–8 + scroll. Ferramentas e sementes ocupam slots.
  A hotbar é a fatia de cima da mochila, não uma segunda bolsa. O slot na mão
  (`slot_na_mao`) está no save.
- **Uma ação só: usar.** O que ela faz depende do item na mão — enxada ara,
  regador rega, semente planta aquela cultura. **Cultura pronta tem
  prioridade**: usar num tile maduro colhe, seja o que for que esteja na mão
  (§6, "colher: sem swing"). Quem decide é `sim/items/resolvedor_uso.gd`.
- **Caixote:** interagir abre painel; clique deposita 1, shift-clique o stack; venda só concretiza ao dormir (dá pra tirar de volta). O mesmo painel tem **aba de compra de sementes** — sem compra, dinheiro é número morto e o loop não fecha. (Alternativa descartada: loja/NPC — mais arte e escopo que o slice comporta.)
- **Dormir na porta da casa** — slice sem interior de casa. Corta um mapa inteiro de arte.
- Sem stamina no slice. O limitador do dia é o relógio. Entra depois como sistema novo + migração de save.

## 5. Economia e fórmulas

Fórmula-mestre: `lucro_por_dia_por_tile = (venda − semente) / dias_de_ciclo`.
Regra de balanceamento: lucro/dia da lenta ≈ 2× o da rápida.

| Papel | Cultura (nome livre p/ arte) | Ciclo | Semente | Venda | Lucro/dia |
|---|---|---|---|---|---|
| Rápida | ex. rabanete | 4d | 20g | 35g | 3.75 |
| Média | ex. cenoura | 6d | 30g | 65g | 5.8 |
| Lenta | ex. abóbora | 13d | 80g | 180g | 7.7 |
| Rebrota | ex. morango | 8d + 4d/colheita | 60g | 45g/fruto | cresce quanto antes planta |

- Estágios de crescimento: `dias_por_estagio: Array[int]` no CropDef (ex. rápida `[1,1,1,1]`). Avança 1 dia de estágio por noite **se regada**.
- Rebrota: campo `colheitas_infinitas: bool` — ao colher volta ao estágio anterior ao "pronta". É a cultura que mais testa o sistema.
- Início de jogo: **500g + 5 sementes da rápida**.
- Números acima são chute calibrado pela fórmula — ajuste fino é `.tres`, não código.

## 6. Feedback (juice mínimo obrigatório)

| Ação | Vê | Ouve |
|---|---|---|
| Arar | Swing de enxada, tile vira terra revirada, poeira | Thunk terroso |
| Plantar | Agachada curta, semente aparece | Pop suave |
| Regar | Arco de gotas, tile escurece (variante molhada) | Água curto |
| Colher | Sem swing; cultura voa em arco até o jogador, stack pisca na hotbar | Pluck + chime |

- Resposta percebida em ≤2 frames: o evento chega no mesmo tick do dispatch.
- **Cultura pronta = 3 sinais redundantes:** sprite final distinto e maior + balanço de 2 frames + glint periódico. Legível da distância da câmera, sem tooltip, cobrindo daltonismo.
- **Canais separados:** a *terra* comunica rega (clara/escura), a *planta* comunica estágio. Nunca misturar.
- **Resumo ao dormir:** linha por item (qtd × preço = subtotal), total do dia, dinheiro atual, "Dia X/28 — Primavera".

## 7. Ideias do loop, por horizonte

**No slice (puro game/, é onde nasce o "gostoso na mão"):**
1. **Manhã-espetáculo** — ao sair de casa, as plantas que cresceram pulam de estágio em cascata, com som. O momento-chave do loop vira recompensa visual. A sim já emite os eventos na ordem; é só animação.
2. **Ritmo de rega** — regar tiles em sequência sem errar sobe o pitch da nota. A rotina mais repetitiva vira música. Custo quase zero.

**Próximo do loop (sistemas pequenos de sim/, pós-slice):**
3. **Pedido do dia** — o caixote acorda com encomenda ("hoje cenoura paga 2×"). Variação diária sem clima.
4. **Qualidade por cuidado** — regou todos os dias sem falhar = qualidade ouro, preço maior. Determinístico; contador `dias_perfeitos` no CropState.

**Assinatura do jogo (visão, médio prazo):**
5. **Agricultura espacial** — adjacência importa: bloco 3×3 da mesma cultura pode virar gigante; vizinhos certos geram híbrido raro. A decisão deixa de ser "o quê" e vira "onde". É aqui que o jogo ganha identidade.

**Descartado com motivo:** janela de colheita que apodrece (pune casual, briga com o tom do gênero); qualidade por RNG (sorte no lugar de cuidado quebra a sim determinística).

## 8. Arquitetura (resumo — a lei está em sim/CLAUDE.md e game/CLAUDE.md)

- Fluxo único: **input → ação → sim → evento → visual**. `game/` nunca lê estado da sim; o dado que faltar devia ter vindo no evento.
- Sistemas do slice, na ordem fixa do tick: **ShippingSystem → FarmSystem → TimeSystem** (+ InventorySystem via ações; DevSystem só em debug). A ordem implementa a sequência de dormir.
- `TimeSystem` emite `MinuteTickedEvent`, `DayEndedEvent(cause)`. Movimento e câmera são 100% `game/`; a posição do jogador **não entra na sim** — a sim conhece só o tile alvo dentro da ação.
- Regras de nascimento de módulo (gravadas nos CLAUDE.md): mecânica nova = arquivo novo; evento gordo, sistema magro; conteúdo é id + catálogo; `.tres` com default; save versionado; `player_id` em toda ação.
- **Prova de fogo do design — pescaria:** FishingSystem + CastLineAction + FishCaughtEvent + FishDef.tres + peixe no inventário genérico. Arquivos existentes tocados: 1 (registro no tick). Se exigir mais que isso, o design falhou.

## 9. Co-op futuro (não implementar; não sabotar)

- Ação→evento já é multiplayer-friendly: co-op = duas fontes de ações no mesmo SimWorld. Host autoritativo processa; clientes recebem eventos replicados; o visual já só reage a evento.
- Custo pago hoje (quase zero): `player_id` em toda ação (hoje `0`); nenhum singleton "o jogador"; inventário como state por `player_id`.
- Movimento é `game/` → replicação de transform padrão do Godot, fora da sim.

## 10. Dados — dois planos, nunca misturar

**Definições (estático, editor-friendly):** Resources `.tres` em `data/`.
- `CropDef`: id, nome, dias_por_estagio, preco_semente, colheitas_infinitas, bloqueia_movimento, sprites. O preço de **venda** não mora aqui: quem sabe quanto um item vale é o `ItemDef` dele — o caixote vende itens, não culturas.
- `ItemDef`: id, nome, preco_venda, stack_max. Fonte única de preço de venda.
- ~~`ToolDef`~~ — **morreu na wave 11.2**. Ferramenta já precisa ser `ItemDef`
  para ocupar um slot da mochila (§4), e um resource paralelo duplicaria id,
  nome e ícone só para acrescentar um campo. O que a distingue agora é
  `ItemDef.acao_de_uso` (`"arar"`, `"regar"`, vazio = item comum). Ferramenta
  nova = um `.tres` + um caso em `sim/items/resolvedor_uso.gd`.
- Designer ajusta balanceamento sem tocar código. Sem SQLite — overkill absoluto para single-player farming.

**Estado (dinâmico, save):** SimStates → JSON versionado em `user://saves/slot_N.json`.

```json
{
  "save_version": 1,
  "time":  { "dia": 3, "minuto": 360, "estacao": "primavera" },
  "farm":  { "plots": { "12:07": { "crop_id": "rabanete", "estagio": 2, "regada": true } } },
  "inventory": { "0": { "slots": [ { "item_id": "enxada", "qtd": 1 }, { "item_id": "", "qtd": 0 }, … ], "capacity": 24, "dinheiro": 500, "slot_na_mao": 0 } },
  "shipping": { "itens": [] }
}
```

- Todo campo com default; campo novo entra sem migração; remover/renomear exige migração incremental por versão.
- Autosave ao dormir; save manual não entra no slice.

## 11. Dev tools (F1, `game/dev/`, só em build debug)

A arquitetura paga a ferramenta: o console é só mais um cliente da bridge.

- **Log de eventos ao vivo** — todo SimEvent com hora de jogo, filtro por tipo, pausa/scroll.
- **Controle do tempo** — velocidade ×1/×10/×60; pular hora; pular dia (roda a sequência de dormir de verdade); pular pro dia 28.
- **Cheats como ações formais** — +1000g, dar sementes, regar tudo, colher tudo — via `DevSystem` registrado só em debug. O visual reage normal; zero gambiarra.
- **Inspetor de tile** — mira num tile, vê o CropState cru.
- **Overlay de grid** — tiles, tile alvo, colisão.
- **Log em arquivo** — `user://logs/` por sessão, eventos serializados.
- **Gravação de ações** — sequência de ações da sessão em arquivo. Replay player fica pra depois; gravar desde já é barato e vira bug report determinístico perfeito.

## 12. Lista de arte (para o artista)

Formato geral: pixel art, tile 16×16, personagem 16×32, paleta livre (definir com o artista). Sprites em spritesheet PNG, fundo transparente.

**Tileset de chão (16×16):**
- Grama (base + 2-3 variações de detalhe)
- Terra arada seca / terra arada **molhada** (variante escura — comunica rega)
- Transições grama↔terra (autotile mínimo)
- Obstáculos: pedra, toco/árvore (bloqueiam)

**Culturas (16×16 por estágio, ancorado no chão do tile):**
- 4 culturas × 4 estágios (semente, broto, crescendo, **pronta** — a "pronta" maior/distinta, preparada para balanço de 2 frames) = 16
- Rebrota: estágio extra "colhida, sem fruto" = +1
- Murcha genérica (fim de estação) = +1
- **Total: 18 sprites de cultura**

**Personagem (16×32, 4 direções):**
- Idle (1 frame/dir) + andar (4 frames/dir) = 20
- Ações ~3 frames/dir: enxada, regador, plantar (agachada), colher (abaixar) = 48
- Ferramenta desenhada junto no frame (sem overlay separado)
- **Total: ~68 frames**

**Objetos:** caixote de venda (fechado + aberto), fachada da casa com porta (dormir é na porta — **sem interior**), cama não necessária no slice.

**UI:** hotbar 8 slots + seleção; ícones 16×16 (4 colheitas, 4 pacotes de semente, 3 ferramentas); retículo de tile (válido/inválido — 2 cores); relógio + calendário HUD; painel do caixote (vender/comprar); painel resumo do dia; fonte pixel (pode ser fonte pronta livre).

**Partículas (2-3 frames cada):** poeira, gotas de água, glint/brilho.

**Áudio (não é arte, registrado para não perder):** thunk, pop, água, pluck+chime, escala de notas da rega (ritmo), som de dormir/manhã, música ambiente dia.

## 13. Em aberto

- Nomes e visual final das 4 culturas (artista decide junto).
- Valores finais de economia (chute calibrado; ajustar em `.tres` jogando).
- Zoom 2× da câmera — decidir com arte real na tela.
- Mouse como override de seleção — só se o playtest pedir.
- Replay player do dev tools — gravação entra no slice, player depois.
