#!/bin/bash
# Prepara um user-data-dir dedicado a partir do perfil logado de uma conta Google no Chrome,
# para o Playwright MCP lançar o Chrome autenticado (Chrome v136+ bloqueia debug no dir padrão).
#
# Uso:  prepare-profile.sh <email-da-conta> <destDir>
#   ex: prepare-profile.sh conta-do-canal@gmail.com ~/.exos-cdp-chrome
#
# Depois deste script:
#  1) Editar ~/.claude.json no server "playwright":
#       "args": ["@playwright/mcp@latest","--browser","chrome","--user-data-dir","<destDir>","--output-dir","<pastaDownloads>"]
#  2) Pedir ao usuário: /mcp -> playwright -> Reconnect (ou reiniciar o Claude)
#  3) browser_navigate p/ studio.youtube.com; se pedir login, usuário loga 1x (persiste no destDir)
set -e
EMAIL="$1"; DEST="${2/#\~/$HOME}"
[ -z "$EMAIL" ] || [ -z "$DEST" ] && { echo "uso: prepare-profile.sh <email> <destDir>"; exit 1; }
SRC="$HOME/Library/Application Support/Google/Chrome"
[ -d "$SRC" ] || { echo "Chrome não encontrado em $SRC"; exit 1; }

echo "Procurando perfil da conta $EMAIL ..."
PROFILE_DIR=$(python3 - "$SRC" "$EMAIL" <<'PY'
import json,sys,os
src,email=sys.argv[1],sys.argv[2]
d=json.load(open(os.path.join(src,"Local State")))
for k,v in d.get("profile",{}).get("info_cache",{}).items():
    if v.get("user_name","").lower()==email.lower(): print(k); break
PY
)
[ -z "$PROFILE_DIR" ] && { echo "Nenhum perfil logado com $EMAIL. Logue essa conta no Chrome primeiro."; exit 1; }
echo "Perfil encontrado: '$PROFILE_DIR'"

echo "Fechando o Chrome (necessário para copiar com consistência)..."
osascript -e 'quit app "Google Chrome"' 2>/dev/null || true
for i in $(seq 1 15); do pgrep -x "Google Chrome" >/dev/null 2>&1 || break; sleep 1; done
pgrep -x "Google Chrome" >/dev/null 2>&1 && { pkill -9 -x "Google Chrome"; sleep 2; }

echo "Preparando $DEST ..."
rm -rf "$DEST"; mkdir -p "$DEST"
cp "$SRC/Local State" "$DEST/Local State"
cp -R "$SRC/$PROFILE_DIR" "$DEST/Default"
# remove caches grandes/descartáveis
rm -rf "$DEST/Default/Service Worker" "$DEST/Default/GPUCache" "$DEST/Default/DawnWebGPUCache" \
       "$DEST/Default/DawnGraphiteCache" "$DEST/Default/Code Cache" 2>/dev/null || true
# remove locks de singleton (senão o launchPersistentContext falha)
rm -f "$DEST/SingletonLock" "$DEST/SingletonCookie" "$DEST/SingletonSocket" 2>/dev/null || true

echo "OK. user-data-dir pronto em: $DEST"
echo "Tamanho: $(du -sh "$DEST" | cut -f1)"
echo
echo "Próximo: ajustar ~/.claude.json (args do playwright p/ --browser chrome --user-data-dir $DEST) e /mcp reconnect."
