# Fontes da interface

As duas famílias do design system "Fazenda de Botões" v1. **Não são arte do
artista** — são fontes livres baixadas do Google Fonts, e por isso vivem aqui
apesar de `assets/` ser território do artista.

| Família | Papel | Arquivos |
| --- | --- | --- |
| Familjen Grotesk | rótulo, botão, corpo | `FamiljenGrotesk-{Regular,SemiBold,Bold}.ttf` |
| JetBrains Mono | **todo número** — relógio, dinheiro, cota, coordenada | `JetBrainsMono-{Regular,Medium,Bold}.ttf` |

Número em mono não dança quando muda: é por isso que a segunda família existe.

Licença: SIL Open Font License 1.1, texto integral em `OFL-*.txt`. Uso e
redistribuição liberados, inclusive comercial; o que a licença pede é que o
texto viaje junto — e é o que estes dois arquivos fazem.

Quem carrega é `game/dev/tema_playground.gd`. Se um arquivo sumir, o tema cai
na fonte padrão do Godot sem quebrar nada — a checagem é por
`ResourceLoader.exists`.
