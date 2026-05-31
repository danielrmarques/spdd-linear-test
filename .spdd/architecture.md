---
type: spdd-architecture
project: "{{project_name}}"
updated: {{date}}
updated_by: "{{agent}}"
---

# Arquitetura — {{project_name}}

## Visão Geral

{{Descrição da arquitetura do projeto em 2-3 parágrafos}}

## Stack

| Camada | Tecnologia | Versão |
|---|---|---|
| {{camada}} | {{tech}} | {{versão}} |

## Componentes

```
{{diagrama de componentes em texto}}
```

## Decisões Arquiteturais (ADRs)

| # | Decisão | Status | Data |
|---|---|---|---|
| {{NNN}} | {{decisão}} | {{accepted/deprecated}} | {{data}} |

## Dependências Externas

| Serviço | Propósito | Como acessar |
|---|---|---|
| {{serviço}} | {{propósito}} | {{env var ou config}} |

## Padrões Adotados

- {{pattern}} — {{onde e por quê}}
