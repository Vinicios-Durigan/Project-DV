#!/usr/bin/env bash
# PreToolUse (Edit|Write): bloqueia qualquer escrita em assets/.

INPUT=$(cat)

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
  */assets/*)
    echo "assets/ é território do artista, não edite por aqui" >&2
    exit 2
    ;;
  assets/*)
    echo "assets/ é território do artista, não edite por aqui" >&2
    exit 2
    ;;
esac

exit 0
