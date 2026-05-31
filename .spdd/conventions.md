# Convenções de Código

## Naming

| Tipo | Convenção | Exemplo |
|---|---|---|
| Arquivos | {{kebab-case / snake_case}} | {{exemplo}} |
| Funções | {{camelCase / snake_case}} | {{exemplo}} |
| Classes | {{PascalCase}} | {{exemplo}} |
| Constantes | {{UPPER_SNAKE}} | {{exemplo}} |
| Variáveis | {{camelCase / snake_case}} | {{exemplo}} |

## Estrutura de Arquivos

```
src/
├── {{camada}}/
│   ├── {{padrão de organização}}
```

## Imports

- Ordem: {{stdlib → third-party → local}}
- Sem imports circulares
- Sem wildcard imports

## Estilo

- Indentação: {{2 ou 4 espaços}}
- Max line length: {{80 / 100 / 120}}
- Trailing commas: {{sim / não}}
- Quotes: {{single / double}}

## Git

- Branch naming: {{feature/FEAT-NNN-slug, fix/BUG-NNN-slug}}
- Commit message: {{tipo: descrição}} (feat, fix, refactor, docs, test, chore)
- PR title: {{FEAT-NNN: descrição curta}}
