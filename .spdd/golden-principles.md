# Golden Principles

Regras que mantêm este codebase legível para humanos e LLMs em futuras execuções.

---

## Mecânicos (enforced por hooks/CI)

1. **Lint em modo error** — não warnings. Se viola a regra, commit não passa.
2. **Type check obrigatório** — strict mode habilitado. Sem `any` ou `ignore`.
3. **Testes obrigatórios antes de done** — agente não declara pronto sem testes passarem.
4. **Commits atômicos** — um commit = uma mudança lógica. Sem "WIP", "fix stuff", "misc".
5. **Naming conventions enforced** — conforme `conventions.md`. Hook valida.
6. **Frontmatter em todo arquivo SPDD** — tipo, status, autor, data obrigatórios.
7. **Sem secrets no código** — env vars ou vault. Hook bloqueia patterns de API keys/tokens.

## Opinativos (enforced por review)

8. **Design before code** — REASONS Canvas preenchido e aprovado antes de gerar código.
9. **Prompt is the spec** — quando realidade diverge, corrige o Canvas primeiro, depois o código.
10. **Separação executor/validador** — quem implementa não é quem valida.
11. **Sem abstrações prematuras** — 3 linhas repetidas é melhor que uma abstração sem uso comprovado.
12. **Código auto-explicativo** — se precisa de comentário, o código está ruim. Exceção: comentários de "por quê", nunca de "o quê".
13. **Cada arquivo tem um propósito** — se não consegue descrever em uma frase, está fazendo demais.
14. **Testes testam comportamento, não implementação** — mock mínimo. Teste E2E quando possível.
15. **ADRs para decisões arquiteturais** — toda decisão não-trivial registrada em `architecture.md` ou no vault Brain.

## Closed Loop (regra de ouro)

**Quando realidade diverge do Canvas:**
- Se é correção de lógica → atualiza Canvas primeiro, depois regenera código
- Se é refactoring → refatora código primeiro, depois sincroniza Canvas

Nunca permitir que Canvas e código divirjam silenciosamente.
