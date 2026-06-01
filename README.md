# spdd-linear-test

![tests](https://img.shields.io/badge/tests-passing-brightgreen)

Projeto de teste da integração **SPDD + Archon + Linear**: issues criadas no
Linear são executadas automaticamente pelo Archon, que gera código, abre PR no
GitHub e comenta o resultado de volta no Linear.

## Documentação

- **[Fluxo E2E do Archon via Linear](docs/archon-linear-e2e.md)** — como uma
  issue vira código, PR e comentário, ponta a ponta. Comece por aqui.

## Estrutura

| Caminho                     | Conteúdo                                              |
| --------------------------- | ---------------------------------------------------- |
| `.spdd/`                    | configuração, convenções, arquitetura e princípios   |
| `.archon/workflows/`        | definições dos workflows do Archon                   |
| `.archon/commands/`         | comandos reutilizáveis de integração com o Linear    |
| `.github/scripts/`          | setup da integração (`linear-init.sh`)               |
| `utils/`                    | código de exemplo                                    |

## Setup rápido

```bash
export LINEAR_API_KEY=lin_api_...
bash .github/scripts/linear-init.sh   # preenche .spdd/config.yml
npm install
npm test
```

Para o fluxo completo via Linear, veja a
[documentação E2E](docs/archon-linear-e2e.md).
