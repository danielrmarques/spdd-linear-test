# Fluxo E2E do Archon via Linear

Este documento descreve, ponta a ponta, como uma issue criada no Linear é
executada automaticamente pelo Archon: do momento em que ela recebe a label de
disparo até a abertura do PR no GitHub e o comentário de retorno no Linear.

> **Status:** validado em produção com a issue **AILM-7** — a issue saiu de
> *Todo*, o Archon executou o workflow, criou a branch, gerou código e teste,
> abriu o PR e comentou de volta no Linear.

---

## Visão geral

```
┌──────────────┐   label archon:execute    ┌───────────────────┐
│   Linear     │  ───────────────────────► │  linear-poller.py │
│  (issue AILM)│                            │  (VPS, a cada 2m) │
└──────────────┘                            └─────────┬─────────┘
        ▲                                             │ dispara
        │ comentário + estado                         ▼
        │                                   ┌───────────────────────┐
        │                                   │  archon-dispatcher.py  │
        │                                   │  • In Progress         │
        │                                   │  • cria branch         │
        │                                   │  • archon workflow run │
        │                                   │  • comenta no Linear   │
        │                                   │  • abre PR no GitHub    │
        └───────────────────────────────────┴───────────┬───────────┘
                                                          ▼
                                                  ┌──────────────┐
                                                  │   GitHub PR  │
                                                  └──────────────┘
```

---

## Fluxo pelo Linear

1. **Criar uma issue** no projeto **AILM** do Linear.
2. **Deixar a issue** no estado **Todo**.
3. **Adicionar a label** `archon:execute` — é ela que marca a issue como
   elegível para execução automática.
4. **Opcionalmente adicionar uma label de workflow** para escolher o tipo de
   execução:

   | Label                            | Workflow executado          |
   | -------------------------------- | --------------------------- |
   | *(sem label de workflow)*        | `archon-feature-development` (default) |
   | `workflow:archon-fix-github-issue` | `archon-fix-github-issue`   |
   | `workflow:archon-smart-pr-review`  | `archon-smart-pr-review`    |
   | `workflow:archon-refactor-safely`  | `archon-refactor-safely`    |

5. **O `linear-poller.py`** roda na VPS **a cada 2 minutos**, consultando o
   Linear por issues em *Todo* com a label `archon:execute`.
6. **Ele chama o `archon-dispatcher.py`**, que para cada issue elegível:
   - Move a issue para **In Progress**.
   - Cria a branch `ailm-NNN-slug` (onde `NNN` é o número da issue).
   - Executa `archon workflow run <workflow> "AILM-NNN"`.
   - Posta um **comentário no Linear** com o resultado da execução.
   - Abre um **PR no GitHub** quando aplicável.

---

## Como o Archon fala com o Linear

As três etapas de integração com o Linear são encapsuladas em comandos
reutilizáveis em `.archon/commands/`, executados pelos nós dos workflows:

| Comando                                   | Quando roda            | O que faz                                                       |
| ----------------------------------------- | ---------------------- | --------------------------------------------------------------- |
| `.archon/commands/linear-setup-board.md`  | início da execução     | move a issue → **In Progress**, aplica `type:feature`, anexa ao projeto |
| `.archon/commands/linear-post-comment.md` | ao longo / no fim      | posta um comentário (ex.: tabela de custo) na issue             |
| `.archon/commands/linear-mark-in-review.md` | após abrir o PR      | move a issue → **In Review**                                    |

Todas as chamadas usam a API GraphQL do Linear (`https://api.linear.app/graphql`)
e são **não-fatais**: se a API key não estiver configurada ou o estado não
estiver mapeado, a etapa é ignorada sem interromper o workflow.

---

## Configuração

A integração é configurada uma única vez por projeto em `.spdd/config.yml`,
na seção `linear:`. Os UUIDs (team, estados, labels, projeto) são preenchidos
de forma interativa pelo script:

```bash
bash .github/scripts/linear-init.sh
```

O script autentica com a Linear API, lista teams/estados/labels/projetos e
escreve os UUIDs no `config.yml`. Pré-requisitos:

- `curl` e `jq` instalados.
- Variável de ambiente `LINEAR_API_KEY` (formato `lin_api_...`). O `config.yml`
  guarda apenas o **nome** da env var em `linear.api_key_env`, nunca o valor.

```bash
export LINEAR_API_KEY=lin_api_...
echo 'export LINEAR_API_KEY=lin_api_...' >> ~/.bashrc   # persistir
```

Mapeamento atual em `.spdd/config.yml`:

| Chave                          | Significado                                 |
| ------------------------------ | ------------------------------------------- |
| `linear.team_id`               | UUID do team (AILM)                         |
| `linear.project_id`            | UUID do projeto (opcional)                  |
| `linear.states.in_progress`   | estado aplicado quando a execução começa    |
| `linear.states.in_review`     | estado aplicado quando o PR é aberto        |
| `linear.states.done`          | estado de conclusão                         |
| `linear.states.blocked`       | estado de bloqueio                          |
| `linear.labels.type_feature`  | label aplicada automaticamente              |
| `github.owner`                 | dono do repositório onde os PRs são abertos |

---

## Branch e PR

- **Branch:** `ailm-NNN-slug` — criada pelo dispatcher a partir de `main`.
  Nomear a branch com o identificador da issue permite que o Linear vincule
  automaticamente branch ↔ issue (integração Linear ⇄ GitHub).
- **PR:** criado com `gh pr create`. O corpo inclui a frase mágica
  `Closes AILM-NNN`, que fecha a issue automaticamente no merge, e uma tabela
  de estimativa de custo da execução. O título segue `feat(FEAT-NNN): {slug}`.
- Após abrir o PR, a issue é movida para **In Review** e recebe um comentário
  com o link do PR e o resumo de custo.

Para que o fechamento automático funcione, habilite a integração
Linear–GitHub em `https://linear.app/settings/integrations/github`.

---

## Workflows disponíveis

Os workflows do Archon ficam em `.archon/workflows/`. O default do projeto
(`.spdd/config.yml` → `default_workflow`) é `spdd-feature-exec`. Variantes:

| Workflow             | Gates humanos | Uso típico                                  |
| -------------------- | ------------- | ------------------------------------------- |
| `spdd-feature`       | sim           | fluxo completo com aprovação humana         |
| `spdd-feature-full`  | sim           | fluxo completo, todos os artefatos          |
| `spdd-feature-auto`  | não           | mesma estrutura do full, auto-aprovado      |
| `spdd-feature-fast`  | não           | versão enxuta / rápida                      |
| `spdd-feature-max`   | não           | cobertura máxima de análise                 |
| `spdd-feature-exec`  | —             | execução direta (default)                   |

Rodar manualmente um workflow para uma issue:

```bash
archon workflow run spdd-feature-exec "AILM-1"
```

---

## Checklist E2E (como validar)

1. [ ] `LINEAR_API_KEY` exportada e `.spdd/config.yml` preenchido
       (`bash .github/scripts/linear-init.sh`).
2. [ ] Criar issue no projeto AILM, deixar em *Todo*.
3. [ ] Aplicar a label `archon:execute` (+ label de workflow, se desejado).
4. [ ] Aguardar até 2 minutos (ciclo do `linear-poller.py`).
5. [ ] Confirmar que a issue foi para *In Progress*.
6. [ ] Confirmar a branch `ailm-NNN-slug` no repositório.
7. [ ] Confirmar o PR aberto no GitHub com `Closes AILM-NNN`.
8. [ ] Confirmar o comentário de resultado no Linear e o estado *In Review*.

> Este checklist foi exercido com sucesso na issue **AILM-7**.
