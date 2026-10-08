# SPEC-1-008 — Supervisão, alertas de estagnação, reatribuição e Parâmetros

**Fase:** 1  
**Status:** planejada  
**Dono:** Marco Carvalho (TI Platina) · **Consultoria:** Kimberly Prestes (Adapta)  
**Origem no escopo:** `02-Escopo-Definitivo.md` §8.5 (estagnação e alertas), §9.10 (Supervisão), §9.12 (Parâmetros e cadastros auxiliares), §7.3 (`alertas`), §7.1 (`historico_carteira`), §4.2 (reatribuir e parâmetros), D13  
**Degrau da solução:** recurso nativo da plataforma — pg_cron, funções SQL e telas no Skip; alertas somente dentro do sistema (sino); nenhuma integração.

## Contexto e decisões fechadas

- **Estado atual:** a supervisora não tem como saber, sem perguntar, quem fez o quê. Clientes em queda podem passar semanas sem contato. Os limites das regras só mudam por SQL (SPEC-1-003).
- **Estado desejado:**
  - A Ângela abre a **Supervisão** e vê, por vendedor, o andamento do dia, as atrasadas e os clientes em queda sem contato.
  - Ela recebe alertas no sino quando uma ação ou um cliente estagna, reatribui clientes e ações, e ajusta os limites das regras pela tela **Parâmetros**.
- **Decisões já fechadas:**
  - **Rota:** `/supervisao`, tela inicial da supervisora (altera o destino da SPEC-1-001).
  - **Alertas** aparecem só no sino da barra superior (fase 1). Envio por e-mail ou mensagem fica para a fase 2 (Maestro).
  - **Estagnação** verificada de hora em hora, das 08:00 às 18:00 dos dias úteis (`0 11-21 * * 1-5` UTC).
  - Os alertas de WhatsApp (conversa sem resposta) são da fase 2. Os de lote (lote parado, lote atingido) entram pela SPEC-1-011 reutilizando `abrir_alerta`.
  - **Reatribuição manual protegida:** cliente reatribuído pela supervisora recebe `clientes.vendedor_manual = true`, e a importação L1 deixa de sobrescrever o vendedor desse cliente. A divergência com o FOCCO aparece como aviso na prévia da importação. Isso altera a RN-04 da SPEC-1-002.
  - **Parâmetros:** editáveis por supervisora e admin, com validação de tipo e faixa, histórico (auditoria) e efeito na próxima execução da rotina comercial.
  - **Cadastros auxiliares** (admin): feriados, resultados (somente descrição e ativo, sem mudar as regras de código), motivos de perda.
- **Bloqueios:** nenhum.

## Resultado observável

A Ângela abre a Supervisão às 11:00 e vê:
- Marcio com 6 de 12 ações concluídas e 1 atrasada;
- Camila com 3 clientes em queda sem contato há mais de 7 dias.

O sino mostra "Ação parada: Reativar Serraf (Camila) — 2 dias úteis sem resultado". Ela reatribui o cliente Serraf para Tatiele, e a ação aberta vai junto. Depois, muda o limite diário de ações de 15 para 12 em Parâmetros, e no dia seguinte cada vendedor recebe no máximo 12 novas.

## Limites e dependências

- **Inclui:**
  - tabela `alertas`, função `abrir_alerta`, sino com lista e contador;
  - job `verificar-estagnacao` (regras abaixo);
  - coluna `clientes.vendedor_manual` e ajuste de `confirmar_importacao` para L1;
  - funções `reatribuir_clientes` e `reatribuir_acao`;
  - rota `/supervisao`;
  - rota `/admin/parametros` (supervisora e admin);
  - rota `/admin/cadastros` (admin);
  - menu e destino da supervisora.
- **Fora de escopo:**
  - alertas de WhatsApp e envio de alertas por e-mail ou mensagem (fase 2);
  - alertas de lote (SPEC-1-011);
  - painéis históricos (SPEC-1-012).
- **Entradas e pré-condições:** SPECs 1-006 e 1-007 (ações e resultados); SPEC-1-002 (`parametros`, `feriados`, `historico_carteira`); SPEC-1-001 (auditoria).
- **Saídas/artefatos:** migração SQL; telas; validação da Ângela em `05_entregas/fase-1/SPEC-1-008/`.
- **Dependências e responsáveis:** Marco constrói no Skip e no Supabase, com orientação da consultora Kimberly; Ângela valida.
- **Atores e permissões mínimas:**

| Ator | Supervisão | Alertas | Reatribuir | Parâmetros | Cadastros auxiliares |
|---|---|---|---|---|---|
| supervisora | ✔ | os próprios | clientes e ações | editar | — |
| admin | — | os próprios | clientes e ações | editar | editar |
| diretoria | leitura | — | — | leitura | — |
| vendedor | — | os próprios (conversas e ocorrências nas fases e SPECs que os criam) | — | — | — |

- **Superfícies/arquivos/configurações afetadas:** Supabase: `alertas`, `abrir_alerta`, `verificar_estagnacao`, job, `clientes.vendedor_manual`, `confirmar_importacao` (L1), funções de reatribuição, políticas de escrita de `parametros`, `feriados`, `resultados_tipo` e `motivos_perda`; Skip: sino, `/supervisao`, `/admin/parametros`, `/admin/cadastros`, menu e destino da supervisora.
- **Risco e plano B:** excesso de alertas → limite de 1 alerta por tipo e referência por dia (RN-02), e a supervisora pode marcar "Silenciar por 7 dias" em alertas de cliente.
- **Rollback ou reversão:**
  - Desligar o job interrompe os alertas.
  - Uma reatribuição é revertida reatribuindo de volta, com histórico preservado.
  - Uma alteração de parâmetro é revertida pelo botão "Restaurar valor anterior" do histórico.

## Dados e integrações

Sem integração externa.

**Tabela `alertas`:**
- `tipo` check (`acao_parada`,`cliente_queda_sem_contato`,`vendedor_sobrecarregado`,`rotina_falhou`) — tipos acrescentados por outras SPECs ampliam o check;
- `destinatario_id` · `titulo` · `mensagem` · `referencia` jsonb (`cliente_id`, `acao_id`, `vendedor_id`) · `link` (rota interna) · `situacao` (`aberto`,`lido`,`resolvido`) · `silenciado_ate` date · `criado_em`;
- RLS: `select` e `update` (`situacao`, `silenciado_ate`) somente do próprio destinatário;
- `insert` somente por `abrir_alerta(tipo, destinatario_papel_ou_id, titulo, mensagem, referencia, link)` (`security definer`).

| Regra | Condição | Ação/resultado | Exceção | Fonte |
|---|---|---|---|---|
| RN-01 Ação parada | Ação `aberta` de faixa alta com `data_prevista` há **≥ 2 dias úteis**, ou de faixa normal há **≥ 5 dias úteis** | Alerta para a supervisora: "Ação parada: {título} ({vendedor}) — {n} dias úteis sem resultado", link para a ficha | Ações `na_fila` não contam | §8.5 |
| RN-02 Deduplicação | Mesmo tipo + mesma referência + mesmo destinatário com alerta `aberto` ou `lido` criado no mesmo dia, ou silenciado | Não cria outro | — | ruído |
| RN-03 Cliente em queda sem contato | `situacao_comercial = 'queda'` e nenhuma interação não anulada há **≥ 7 dias** | Alerta para a supervisora: "{cliente} em queda há {n} dias sem contato ({vendedor})" | — | §8.5 |
| RN-04 Vendedor sobrecarregado | Vendedor com **> 10** ações atrasadas | Alerta para a supervisora: "{vendedor} com {n} ações atrasadas" | — | §8.5 |
| RN-05 Rotina falhou | `rotina_comercial` ou importação com situação `falhou` | Alerta para admin e supervisora com o link para Importações | — | §8.5 |
| RN-06 Resolução automática | A condição do alerta deixou de existir (ação concluída, contato registrado) | Alerta passa a `resolvido` na próxima verificação | — | ruído |
| RN-07 Reatribuir clientes | Supervisora ou admin escolhe 1 ou N clientes e o novo vendedor, com motivo obrigatório | Atualiza `vendedor_id`, `vendedor_manual = true`; grava `historico_carteira`; move as ações **abertas** desses clientes para o novo vendedor | Novo vendedor inativo → erro | §9.10 |
| RN-08 Reatribuir ação | Supervisora ou admin escolhe uma ação aberta e o novo responsável | Atualiza `vendedor_id` da ação; observação "Reatribuída de X para Y por Z" | — | §9.10 |
| RN-09 L1 e vendedor manual | Importação L1 com `codigo_vendedor` diferente para cliente com `vendedor_manual = true` | Mantém o vendedor manual; aviso na prévia "{n} clientes com vendedor definido manualmente diferem do FOCCO" | Supervisora pode "Voltar ao vendedor do FOCCO" no cliente (zera `vendedor_manual`) | integridade |
| RN-10 Parâmetros | Edição | Valida tipo e faixa por chave (tabela abaixo); grava `alterado_por`, `alterado_em` e auditoria; efeito na próxima `rodar_rotina_comercial` | Valor fora da faixa → erro no campo | §9.12 |

**Faixas de validação dos parâmetros** (todas as chaves das SPECs 1-002, 1-003 e 1-006):

| Grupo na tela | Chaves | Faixa |
|---|---|---|
| Métricas | `metricas_dias_recentes` (30–120), `metricas_meses_referencia` (3–12), `elegibilidade_media_minima` (0–100.000), `elegibilidade_faturamentos_minimos` (1–24), `mercados_excluidos_consumo` (lista dos 4 mercados) | inteiros/lista |
| Queda e situação | `queda_atencao` (−0,90 a −0,05), `queda_critica` (−0,95 a −0,10, menor que `queda_atencao`), `dias_inativo` (60–365) | decimais/inteiros |
| Família e itens | `familia_meses_minimos` (1–6), `familia_dias_sem_compra` (30–180), `item_chave_percentual` (0,01–0,50), `item_chave_dias_sem_compra` (30–365) | — |
| Recompra e silêncio | `recompra_fator` (1,0–3,0), `recompra_dias_extra` (0–60), `recompra_fator_critico` (1,5–5,0), `silencioso_dias` (15–180) | — |
| Pendências | `pendencia_antiga_dias` (7–120), `preco_referencia_dias` (30–365) | — |
| Prioridade | os 8 pesos (0,1–3,0), `fator_atraso_por_dia` (0–0,5), `fator_atraso_maximo` (1–5), `faixa_alta_percentual` (0,05–0,80) | — |
| Rotina | `acoes_limite_diario` (3–50), `sla_dias_uteis_alta` (1–10), `sla_dias_uteis_normal` (1–20), `cooldown_dias` (7–120) | — |
| Estagnação | `estagnacao_alta_dias_uteis` (2), `estagnacao_normal_dias_uteis` (5), `queda_sem_contato_dias` (7), `sobrecarga_atrasadas` (10) — inseridos nesta SPEC | 1–30 / 1–30 / 1–60 / 1–100 |
| Funil e follow-up | `lead_parado_dias` (5–60), `followup_1_dias_uteis` (1–15), `followup_2_dias_uteis` (1–15) — inseridos pela SPEC-1-009 | inteiros |
| Sistema | `vendedor_padrao_id` (lista de perfis ativos supervisora/vendedor), `importacao_janela_desfazer_horas` (1–72), `importacao_retencao_dias` (7–180) | — |

## Telas

**Sino (barra superior, todos os papéis):**
- contador de alertas `aberto`;
- o painel lista os alertas por data, com título, mensagem, hora e link;
- ações: "Marcar como lido", "Resolver" e, para alertas de cliente, "Silenciar 7 dias";
- aba "Resolvidos" com os últimos 30 dias.

**`/supervisao`:**
1. **4 KPIs da equipe hoje:**
   - Ações concluídas / total do dia;
   - Atrasadas;
   - Clientes em queda sem contato há 7+ dias;
   - Alertas abertos.
2. **Quadro por vendedor** (cartões):
   - avatar e nome;
   - barra de progresso do dia;
   - atrasadas;
   - clientes em queda sem contato;
   - ações na fila;
   - "Ver ações" → o Meu dia do vendedor (seletor da SPEC-1-007).
3. **Alertas abertos** da supervisora, com ações rápidas: "Abrir ficha", "Reatribuir", "Assumir" (reatribui para si) e "Resolver".
4. **Reatribuir carteira:** abre a Carteira em modo seleção (checkbox por linha) → "Reatribuir selecionados" → modal com novo vendedor e motivo → confirmação "Reatribuir {n} clientes e {m} ações abertas para {vendedor}?".

**`/admin/parametros`:**
- grupos da tabela de faixas, cada parâmetro com rótulo em português, descrição curta, valor atual, faixa e última alteração (quem e quando);
- "Salvar" por grupo; "Histórico" mostra os valores anteriores com "Restaurar".

**`/admin/cadastros` (admin):**
- abas Feriados (adicionar e remover datas futuras), Resultados (descrição e ativo) e Motivos de perda (adicionar, renomear, desativar).
- Um item usado em registros nunca é apagado, apenas desativado.

| Cenário | Dado/condição | Resultado esperado | Caminho de erro/recuperação |
|---|---|---|---|
| Principal | Ação alta com `data_prevista` 2 dias úteis atrás | Um alerta para a supervisora na verificação seguinte | — |
| Principal | Reatribuir 3 clientes de Camila para Tatiele | 3 clientes com Tatiele; ações abertas movidas; histórico gravado; Carteira e Meu dia atualizados | — |
| Limite | Feriado entre a data prevista e hoje | Não conta como dia útil | — |
| Limite | Verificação horária repetida no mesmo dia | Sem alerta duplicado | — |
| Limite | Contato registrado no cliente alertado | Alerta passa a `resolvido` na próxima verificação | — |
| Falha | `queda_critica` maior que `queda_atencao` | Erro "A queda crítica deve ser menor que a de atenção." | Corrigir |
| Falha | Vendedor tenta abrir `/supervisao` ou `/admin/parametros` | Redirecionado para o seu destino; escrita no banco recusada | — |
| Falha | Importação L1 com vendedor diferente para cliente reatribuído | Vendedor manual mantido; aviso na prévia | "Voltar ao vendedor do FOCCO" quando desejado |

## Instruções de execução para o Ethos

1. **Ler antes de alterar:** `02-Escopo-Definitivo.md` §8.5, §9.10 e §9.12; SPECs 1-002, 1-006 e 1-007; esta SPEC.
2. **Alterar somente:** objetos e telas desta SPEC; o trecho de L1 em `confirmar_importacao` (RN-09); o modo seleção da Carteira.
3. **Não alterar:** fórmulas do motor; regras de resultado.
4. **Executar nesta ordem:**
   1. `alertas` e `abrir_alerta`.
   2. `verificar_estagnacao` com a fixture.
   3. Sino.
   4. Reatribuição e RN-09.
   5. Supervisão.
   6. Parâmetros.
   7. Cadastros.
   8. Menu e destino.
   9. Validação com a Ângela.
5. **Parar e pedir validação quando:** a Ângela receber mais de 20 alertas por dia na primeira semana (calibrar parâmetros com ela antes de seguir).
6. **Estado válido ao parar:** nenhum alerta duplicado; reatribuições consistentes entre `clientes` e `acoes`.

## Checklist de execução

- [ ] `alertas`, `abrir_alerta` e sino
- [ ] `verificar_estagnacao` e job horário
- [ ] Reatribuição de clientes e ações, com `vendedor_manual` respeitado na L1
- [ ] Tela Supervisão
- [ ] Telas Parâmetros (com validação e histórico) e Cadastros auxiliares
- [ ] Menu e destino da supervisora → `/supervisao`
- [ ] Validação da Ângela
- [ ] Evidências salvas em `05_entregas/fase-1/SPEC-1-008/`

## Critérios de aceite

- [ ] **CA-1-37:** Uma ação de faixa alta sem resultado há 2 dias úteis (ou normal há 5) gera exatamente um alerta para a supervisora, que se resolve sozinho quando a ação é concluída.
- [ ] **CA-1-38:** Cliente "Em queda" sem interação há 7 dias e vendedor com mais de 10 atrasadas geram os alertas correspondentes, sem duplicar no mesmo dia.
- [ ] **CA-1-39:** Reatribuir N clientes move as ações abertas, grava o histórico e é preservado na importação L1 seguinte.
- [ ] **CA-1-40:** Alterar `acoes_limite_diario` para 12 faz a rotina do dia seguinte criar no máximo 12 ações novas por vendedor; um valor fora da faixa é recusado.
- [ ] **CA-1-41:** A tela Supervisão mostra, para cada vendedor, os mesmos números que as consultas SQL equivalentes (concluídas, total, atrasadas, queda sem contato).
- [ ] **CA-1-42:** Vendedor e diretoria não conseguem alterar parâmetros nem reatribuir (teste pelo banco).

## TDD da SPEC

| Etapa | Prova | Comando/ação | Resultado esperado | Evidência |
|---|---|---|---|---|
| RED 1 | Função inexistente | `select verificar_estagnacao()` | Erro "function does not exist" | `red.txt` |
| GREEN 1 | Ação parada | Fixture da SPEC-1-006; ajustar `data_prevista` da ação de C001 para 2 dias úteis atrás; rodar a verificação 2 vezes; concluir a ação; rodar de novo | 1 alerta; sem duplicata; `resolvido` depois da conclusão | `parada.txt` |
| GREEN 2 | Queda sem contato e sobrecarga | C007 sem interação há 7+ dias; criar 11 ações atrasadas para um vendedor de teste | 2 alertas corretos | `alertas.txt` |
| GREEN 3 | Reatribuição | Reatribuir C001 e C006 para outro vendedor; reimportar L1 da fixture | Ações movidas; histórico gravado; vendedor mantido após L1; aviso na prévia | `reatribuicao.txt` + captura |
| GREEN 4 | Parâmetro | Mudar `acoes_limite_diario` para 12 e gerar 20 sinais; tentar salvar `queda_critica = −0,20` | 12 com data do dia; erro de validação | `parametros.txt` |
| GREEN 5 | Números da Supervisão | Comparar os cartões com SQL equivalente | Iguais | `supervisao.txt` + captura |
| REFACTOR/REGRESSÃO | Permissão e feriado | Como vendedor e diretoria, `update parametros` e `select reatribuir_clientes(...)`; feriado no meio do intervalo | Recusados; dia não contado | `regressao.txt` |

**Caminhos de erro obrigatórios:** deduplicação, resolução automática, feriado, parâmetro fora da faixa, permissão, L1 versus vendedor manual.  
**Evidência exigida:** arquivos citados em `05_entregas/fase-1/SPEC-1-008/`.

## Handoff e operação

- **Como demonstrar:**
  1. Ângela abre a Supervisão.
  2. Ela trata um alerta de ação parada.
  3. Ela reatribui um cliente.
  4. Ela altera um parâmetro e mostra o histórico.
- **Como operar depois:**
  - A Ângela abre a Supervisão às 10:00 e às 15:00 dos dias úteis.
  - Ajustes de parâmetros são feitos por ela, com o motivo registrado no histórico.
- **Como monitorar:** contador do sino e KPI de alertas abertos.
- **Pendência conhecida:** nenhuma.

## Tasks vinculadas

| ID | Task | Dono | SPEC | Critério | Recorte da prova | Evidência esperada | Pré-condições | Status |
|---|---|---|---|---|---|---|---|---|
| 1.28 | Criar `alertas`, `abrir_alerta`, `verificar_estagnacao`, job horário e sino | Marco Carvalho | SPEC-1-008 | CA-1-37, CA-1-38 | RED 1 → GREEN 1, GREEN 2 | `parada.txt`, `alertas.txt` | 1.20 concluída | ☐ |
| 1.29 | Implementar reatribuição (clientes e ações, `vendedor_manual` na L1) e a tela Supervisão; mudar o destino da supervisora | Marco Carvalho | SPEC-1-008 | CA-1-39, CA-1-41 | GREEN 3, GREEN 5 | `reatribuicao.txt`, `supervisao.txt` | 1.28, 1.24 e 1.13 concluídas | ☐ |
| 1.30 | Construir as telas Parâmetros (validação e histórico) e Cadastros auxiliares, com as políticas de escrita | Marco Carvalho | SPEC-1-008 | CA-1-40, CA-1-42 | GREEN 4 e REGRESSÃO | `parametros.txt`, `regressao.txt` | 1.22 concluída | ☐ |
| 1.31 | Validar a Supervisão, os alertas e os parâmetros com a rotina real por 3 dias úteis | Ângela Ferreira | SPEC-1-008 | CA-1-41 | GREEN 5 com dados reais | `validacao.md` com volume de alertas por dia e ajustes feitos | 1.29 e 1.30 concluídas | ☐ |

## Emendas

<!-- Append-only (D19): mudanças aprovadas depois da geração. A história não é reescrita. -->

| Data | Origem do sinal | Micro-spec/task | Motivo |
|---|---|---|---|
| | | | |
