# Sinais de mudança

| Data | Quem | SPEC/task | Sinal | Resposta da consultora |
|---|---|---|---|---|
| 08/10/2026 | Lótus (execução técnica) | SPEC-1-001 / task 1.01 | Divergência de modelo: a SPEC descreve `perfis.id` como UUID próprio e `user_id` como FK a `auth.users`, mas a base já criada usa `perfis.id = auth.users.id`, e o app/ FKs comerciais referenciam esse ID. Para preservar os nove perfis e os vínculos existentes, a implementação mantém `id=user_id` 1:1. Validar com a Kimberly se este é o contrato definitivo ou se deve haver emenda/migração futura controlada antes da administração de usuários (task 1.02). | Pendente de validação da consultora |