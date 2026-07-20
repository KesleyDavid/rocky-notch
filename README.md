# vibenotch

Monitor e aprovador de agentes de código de IA no notch do seu Mac.

Sessões do Claude Code aparecem no notch com status ao vivo; pedidos de
permissão chegam como um cartão com **Aprovar / Negar / No terminal** — sem
trocar de janela, em qualquer terminal (Terminal.app, VS Code, Cursor, cmux,
SSH), porque a integração é via hooks oficiais, não injeção de terminal.

## Como funciona

```
Claude Code ──PermissionRequest──▶ vibenotch-hook ──socket──▶ Vibenotch.app (notch)
     ◀── allow/deny ◀─────────────────────────────◀── você toca Aprovar/Negar
```

**Fail-open por contrato:** se o app não estiver rodando (ou travar, ou
demorar), o hook sai em milissegundos sem output e o prompt normal aparece no
terminal. O vibenotch nunca bloqueia seu trabalho.

## Build e uso

```sh
make app        # monta dist/Vibenotch.app (assinatura ad-hoc)
make run        # build + abre
make test       # testes unitários (VibenotchCore)
Tests/integration.sh  # harness ponta-a-ponta (hook real x app real)
```

Depois de abrir: ícone na menu bar → "Instalar integração com Claude Code…"
(cria backup `~/.claude/settings.json.vibenotch-bak`). Sessões novas do
Claude Code aparecem no notch.

## Estrutura

- `Sources/VibenotchCore` — modelos de eventos, protocolo NDJSON do IPC,
  máquina de estados de sessão, merge do settings.json. Puro e testado.
- `Sources/VibenotchHook` — CLI mínimo executado pelos hooks; cliente do
  socket Unix com deadlines agressivos.
- `Sources/VibenotchApp` — app SwiftUI/AppKit: servidor IPC, AgentHub,
  janela do notch, adapter do Claude Code.
- `docs/superpowers/` — spec de design e plano de implementação.

## Roadmap (fase 2)

Adapters Codex/Cursor/OpenCode/Gemini · transcript watcher (status mais rico)
· quotas · foco em pane/aba específica · Developer ID + notarização + updates
· licenciamento e site.
