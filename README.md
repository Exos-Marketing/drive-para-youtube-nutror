# drive-para-youtube-nutror

Skill do Claude Code que publica gravações como aulas: baixa os vídeos de uma pasta do Google Drive, sobe cada um
num canal do YouTube como **Não listado** (título = nome do arquivo) e incorpora cada vídeo como aula num módulo de
um curso na Nutror. É genérica: recebe a pasta, o canal e o curso + módulo como parâmetros.

```
pasta do Drive  →  download (1 vídeo por vez)  →  YouTube Studio (Não listado)  →  aula na Nutror (embed)  →  conferência
```

## Instalação

```bash
git clone https://github.com/Exos-Marketing/drive-para-youtube-nutror.git \
  ~/.claude/skills/drive-para-youtube-nutror
```

Requisitos:

- O MCP do Google Drive, para listar a pasta.
- O MCP do Playwright dirigindo um Chrome autenticado. O `scripts/prepare-profile.sh` copia o perfil logado da
  conta Google para uma pasta própria, porque o Chrome 136+ não deixa automatizar o perfil padrão.
- Login manual, na hora, no Google (canal do YouTube) e na Nutror/Eduzz como produtor.

**Nenhuma credencial mora neste repo.** O login é sempre feito pela pessoa, no navegador da automação.

## Uso

No Claude Code, peça "sobe as gravações dessa pasta no YouTube e coloca na Nutror", com o link da pasta, o canal e
o curso + módulo. A skill faz um piloto com 1 vídeo antes do lote e registra `título → arquivo → link do YouTube →
aula` num `links.md`, para poder retomar.

## Regras

- Um vídeo por vez (pico de ~2 GB em disco); o `.mp4` é apagado depois de subir.
- O download só vale quando o tamanho em bytes bate com o do Drive.
- Antes de subir, confere se o canal já tem vídeo com o mesmo título, para retomar sem duplicar.

## O que tem aqui

| arquivo | o que faz |
|---|---|
| `SKILL.md` | parâmetros, fluxo e regras |
| `REFERENCE.md` | setup do Chrome autenticado e os seletores e armadilhas do YouTube Studio e da Nutror |
| `scripts/prepare-profile.sh` | prepara o perfil logado do Chrome para o Playwright |

---

Interno · Exos Marketing Digital e Internacionalização Ltda.
