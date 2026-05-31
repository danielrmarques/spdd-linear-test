# Safeguards — Limites Não-Negociáveis

## Segurança

- Sem secrets hardcoded (API keys, tokens, passwords) — use env vars
- Input validation em todo boundary (API endpoints, forms, CLI args)
- SQL injection: usar prepared statements / ORM, nunca string concat
- XSS: sanitizar output em templates
- CORS configurado explicitamente (não wildcard em produção)
- Dependências: audit periódico, sem vulnerabilidades críticas

## Performance

- Timeout máximo de API: {{X}} segundos
- Payload máximo: {{X}} MB
- Queries: sem N+1, sem full table scan em tabelas > 10K rows
- Memory: sem leaks conhecidos, sem caches ilimitados

## Invariantes

- {{invariante do domínio que nunca pode ser violado}}
- Dados de produção nunca em logs (PII, tokens, senhas)
- Todo endpoint autenticado exceto os listados em whitelist

## Disponibilidade

- Health check endpoint obrigatório
- Graceful shutdown implementado
- Retry com backoff em chamadas externas

## Dados

- Migrations são forward-only (sem rollback destrutivo)
- Backup antes de migration em produção
- Soft delete > hard delete
