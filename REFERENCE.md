# REFERENCE — Drive → YouTube → Nutror

Playbook detalhado com seletores e armadilhas testadas. Tudo via Playwright MCP (`mcp__playwright__browser_*`) + Google Drive MCP.

## Setup do Chrome autenticado

O Chrome v136+ **bloqueia `--remote-debugging-port` no user-data-dir padrão**, e anexar via `--cdp-endpoint` a um Chrome externo falha com `Browser.setDownloadBehavior ... not supported`. Solução que funciona: **o próprio Playwright MCP lança o Chrome** apontando para uma **cópia** do perfil logado.

Passos:
1. Rodar `scripts/prepare-profile.sh <email> <destDir>` — ele acha o perfil daquela conta no Chrome, fecha o Chrome e copia `Local State` + o perfil (como `Default`) para `<destDir>` (ex.: `~/.exos-cdp-chrome`).
2. Editar `~/.claude.json` no server `playwright`, `args`:
   ```json
   ["@playwright/mcp@latest","--browser","chrome","--user-data-dir","<destDir>","--output-dir","<pastaDownloads>"]
   ```
3. **Pedir ao usuário**: `/mcp` → playwright → Reconnect (ou reiniciar o Claude).
4. `browser_navigate` para `https://studio.youtube.com` e snapshot. **A sessão do Google geralmente NÃO migra com a cópia** → pedir ao usuário login manual uma vez (persiste no destDir). Idem Nutror/Eduzz (tem reCAPTCHA).
5. Reverter depois: `args` de volta para `["@playwright/mcp@latest"]` + reconnect.

Downloads do MCP caem em `--output-dir` com nome sanitizado (espaços/`.`/`–` → `-`).

## YouTube

### Download do Drive (por vídeo)
- `browser_navigate` → `https://drive.google.com/file/d/<ID>/view`
- click `[aria-label="Baixar"]` → abre **aba 1** (interstício "não foi possível verificar vírus" p/ arquivos >100MB)
- `browser_tabs select index 1` → click `#download-form button, #uc-download-link, form button[type=submit], input[type=submit]`
- Esperar via Bash até `stat -f%z <arquivo> == fileSize` (bytes exatos). Depois `browser_tabs close index 1`.

### Upload no Studio
- `browser_navigate` → `https://studio.youtube.com`; click `role=button[name="Enviar vídeos"]`; click `role=button[name="Selecionar arquivos"]` (abre file chooser) → `browser_file_upload [caminho]`.
- Título (contenteditable): `browser_type` target `#title-textarea #textbox` com o nome do arquivo sem `.mp4` (o `.fill` substitui o auto-preenchido). Verificar via `browser_evaluate` lendo `document.querySelector('#title-textarea #textbox').textContent`.
- Público "não infantil": click `tp-yt-paper-radio-button[name="VIDEO_MADE_FOR_KIDS_NOT_MFK"]`.
- **Link**: ler `document.querySelector('a[href^="https://youtu.be/"]').href` (já disponível durante o upload).
- Avançar: click `#next-button` **3×** (Detalhes→Elementos→Verificações→Visibilidade).
- Visibilidade: click `tp-yt-paper-radio-button[name="UNLISTED"]`; salvar: click `#done-button`.
- **Arquivo grande ainda processando**: aparece um diálogo "Processando vídeo / precisa terminar o processamento antes de ficar não listado". Isso é informativo — o Não listado **já foi salvo** (fica pendente até o processamento). Fechar:
  ```js
  const dlg=[...document.querySelectorAll('ytcp-dialog#dialog')].find(d=>getComputedStyle(d).display!=='none'&&/Processando vídeo|publicado/.test(d.textContent||''));
  if(dlg){const c=dlg.querySelector('ytcp-button#close-button, #close-button'); (c.querySelector('button')||c).click();}
  ```
  Se o upload ainda não terminou, `#done-button` fica `disabled` — esperar o upload (ler `.progress-label`) e então clicar.
- Deletar o `.mp4` local e seguir.

### Verificação
`browser_navigate` → `https://studio.youtube.com/channel/<CID>/videos/upload`; ler linhas `ytcp-video-row`: `#video-title` e `.tablecell-visibility` (esperar "Não listado").

## Nutror

### Achar/abrir o curso (produtor)
- Logado, ir a `my.nutror.com/cursos`. O id do curso aparece em ids tipo `course-card-<id>-image-click`. Abrir o card → aba **Conteúdo** (`/curso/<id>/conteudo`).
- O **módulo** já pode existir (ex.: "Gravações"). Expandir clicando no cabeçalho (elemento com `aria-expanded`). Anotar o **id do módulo** dos links `/curso/<id>/modulo/<modId>/aula/<aulaId>`.

### Criar aulas (rápido)
- Com o módulo expandido, no campo `input[placeholder="Nome da aula"]`: `browser_type` com `submit:true` (Enter cria a aula). Repetir para todas. Ler depois título→id:
  ```js
  [...document.querySelectorAll('article')].filter(a=>/^Aula /.test(a.textContent.trim())).map(a=>{let p=a,h=null;for(let i=0;i<6&&p;i++){const l=p.querySelector&&p.querySelector('a[href*="/aula/"]');if(l){h=l.getAttribute('href');break;}p=p.parentElement;}return {t:a.textContent.trim(), id:(h&&h.match(/aula\/(\d+)/)||[])[1]};})
  ```
  (Aulas que **já têm conteúdo** não mostram o link "Adicionar conteúdo".)

### Incorporar o vídeo (por aula)
- `browser_navigate` → `https://my.nutror.com/curso/<id>/modulo/<modId>/aula/<aulaId>#conteudo`
- click card **Incorporado**: `text=Adicione mídias via links ou códigos embed`
- `browser_type` no campo `[placeholder="Insira o link ou código embed aqui"]` com `https://youtu.be/<id>`
- **Validar→Inserir→Salvar via JS** (o botão fixo `#lesson-save-button` sobrepõe o "Validar" e intercepta cliques normais):
  ```js
  async () => {
    const sleep=ms=>new Promise(r=>setTimeout(r,ms));
    const find=t=>[...document.querySelectorAll('button')].find(b=>b.textContent.trim()===t&&!b.disabled);
    let v=find('Validar'); if(v)v.click();
    let ins=null; for(let i=0;i<25;i++){await sleep(200); ins=find('Inserir'); if(ins)break;}
    if(ins)ins.click();
    let s=null; for(let i=0;i<25;i++){await sleep(200); s=document.querySelector('#lesson-save-button'); if(s&&!s.disabled)break;}
    let saved=false; if(s&&!s.disabled){s.click(); saved=true;}
    return {validar:!!v, inserir:!!ins, saved};
  }
  ```
- Validar persistência: recarregar a URL da aula e checar `/(youtube|youtu\.be|<videoId>)/.test(document.body.innerHTML)`.

### Verificação final
`/curso/<id>/conteudo`, expandir o módulo, conferir contagem de aulas e que nenhuma das novas tem link "Adicionar conteúdo" (= todas com conteúdo).

## Armadilhas resumidas
- Chrome debug bloqueado no dir padrão → usar perfil copiado.
- CDP-attach externo não funciona → MCP lança o Chrome.
- Sessão não migra → login manual 1×.
- Download grande do Drive → interstício "Fazer download mesmo assim".
- Completar download → comparar bytes com `fileSize`.
- YouTube vídeo grande → diálogo "Processando vídeo" (fechar; já salvou Não listado).
- Nutror → clicar Validar/Inserir/Salvar via JS por causa do overlay do botão fixo.
