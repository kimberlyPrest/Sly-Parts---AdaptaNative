# Central Sly — Task 1.01 / SPEC-1-001

**Banco:** Supabase Comercial (`oznknqxqagcbdihdqufz`)  
**Migração aplicada:** `20261008200530` — `task_1_01_perfis_auditoria_rls`  
**Escopo desta rodada:** somente task 1.01 (perfis, auditoria, funções de papel e RLS).

## Evidências — estado anterior (RED)

- Consulta de `perfis` como usuário autenticado vendedor falhou com `ERROR 42P17: infinite recursion detected in policy for relation "perfis"`.
- Antes da migração: não havia tabela `auditoria`; RLS de `perfis` não estava forçada e havia política `perfis_select USING (true)` e regras recursivas.

## Evidências — estado após migração (GREEN)

- Vendedor (`33333333-3333-4333-8333-333333333333`): `papel=vendedor`, `eh_gestao=false`, vê **1** perfil.
- Supervisora (`55555555-5555-4555-8555-555555555555`): `papel=supervisora`, `eh_gestao=true`, vê **9** perfis.
- PCP (`99999999-9999-4999-8999-999999999999`): `papel=pcp`, `eh_gestao=false`, vê **1** perfil.
- Perfis após migração: **9**; todos mantiveram `id=user_id`; todos têm `criado_em` e `atualizado_em`; os 40 clientes e 25 ações preexistentes continuaram intactos.
- RLS está ativada e forçada em `perfis` e `auditoria`.
- Papel autenticado não tem permissão SQL para inserir, alterar ou apagar `perfis`; `anon` não pode ler `perfis`.
- `registrar_acesso()` atualiza `ultimo_acesso_em` para o usuário autenticado.
- `registrar_auditoria()` grava evento de UPDATE em `auditoria` dentro da mesma transação de teste; o teste foi revertido.
- Validações de nome (2–80 caracteres) e código FOCCO obrigatório para vendedor rejeitam entradas inválidas.
- Preview testado após a migração: login rápido do vendedor abriu `/meu-dia`; botão de supervisora carregou `/meu-dia` com a visão ampla. Na Carteira, supervisora viu 40 clientes; vendedor Carlos viu os 8 clientes atribuídos a ele.

## Limite identificado (não alterado nesta task)

As políticas herdadas de `clientes` e outras tabelas ainda usam `vendedor_id = auth.uid()` diretamente. Portanto, embora `papel_atual()` retorne `NULL` para um usuário inativo, a remoção imediata de todo acesso aos próprios dados depende de revisar essas políticas no escopo correspondente. Não alterei outras tabelas/políticas para manter a execução restrita à task 1.01. Também não testei o fluxo de convite, login por todos os papéis ou tela de administração: pertencem às tasks 1.02–1.04.

## Testes manuais para Gabi

1. Entre no preview com o botão rápido **Vendedor Carlos Eduardo**. Deve abrir Meu dia sem erro.
2. Abra **Carteira**. O vendedor deve ver somente a carteira atribuída a ele.
3. Troque para o botão rápido **Supervisora Renata Silveira**. Ela deve conseguir ver a carteira completa.
4. Na validação SQL/RLS, repita a consulta `select count(*) from public.perfis`: como vendedor = 1; como supervisora = 9.
5. Confirme no histórico de migrações do Supabase que `task_1_01_perfis_auditoria_rls` está aplicada.

**Observação:** o passo de Carteira valida regressão do app; as permissões da Carteira serão formalmente aceitas na SPEC-1-004. Não altere/remova usuários ou dados de produção durante a validação.
