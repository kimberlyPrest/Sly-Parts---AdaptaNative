# SPEC-1-010 — Pós-venda: ocorrências e acompanhamento

**Fase:** 1  
**Status:** planejada  
**Dono:** Marco Carvalho (TI Platina) · **Consultoria:** Kimberly Prestes (Adapta)  
**Origem no escopo:** `02-Escopo-Definitivo.md` §9.7 (Pós-venda), §7.4 (`ocorrencias`), §9.2.1 (resultado "Problema de atendimento ou qualidade"), §4.2 (permissões); "CRM tanto da parte comercial, tanto pós" (1ª Consultoria, ~31:07)  
**Degrau da solução:** construção mínima no Skip sobre uma tabela nova no Supabase, reaproveitando `acoes`, `alertas` e a linha do tempo; nenhuma integração.

## Contexto e decisões fechadas

- **Estado atual:**
  - Reclamações de qualidade, entrega, nota fiscal e divergência de peças chegam por WhatsApp, e-mail e telefone e são tratadas por troca de mensagens com Qualidade, Expedição e Fiscal (VSM da Ângela: "CONF PÇS", "SERASA - FATURA CORRIGIDA", "ENG - DÚVIDAS").
  - Não há registro único nem prazo.
  - Depois de resolver um problema ou reativar um cliente, ninguém volta para saber se ficou tudo bem.
- **Estado desejado:**
  - Cada problema do cliente vira uma **ocorrência** com tipo, responsável, área, prazo e situação, visível na ficha do cliente.
  - Ocorrência resolvida e primeiro pedido de cliente reativado geram, sozinhos, uma ação de **acompanhamento** para o vendedor.
- **Decisões já fechadas:**
  - **Rota:** `/pos-venda`.
  - **Origens de uma ocorrência:**
    - botão "Abrir ocorrência" na ficha;
    - resultado `problema` no Meu dia (habilitado por esta SPEC).
  - **Situações:** `aberta` → `em_tratamento` → `resolvida`. `resolvida` exige texto de resolução. Uma ocorrência resolvida pode ser **reaberta** em até 15 dias, com motivo.
  - **Prazo padrão:** 5 dias úteis a partir da abertura, ajustável na abertura (1 a 30 dias úteis).
  - **Áreas:** Qualidade, Expedição, Fiscal/Faturamento, PCP, Engenharia, Comercial, Financeiro.
  - **Responsável:** qualquer usuário ativo da Central Sly. Quando a área não tem usuário, o responsável é o vendedor do cliente, que acompanha com a área por fora.
  - **Alertas no sino:**
    - responsável recebe ao ser designado;
    - responsável e supervisora recebem quando o prazo vence sem resolução.
  - **Acompanhamentos automáticos:** criados por `gerar_acoes` (SPEC-1-006):
    - **7 dias** depois de uma ocorrência resolvida;
    - **10 dias** depois do primeiro faturamento de um cliente que teve ação de reativação concluída nos 45 dias anteriores.
- **Bloqueios:** nenhum.

## Resultado observável

O Marcio registra no Meu dia o resultado "Problema de atendimento ou qualidade" para a Cooper: "4 pistões PS 4938 0,50 vieram com medida trocada". Abre-se a ocorrência "Divergência de peças", área Expedição, responsável Ângela, prazo de 5 dias úteis. A Ângela recebe o alerta, trata e resolve com "Troca enviada na NF 30712". Sete dias depois, aparece no Meu dia do Marcio: "Acompanhamento Cooper — confirmar se a troca resolveu".

## Limites e dependências

- **Inclui:**
  - tabela `ocorrencias`;
  - funções `abrir_ocorrencia`, `atualizar_ocorrencia`, `reabrir_ocorrencia`;
  - habilitação do resultado `problema` em `registrar_resultado`;
  - acompanhamentos automáticos em `gerar_acoes`;
  - alertas `ocorrencia_designada` e `ocorrencia_vencida` (job de estagnação da SPEC-1-008);
  - rota `/pos-venda`;
  - botão e seção de ocorrências na ficha;
  - ocorrências na linha do tempo;
  - item de menu.
- **Fora de escopo:**
  - abertura de ocorrência pela IA a partir de conversa (fase 2);
  - integração com sistemas de qualidade;
  - envio de comunicação ao cliente;
  - indicadores de pós-venda (SPEC-1-012 lê esta tabela).
- **Entradas e pré-condições:** SPEC-1-007 (`registrar_resultado`, Meu dia), SPEC-1-008 (`alertas`, job), SPEC-1-005 (ficha e linha do tempo).
- **Saídas/artefatos:** migração SQL; telas; validação com 2 ocorrências reais.
- **Dependências e responsáveis:** Marco constrói no Skip e no Supabase, com orientação da consultora Kimberly; Ângela valida.
- **Atores e permissões mínimas:**

| Ator | Ver | Abrir | Atualizar e resolver | Reabrir |
|---|---|---|---|---|
| vendedor | ocorrências dos clientes da própria carteira e as que lhe foram designadas | própria carteira | as designadas a ele ou da própria carteira | — |
| supervisora | todas | todas | todas | ✔ |
| diretoria, pcp | todas (leitura) | — | as designadas a eles | — |
| admin | — | — | — | — |

- **Superfícies/arquivos/configurações afetadas:** Supabase: `ocorrencias`, funções, ajustes em `registrar_resultado` e `gerar_acoes`, tipos de alerta; Skip: `/pos-venda`, ficha, modal de resultado, menu.
- **Risco e plano B:** ocorrências sem responsável real (área sem usuário) → responsável = vendedor, com o campo "Área encaminhada" para registro.
- **Rollback ou reversão:** a tabela é independente; ocultar o menu e desabilitar o resultado `problema` volta ao estado anterior sem perda de dados.

## Dados e integrações

Sem integração externa.

**Tabela `ocorrencias`** (RLS conforme a matriz; auditoria):
- `cliente_id` (obrigatório) · `acao_id` (quando aberta por resultado) · `tipo` check (`qualidade`,`entrega`,`nota_fiscal`,`divergencia_pecas`,`outro`) · `descricao` (10 a 2.000 caracteres) · `numero_nota` · `numero_pedido` · `itens` text · `area` check (`qualidade`,`expedicao`,`fiscal`,`pcp`,`engenharia`,`comercial`,`financeiro`) · `responsavel_id` FK perfis · `aberta_por` · `situacao` (`aberta`,`em_tratamento`,`resolvida`) · `prazo` date · `resolucao` text · `resolvida_em` · `resolvida_por` · `reaberta_vezes` int · `criado_em`, `atualizado_em`.
- Índices (`cliente_id`, `situacao`) e (`responsavel_id`, `situacao`).

| Regra | Condição | Ação/resultado | Exceção | Fonte |
|---|---|---|---|---|
| RN-01 Abertura | Ficha ou resultado `problema` | Campos obrigatórios: tipo, descrição, área, responsável; prazo padrão de 5 dias úteis; `situacao = 'aberta'`; alerta `ocorrencia_designada` ao responsável (se não for quem abriu) | Resultado `problema` pré-preenche a descrição com a observação do resultado | §9.7 |
| RN-02 Tratamento | Responsável ou supervisora muda para `em_tratamento` | Registra quem e quando; comentário opcional na linha do tempo | — | §9.7 |
| RN-03 Resolução | Mudar para `resolvida` | Exige `resolucao` (≥ 10 caracteres); grava `resolvida_em` e `resolvida_por` | — | §9.7 |
| RN-04 Vencida | `situacao <> 'resolvida'` e hoje > `prazo` (dias úteis) | Alerta `ocorrencia_vencida` para o responsável e a supervisora (uma vez por dia, sem duplicar) | — | §8.5 |
| RN-05 Acompanhamento pós-ocorrência | Ocorrência resolvida há 7 dias e sem acompanhamento criado | `gerar_acoes` cria ação `pos_venda` "Acompanhamento {cliente} — confirmar se {tipo} foi resolvida" para o vendedor do cliente, faixa normal | Reaberta antes de 7 dias → não cria | §9.7 |
| RN-06 Acompanhamento pós-reativação | Primeira venda importada de um cliente cuja ação `reativacao` foi concluída nos 45 dias anteriores à venda | Ação `pos_venda` "Acompanhamento {cliente} — primeiro pedido após reativação" 10 dias depois da venda, faixa normal | Uma por reativação | §9.7 |
| RN-07 Reabertura | Supervisora, até 15 dias depois de resolvida | Volta a `aberta`, com motivo; cancela o acompanhamento ainda não feito | — | qualidade |
| RN-08 Linha do tempo | Abertura, mudança de situação e resolução | Aparecem na linha do tempo da ficha com ícone de pós-venda | — | §9.4 |

## Telas

**`/pos-venda`:**
1. **Cabeçalho:** "Pós-venda", contadores (Abertas, Em tratamento, Vencidas, Resolvidas nos últimos 30 dias) e botão "Nova ocorrência" (escolhe o cliente).
2. **Filtros:** situação, tipo, área, responsável, vendedor (gestão), "Somente as minhas", período.
3. **Tabela:** cliente (link para a ficha), tipo (badge), resumo da descrição, área, responsável, prazo (vermelho quando vencido), situação, dias em aberto.
4. **Detalhe** (painel lateral):
   - todos os campos e o histórico;
   - botões "Iniciar tratamento", "Resolver" (pede a resolução), "Reatribuir responsável" e "Reabrir" (supervisora).
5. **Celular:** lista de cartões.

**Ficha do cliente:**
- botão "Abrir ocorrência" no cabeçalho;
- seção "Ocorrências" com as abertas e as últimas 5 resolvidas.

**Modal de resultado (SPEC-1-007):** o cartão "Problema de atendimento ou qualidade" passa a aparecer. Ao escolhê-lo, o modal mostra os campos da RN-01 e, ao salvar, conclui a ação e abre a ocorrência na mesma transação.

| Cenário | Dado/condição | Resultado esperado | Caminho de erro/recuperação |
|---|---|---|---|
| Principal | Resultado `problema` com tipo, área e responsável | Ação concluída; ocorrência aberta com `acao_id`; alerta ao responsável | — |
| Principal | Ocorrência resolvida há 7 dias | Ação `pos_venda` no Meu dia do vendedor | — |
| Principal | Cliente reativado fatura em D; ação de reativação concluída em D − 20 | Acompanhamento em D + 10 | — |
| Limite | Prazo vencido | Um alerta por dia ao responsável e à supervisora | — |
| Limite | Reaberta no dia 5 após a resolução | Acompanhamento não é criado no dia 7 | — |
| Falha | Resolver sem texto | Bloqueado | Preencher |
| Falha | Vendedor tenta ver ocorrência de cliente de outra carteira (não designada a ele) | Não aparece; leitura direta recusada | — |

## Instruções de execução para o Ethos

1. **Ler antes de alterar:** `02-Escopo-Definitivo.md` §9.7; SPECs 1-005, 1-006, 1-007 e 1-008; esta SPEC.
2. **Alterar somente:** objetos desta SPEC; o trecho de `problema` em `registrar_resultado`; os trechos de acompanhamento em `gerar_acoes`; os tipos de alerta e sua verificação; as telas listadas.
3. **Não alterar:** as demais regras de resultado, sinais e alertas.
4. **Executar nesta ordem:**
   1. Tabela e funções.
   2. Resultado `problema`.
   3. Acompanhamentos.
   4. Alertas.
   5. Tela.
   6. Ficha.
   7. Validação.
5. **Parar e pedir validação quando:** a Ângela pedir área ou tipo novo (emenda) ou um fluxo de aprovação de troca/devolução (fora do escopo).
6. **Estado válido ao parar:** ocorrências abertas continuam visíveis; nenhuma ação concluída sem a ocorrência correspondente.

## Checklist de execução

- [ ] `ocorrencias`, funções e RLS
- [ ] Resultado `problema` habilitado e abrindo ocorrência na mesma transação
- [ ] Acompanhamentos automáticos (7 dias após resolução; 10 dias após primeiro pedido de reativado)
- [ ] Alertas de designação e de vencimento
- [ ] Tela Pós-venda, detalhe e celular
- [ ] Seção e botão na ficha; ocorrências na linha do tempo
- [ ] Validação com 2 ocorrências reais
- [ ] Evidências salvas em `05_entregas/fase-1/SPEC-1-010/`

## Critérios de aceite

- [ ] **CA-1-49:** O resultado "Problema de atendimento ou qualidade" conclui a ação e abre a ocorrência com tipo, área, responsável e prazo, numa única operação; o responsável recebe o alerta.
- [ ] **CA-1-50:** Uma ocorrência resolvida gera, 7 dias depois, a ação de acompanhamento no Meu dia do vendedor; o primeiro pedido de um cliente reativado gera o acompanhamento 10 dias depois.
- [ ] **CA-1-51:** Uma ocorrência vencida gera um alerta por dia ao responsável e à supervisora, até ser resolvida.
- [ ] **CA-1-52:** Vendedores só veem ocorrências da própria carteira ou designadas a eles; resolver exige texto de resolução.

## TDD da SPEC

| Etapa | Prova | Comando/ação | Resultado esperado | Evidência |
|---|---|---|---|---|
| RED 1 | Tabela inexistente | `select abrir_ocorrencia(...)` | Erro "function does not exist" | `red.txt` |
| GREEN 1 | Resultado `problema` | Fixture da SPEC-1-006: registrar `problema` na ação de C002 com tipo `divergencia_pecas`, área `expedicao` e responsável = supervisora | Ação concluída; ocorrência com `acao_id`; alerta à supervisora | `problema.txt` |
| GREEN 2 | Acompanhamento pós-ocorrência | Resolver a ocorrência com `resolvida_em` = 7 dias atrás (branch) e rodar `gerar_acoes` | 1 ação `pos_venda` para o vendedor de C002 | `acompanhamento.txt` |
| GREEN 3 | Acompanhamento pós-reativação | Concluir reativação de C003 em D − 20; importar venda de C003 em D; rodar com D + 10 | Ação `pos_venda` em D + 10 | `reativado.txt` |
| GREEN 4 | Vencida | Ocorrência com prazo de ontem; rodar a verificação 2 vezes | 1 alerta por destinatário | `vencida.txt` |
| GREEN 5 | Ocorrências reais | A Ângela abre e trata 2 ocorrências reais | Fluxo completo, com linha do tempo | `validacao.md` + capturas |
| REFACTOR/REGRESSÃO | Permissão, resolução sem texto, reabertura | Vendedor A consulta ocorrência de B; resolver sem texto; reabrir no dia 5 e rodar no dia 7 | 0; bloqueio; sem acompanhamento | `regressao.txt` |

**Caminhos de erro obrigatórios:** campos obrigatórios, resolução sem texto, vencimento, reabertura, permissão.  
**Evidência exigida:** arquivos citados em `05_entregas/fase-1/SPEC-1-010/`.

## Handoff e operação

- **Como demonstrar:**
  1. Marcio registra um problema pelo Meu dia.
  2. Ângela trata e resolve.
  3. Marco mostra o acompanhamento criado (data ajustada em teste).
- **Como operar depois:**
  - Toda reclamação vira ocorrência no mesmo dia.
  - A Ângela revisa as vencidas na Supervisão.
- **Como monitorar:** contadores da tela e painel (SPEC-1-012).
- **Pendência conhecida:** nenhuma.

## Tasks vinculadas

| ID | Task | Dono | SPEC | Critério | Recorte da prova | Evidência esperada | Pré-condições | Status |
|---|---|---|---|---|---|---|---|---|
| 1.35 | Criar `ocorrencias` e funções, habilitar o resultado `problema`, os acompanhamentos em `gerar_acoes` e os alertas de designação e vencimento | Marco Carvalho | SPEC-1-010 | CA-1-49, CA-1-50, CA-1-51, CA-1-52 | RED 1 → GREEN 1 a GREEN 4; REGRESSÃO | `problema.txt`, `acompanhamento.txt`, `reativado.txt`, `vencida.txt`, `regressao.txt` | 1.24 e 1.28 concluídas | ☐ |
| 1.36 | Construir a tela Pós-venda, o detalhe, a seção e o botão na ficha, a linha do tempo e o cartão no modal de resultado | Marco Carvalho | SPEC-1-010 | CA-1-49, CA-1-52 | GREEN 1 pela tela; REGRESSÃO pela tela | Capturas | 1.35 e 1.25 concluídas | ☐ |
| 1.37 | Abrir e tratar 2 ocorrências reais e validar o fluxo | Ângela Ferreira | SPEC-1-010 | CA-1-49 | GREEN 5 | `validacao.md` | 1.36 concluída | ☐ |

## Emendas

<!-- Append-only (D19): mudanças aprovadas depois da geração. A história não é reescrita. -->

| Data | Origem do sinal | Micro-spec/task | Motivo |
|---|---|---|---|
| | | | |
