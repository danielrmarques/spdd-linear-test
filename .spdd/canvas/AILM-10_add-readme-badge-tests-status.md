---
type: spdd-canvas
feat_id: AILM-10
title: "Add README badge: tests status"
status: approved
approval_mode: fast-track
author: architect
created: 2026-06-01
updated: 2026-06-01
---

# AILM-10: Add README badge: tests status

## R — Requirements

**Problema:** README.md lacks a visual signal of test suite health. Contributors and users have no at-a-glance indicator that tests pass.

**Definition of Done:**
- [x] README.md contains a badge image near the top of the file
- [x] Badge text reads "tests passing" in a green-ish color
- [x] `npm test` continues to pass after the change

## E — Entities

**Entidades de domínio:**
- `README.md` — project root documentation file; the only file modified
- `badge` — an inline markdown image `![label](url)` rendered by GitHub as a shield
- `shields.io` — badge CDN that serves static SVGs via parameterised URL; no auth required

## A — Approach

**Estratégia:** Embed a static Shields.io badge as a Markdown image tag directly in README.md, immediately after the `# spdd-linear-test` heading. Use the `https://img.shields.io/badge/{label}-{message}-{color}` URL format with `label=tests`, `message=passing`, `color=brightgreen`. This requires no CI integration, no new dependencies, and renders correctly on GitHub.

**Alternativas descartadas:**
- **Dynamic GitHub Actions badge** — requires a CI workflow file and badge gist/endpoint; out of scope per acceptance criteria
- **Codecov / external CI badge** — requires third-party account setup; disproportionate for a static signal

## S — Structure

**Componentes afetados:**
- `README.md` — one line inserted after the `# spdd-linear-test` heading

**Dependências:**
- `shields.io` CDN (external, read-only, no credentials) — badge is fetched by GitHub at render time; badge itself is static and does not reflect actual CI state

**Impacto:**
- No code paths changed; no logic affected
- `npm test`, `npm run typecheck`, `npm run lint` are unaffected

## O — Operations

**Steps de implementação (ordem de execução):**

1. **Insert badge line in README.md** ✅
   - Arquivo: `README.md`
   - Operação: add `![tests](https://img.shields.io/badge/tests-passing-brightgreen)` on the line immediately after `# spdd-linear-test`
   - Comportamento: renders as a green badge on GitHub and in any Markdown viewer
   - Teste: visual inspection in PR preview; no automated assertion needed

2. **Verify test suite** ✅
   - Comando: `npm test`
   - Comportamento: all existing tests must pass unchanged
   - Teste: `npm test` exit code 0

## N — Norms

**Padrões aplicáveis (de `norms.md`):**
- Documentação: README.md deve ser mantido atualizado — this change fulfils that norm
- Logging/Error handling: not applicable (docs-only change)
- Naming: badge alt-text `tests` matches the subject; `passing` matches the test command name

## S — Safeguards

**Limites aplicáveis (de `safeguards.md`):**
- Sem secrets hardcoded: badge URL contains no credentials; shields.io URL is public
- Sem PII em logs: not applicable
- Invariantes: `npm test` must still exit 0 — verified in Operation 2 before merge
