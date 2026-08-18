#!/usr/bin/env bash
# PostToolUse (Edit|Write): roda a suite GUT headless quando sim/ ou tests/ muda.
# Nunca derruba a sessao: sem Godot ou sem GUT, apenas avisa.

INPUT=$(cat)

json_escape() {
  printf '%s' "$1" \
    | tr -d '\000-\010\013\014\016-\037' \
    | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
    | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g'
}

# exit 0 + additionalContext = mensagem para o Claude sem marcar erro na sessao
notify() {
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$(json_escape "$1")"
  exit 0
}

FILE=$(printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -z "$FILE" ] && exit 0

# barras invertidas (inclusive as escapadas do JSON) viram barra normal
# e "C:/x" vira "/c/x", para casar caminho Windows com caminho do Git Bash
norm() { printf '%s' "$1" | sed -e 's|\\\+|/|g' | tr 'A-Z' 'a-z' | sed -e 's|^\([a-z]\):/|/\1/|'; }

ROOT="${CLAUDE_PROJECT_DIR:-$PWD}"
FILE_N=$(norm "$FILE")
ROOT_N=$(norm "$ROOT")
REL="${FILE_N#"$ROOT_N"/}"

# se o prefixo do projeto nao bateu, cai para o caminho completo
[ "$REL" = "$FILE_N" ] && REL="${FILE_N#/}"

case "$REL" in
  sim/*|tests/*|*/sim/*|*/tests/*) ;;
  *) exit 0 ;;
esac

cd "$ROOT" || exit 0

# Localiza o binario do Godot
GODOT=""
for c in "$GODOT_BIN" godot godot.exe Godot Godot.exe godot4 godot4.exe; do
  [ -z "$c" ] && continue
  if command -v "$c" >/dev/null 2>&1; then GODOT=$(command -v "$c"); break; fi
done
[ -z "$GODOT" ] && notify "GUT nao executado: binario do Godot nao encontrado no PATH. Adicione o Godot ao PATH ou defina GODOT_BIN. Arquivo alterado: $REL"

GUT_ENTRY="addons/gut/gut_cmdln.gd"
[ -f "$GUT_ENTRY" ] || notify "GUT nao executado: $GUT_ENTRY nao existe. Instale o GUT em addons/gut/. Arquivo alterado: $REL"

OUT=$("$GODOT" --headless -s "$GUT_ENTRY" -gdir=res://tests -ginclude_subdirs -gexit 2>&1)
CODE=$?
TAIL=$(printf '%s' "$OUT" | tail -n 60)

if [ "$CODE" -ne 0 ]; then
  # exit 2 no PostToolUse: stderr chega ao Claude (a ferramenta ja rodou, nada e revertido)
  printf 'Suite GUT falhou (exit %s) apos alterar %s:\n\n%s\n' "$CODE" "$REL" "$TAIL" >&2
  exit 2
fi

notify "Suite GUT passou apos alterar $REL.
$TAIL"
