---
name: drive-para-youtube-nutror
description: Baixa vídeos de uma pasta do Google Drive, sobe cada um num canal do YouTube como "Não listado" (título = nome do arquivo) e incorpora (embed) cada vídeo como aula num módulo de um curso na Nutror. Use quando o usuário pedir para "subir as gravações no YouTube e colocar na Nutror", "publicar aulas gravadas", "pegar os vídeos do Drive e incorporar no curso", "subir vídeos não listados e embutir na Nutror/Eduzz", ou fluxo equivalente Drive→YouTube→Nutror. Genérica: recebe pasta do Drive, canal YouTube e curso+módulo Nutror como parâmetros.
---

# Drive → YouTube (Não listado) → Nutror (embed)

Pipeline para publicar gravações: **Drive → YouTube não listado → aula incorporada na Nutror**.
Usa o **Playwright MCP** dirigindo um Chrome **autenticado** (perfil real copiado) + o **Google Drive MCP** para listar a pasta. Toda a UI é frágil — siga [REFERENCE.md](REFERENCE.md) para os seletores e armadilhas exatos.

## Parâmetros (peça ao usuário se faltarem)
- **folderId do Drive** (da URL `drive.google.com/drive/folders/<ID>`)
- **Canal YouTube** alvo (e a conta Google que o acessa)
- **Curso Nutror** (id da URL `my.nutror.com/curso/<id>/...`) + **nome do módulo** (criar se não existir, confirmando antes)
- Conta produtor da Nutror/Eduzz (o usuário loga na hora)
- Defaults YouTube: Não listado · "não é conteúdo para crianças" · sem descrição · sem playlist · título = nome do arquivo sem `.mp4`

## Fluxo
1. **Listar a pasta** via Drive MCP `search_files` com `query: parentId = '<folderId>'`, `pageSize 100`. Guardar por vídeo: `id`, `title`, `fileSize` (bytes — sinal de download completo).
2. **Setup do navegador autenticado** (uma vez): rodar `scripts/prepare-profile.sh <email-da-conta> <dir-destino>`, ajustar a config do Playwright MCP e **pedir ao usuário `/mcp` reconnect + login manual** (Google e Nutror). Detalhes e por quê em [REFERENCE.md](REFERENCE.md#setup-do-chrome-autenticado).
3. **Piloto**: processar 1 vídeo ponta a ponta (download → upload → confirmar Não listado) e validar antes do lote.
4. **Loop YouTube** (1 vídeo por vez, deletando o `.mp4` após subir): baixar do Drive → subir no Studio → título/kids/visibilidade → **registrar o link `youtu.be/<id>`**. Ver [REFERENCE.md](REFERENCE.md#youtube).
5. **Verificar** no painel `studio.youtube.com/.../videos/upload` que todos estão "Não listado" com título certo.
6. **Loop Nutror**: criar 1 aula por vídeo no módulo (campo "Nome da aula" + Enter), abrir cada aula e **incorporar** o link (Validar→Inserir→Salvar via JS). Ver [REFERENCE.md](REFERENCE.md#nutror).
7. **Verificar** em `/curso/<id>/conteudo` que o módulo tem todas as aulas e nenhuma "sem conteúdo". **Limpar** os `.mp4` baixados.

## Regras
- Sempre **um vídeo por vez** (pico de disco ~2 GB); registrar `título → folderId → link YouTube → aula Nutror` num `links.md` para permitir retomada.
- Conferir o **tamanho em bytes** == `fileSize` da API antes de considerar o download completo (o nome do arquivo é sanitizado: espaços/pontos → `-`).
- **Idempotência**: antes de subir, checar no canal se já existe vídeo com o mesmo título (evitar duplicar em retomadas).
- Nunca hard-codar credenciais; login é sempre manual no navegador da automação.
