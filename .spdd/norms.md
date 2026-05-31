# Norms — Padrões Cross-Cutting

## Logging

- Formato: JSON estruturado
- Níveis: ERROR (ação necessária), WARN (atenção), INFO (operacional), DEBUG (dev only)
- Campos obrigatórios: timestamp, level, message, correlation_id
- Sem PII em logs (mascarar emails, tokens, senhas)

## Error Handling

- Erros esperados: tratar com tipos específicos (não catch genérico)
- Erros inesperados: log + rethrow (não engolir silenciosamente)
- API: retornar HTTP status correto + body com {error, message, details}
- Sem stack traces em produção para o cliente

## Observabilidade

- Métricas: latência, throughput, error rate por endpoint
- Tracing: correlation_id propagado entre serviços
- Health check: `/health` retorna status + dependências

## Testes

- Unit tests: comportamento, não implementação
- Integration tests: boundaries reais (DB, API externa)
- E2E tests: happy path + edge cases críticos
- Coverage mínimo: {{X}}%

## Documentação

- README.md atualizado com setup, run, test
- API documentada (OpenAPI / swagger se aplicável)
- ADRs para decisões não-triviais
- CHANGELOG.md mantido
