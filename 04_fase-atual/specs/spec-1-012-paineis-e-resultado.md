# SPEC-1-012 — Painéis de gestão e medição de resultado

**Fase:** 1  
**Status:** planejada  
**Dono:** Marco Carvalho (TI Platina) · **Consultoria:** Kimberly Prestes (Adapta)  
**Origem no escopo:** `02-Escopo-Definitivo.md` §9.11 (Painéis de gestão), §8.6 (medição de resultado), §14 (indicadores de sucesso), §9.1 (destino da diretoria); dashboard do CRM citado na 1ª Consultoria (04:28)  
**Degrau da solução:** recurso nativo — views e uma tabela de fotografia diária no Supabase, gráficos com Recharts no Skip; nenhuma integração.

## Contexto e decisões fechadas

- **Estado atual:** os números comerciais são consolidados à mão no fechamento do mês. Não existe medição de execução, reativação ou prospecção (vídeo *Monitoramento da carteira*, 05:59 e 09:59).
- **Estado desejado:** `/paineis` mostra, por período e vendedor:
  - a execução da rotina;
  - a saúde da carteira ao longo do tempo;
  - o resultado (clientes reativados, faturamento recuperado, peças viabilizadas em lotes);
  - os motivos de perda;
  - a prospecção.
- **Decisões já fechadas:**
  - **Rota:** `/paineis`, tela inicial da diretoria (altera o destino da SPEC-1-001).
  - **Seções:** Execução, Saúde da carteira, Resultado, Motivos e Prospecção. A seção **Atendimento WhatsApp** é da fase 2.
  - **Fotografia diária:** a tabela `fotografia_carteira_diaria` guarda, ao fim de cada `rodar_rotina_comercial`, a contagem e o valor em risco por vendedor e situação, para mostrar a evolução. O histórico começa no dia da entrega desta SPEC; não há reconstrução retroativa.
  - **Medição de resultado** (§8.6) na tabela `resultado_reativacao`, recalculada no fim da rotina comercial:
    - **cliente reativado:** cliente em `queda` ou `inativo`, ou com sinal `cliente_silencioso` no momento da ação de reativação concluída, que nos **45 dias** seguintes fatura pelo menos **50% da média de referência**;
    - **faturamento recuperado:** faturamento do cliente reativado nos **60 dias** seguintes à ação, menos (média recente na data da ação × 2);
    - **peças viabilizadas:** soma dos compromissos de lote convertidos.
  - **Visibilidade:**
    - vendedor vê os próprios números (filtro de vendedor travado);
    - supervisora, diretoria e admin veem todos;
    - pcp vê só a seção Lotes do Resultado.
  - **Exportação:** cada gráfico tem o botão "Baixar dados (.xlsx)" com os números exibidos.
- **Bloqueios:** nenhum.

## Resultado observável

A Gabrielle abre os Painéis no fim de novembro e vê:
- **Execução:** 412 ações geradas, 371 concluídas (90%), 83% das ações de faixa alta no prazo;
- **Saúde da carteira:** clientes em queda caindo de 38 para 29 em 4 semanas;
- **Resultado:** 14 clientes reativados, R$ 186 mil de faturamento recuperado, 2 lotes C/D atingidos com 520 peças;
- **Motivos:** "Concorrente com rebate" em primeiro;
- **Prospecção:** 9 leads, 2 convertidos, 21 dias até o primeiro pedido.

## Limites e dependências

- **Inclui:**
  - tabelas `fotografia_carteira_diaria` e `resultado_reativacao`;
  - funções `fotografar_carteira`, `calcular_resultado`;
  - views de indicadores;
  - rota `/paineis` com as 5 seções, filtros e exportação;
  - menu e destino da diretoria;
  - conferência dos números com a Ângela.
- **Fora de escopo:**
  - indicadores de WhatsApp (fase 2);
  - envio automático de resumo (fase 2, Maestro);
  - metas por vendedor (o painel mostra os números; metas ficam para depois do 1º mês de linha de base).
- **Entradas e pré-condições:** SPECs 1-006 (sinais e ações), 1-007 (resultados), 1-009 (leads), 1-010 (ocorrências), 1-011 (lotes).
- **Saídas/artefatos:** migração SQL; tela; conferência dos indicadores.
- **Dependências e responsáveis:** Marco constrói no Skip e no Supabase, com orientação da consultora Kimberly; Ângela confere os números; Gabrielle aceita o painel.
- **Atores e permissões mínimas:** conforme "Visibilidade". As views usam `security_invoker = true` para herdar o RLS.
- **Superfícies/arquivos/configurações afetadas:** Supabase: tabelas, funções, views e chamada no fim de `rodar_rotina_comercial`; Skip: `/paineis`, menu e destino da diretoria.
- **Risco e plano B:** no início há pouco histórico para tendências → os gráficos de evolução mostram "Histórico disponível a partir de dd/mm" até haver 7 dias de fotografia.
- **Rollback ou reversão:** as tabelas são derivadas e as views podem ser removidas sem efeito na operação.

## Dados e integrações

Sem integração externa.

**`fotografia_carteira_diaria`:** `data` · `vendedor_id` · `situacao_comercial` · `clientes` int · `valor_em_risco` numeric · `acoes_abertas` int · `acoes_atrasadas` int; único (`data`,`vendedor_id`,`situacao_comercial`).

**`resultado_reativacao`:** `acao_id` (único) · `cliente_id` · `vendedor_id` · `data_acao` · `situacao_na_acao` · `media_ref_na_acao` · `media_recente_na_acao` · `faturado_45d` · `reativado` boolean · `faturado_60d` · `faturamento_recuperado` · `calculado_em`. A situação e as médias são capturadas no momento da conclusão: `registrar_resultado` grava a fotografia da métrica do cliente na própria ação, em `acoes.metricas_no_resultado` jsonb, acrescentado por esta SPEC.

**Indicadores (views):**

| Seção | Indicador | Regra |
|---|---|---|
| Execução | Ações geradas, concluídas e % concluídas | Ações criadas no período; concluídas entre elas |
| Execução | % de faixa alta no prazo | Faixa alta concluídas até `prazo` ÷ faixa alta com `prazo` no período |
| Execução | Ações por resultado | Contagem por `resultado_codigo` |
| Execução | Leads com primeiro contato no mesmo dia | `primeiro_contato` concluídas na data de criação ÷ total |
| Saúde | Clientes por situação ao longo do tempo | `fotografia_carteira_diaria` (linhas por semana) |
| Saúde | Valor em risco total | Soma do valor em risco dos sinais ativos |
| Saúde | Clientes em queda sem contato há 7+ dias | Mesma regra do alerta da SPEC-1-008 |
| Resultado | Clientes reativados | `resultado_reativacao.reativado` com `data_acao` no período |
| Resultado | Faturamento recuperado | Soma de `faturamento_recuperado` dos reativados |
| Resultado | Lotes atingidos e peças viabilizadas | Oportunidades que chegaram a `lote_atingido` no período; soma dos compromissos convertidos |
| Resultado | Ocorrências abertas, resolvidas e tempo médio de resolução | `ocorrencias` |
| Motivos | Ranking de motivos de perda e concorrentes citados | `acoes.motivo_perda_codigo` e `concorrente` (normalizado em maiúsculas) |
| Prospecção | Leads por origem; conversão por etapa; tempo médio até o primeiro pedido; perdidos por motivo | `leads` e `leads_etapas_historico` |

| Regra | Condição | Ação/resultado | Exceção | Fonte |
|---|---|---|---|---|
| RN-01 Período | Filtro | Opções: esta semana, semana passada, este mês, mês passado, últimos 90 dias, personalizado; padrão "este mês" | — | §9.11 |
| RN-02 Reativado | Ação `reativacao` concluída com situação `queda`/`inativo` ou sinal silencioso no momento | Avaliado aos 45 dias; antes disso, "em observação" | Ações concluídas com `nao_se_aplica` ficam fora | §8.6 |
| RN-03 Recuperado | Cliente reativado | `faturado_60d − 2 × media_recente_na_acao`; mínimo 0 | Avaliado aos 60 dias; antes, parcial com selo "parcial" | §8.6 |
| RN-04 Fotografia | Fim de `rodar_rotina_comercial` | Insere ou atualiza a fotografia do dia | — | §9.11 |
| RN-05 Consistência | Todo indicador | O número exibido é igual à consulta SQL documentada na view (sem cálculo no navegador) | — | qualidade |

## Telas

**`/paineis`:**
1. **Cabeçalho:** título, filtro de período, filtro de vendedor (travado para o vendedor) e "Dados atualizados até …".
2. **Linha de KPIs** (Montserrat 700): % ações concluídas · % alta no prazo · clientes reativados · faturamento recuperado (R$) · valor em risco atual (R$) · leads convertidos.
3. **Seções** em cartões, cada uma com até 3 gráficos:
   - **Execução:** barras de ações geradas × concluídas por semana; barras de resultados; ranking por vendedor (gestão).
   - **Saúde da carteira:** áreas empilhadas por situação ao longo do tempo (verde, âmbar, vermelho, cinza); número de valor em risco; lista dos 10 maiores valores em risco com link.
   - **Resultado:** cartões de reativados e recuperado; tabela de clientes reativados (cliente, vendedor, data da ação, recuperado); lotes atingidos; ocorrências.
   - **Motivos:** barras horizontais de motivos de perda; lista de concorrentes citados.
   - **Prospecção:** funil de conversão por etapa; leads por origem; tempo médio até o primeiro pedido.
4. **Paleta:** ardósia `#2C3E50` como série principal, teal `#86B0B6` e `#91CCD2` secundárias, vermelho `#ED1C24` só para crítico/atenção; eixos e rótulos em `#707980`.
5. **Celular:** seções empilhadas; gráficos com rolagem horizontal quando necessário.

| Cenário | Dado/condição | Resultado esperado | Caminho de erro/recuperação |
|---|---|---|---|
| Principal | Diretoria abre "este mês" | Todos os indicadores do período, todos os vendedores | — |
| Principal | Vendedor abre | Só os próprios números; filtro de vendedor travado | — |
| Limite | Menos de 7 dias de fotografia | Mensagem "Histórico disponível a partir de dd/mm" no gráfico de evolução | — |
| Limite | Ação de reativação concluída há 20 dias | Cliente "em observação" | — |
| Falha | PCP abre | Só a seção de Lotes | — |
| Falha | Erro de carregamento de uma seção | Mensagem na seção, demais seções seguem | "Tentar de novo" |

## Instruções de execução para o Ethos

1. **Ler antes de alterar:** `02-Escopo-Definitivo.md` §8.6, §9.11 e §14; SPECs 1-006 a 1-011; esta SPEC.
2. **Alterar somente:** tabelas, funções e views desta SPEC; `acoes.metricas_no_resultado` e a gravação em `registrar_resultado`; a chamada no fim de `rodar_rotina_comercial`; `/paineis`, menu e destino da diretoria.
3. **Não alterar:** regras de sinais, ações, leads, ocorrências e lotes.
4. **Executar nesta ordem:**
   1. Captura das métricas no resultado.
   2. Tabelas e funções.
   3. Views com testes.
   4. Tela por seção.
   5. Exportação.
   6. Conferência com a Ângela.
   7. Aceite da Gabrielle.
5. **Parar e pedir validação quando:** um indicador pedido pela diretoria não estiver na tabela de indicadores (emenda).
6. **Estado válido ao parar:** as seções já entregues mostram números iguais às consultas.

## Checklist de execução

- [ ] `acoes.metricas_no_resultado` gravado no registro de resultado
- [ ] `fotografia_carteira_diaria`, `resultado_reativacao`, funções e views
- [ ] `/paineis` com as 5 seções, filtros, KPIs, exportação e celular
- [ ] Menu e destino da diretoria → `/paineis`
- [ ] Conferência dos indicadores com a Ângela
- [ ] Aceite da Gabrielle
- [ ] Evidências salvas em `05_entregas/fase-1/SPEC-1-012/`

## Critérios de aceite

- [ ] **CA-1-58:** Com dados de teste, um cliente em queda com ação de reativação concluída que fatura ≥ 50% da média de referência em 45 dias aparece como reativado, e o faturamento recuperado é o da RN-03.
- [ ] **CA-1-59:** Cada indicador da tabela de indicadores exibido na tela é igual à consulta SQL da view correspondente, para o mesmo período e vendedor.
- [ ] **CA-1-60:** O vendedor vê só os próprios números; o PCP vê só a seção de Lotes; diretoria e supervisora veem tudo.
- [ ] **CA-1-61:** A fotografia diária é gravada a cada rotina comercial e alimenta o gráfico de evolução por situação.
- [ ] **CA-1-62:** A Ângela confere 5 indicadores do mês com os registros do sistema, e a Gabrielle aceita o painel como substituto do fechamento manual da carteira.

## TDD da SPEC

| Etapa | Prova | Comando/ação | Resultado esperado | Evidência |
|---|---|---|---|---|
| RED 1 | Função inexistente | `select calcular_resultado('2026-11-06')` | Erro "function does not exist" | `red.txt` |
| GREEN 1 | Reativação | Branch de teste: C001 da fixture (queda; média ref 10.000; recente 3.000) com ação concluída em 06/11; importar venda de R$ 9.000 em 20/11; `calcular_resultado('2026-12-21')` | `reativado = true` (9.000 ≥ 5.000); `faturamento_recuperado = 9.000 − 6.000 = 3.000` | `reativacao.txt` |
| GREEN 2 | Consistência | Para cada indicador, comparar a tela com `select` na view | Iguais | `consistencia.txt` + capturas |
| GREEN 3 | Visibilidade | Abrir como vendedor, pcp, supervisora e diretoria | Conforme o CA-1-60 | 4 capturas |
| GREEN 4 | Fotografia | Rodar a rotina em 3 dias de teste | 3 fotografias; gráfico com 3 pontos | `fotografia.txt` |
| GREEN 5 | Aceite | Conferência e aceite | Registro de aceite | `aceite.md` |
| REFACTOR/REGRESSÃO | Bordas | Período sem dados; cliente "em observação"; `nao_se_aplica` excluído; exportação de cada gráfico | Mensagens e números corretos | `regressao.txt` |

**Caminhos de erro obrigatórios:** período vazio, histórico insuficiente, reativação em observação, visibilidade por papel, falha de uma seção.  
**Evidência exigida:** arquivos citados em `05_entregas/fase-1/SPEC-1-012/`.

## Handoff e operação

- **Como demonstrar:** a Gabrielle abre os Painéis, filtra "mês passado" e um vendedor, e baixa os dados de um gráfico.
- **Como operar depois:**
  - A Ângela usa os Painéis no fechamento mensal, no lugar da consolidação manual.
  - A Gabrielle revisa semanalmente.
- **Como monitorar:** "Dados atualizados até" e fotografia diária.
- **Pendência conhecida:** nenhuma.

## Tasks vinculadas

| ID | Task | Dono | SPEC | Critério | Recorte da prova | Evidência esperada | Pré-condições | Status |
|---|---|---|---|---|---|---|---|---|
| 1.41 | Gravar métricas no resultado; criar `fotografia_carteira_diaria`, `resultado_reativacao`, funções e views de indicadores | Marco Carvalho | SPEC-1-012 | CA-1-58, CA-1-61 | RED 1 → GREEN 1, GREEN 4 | `reativacao.txt`, `fotografia.txt` | 1.22 e 1.24 concluídas | ☐ |
| 1.42 | Construir `/paineis` (5 seções, KPIs, filtros, exportação, celular) e mudar o destino da diretoria | Marco Carvalho | SPEC-1-012 | CA-1-59, CA-1-60 | GREEN 2, GREEN 3, REGRESSÃO | `consistencia.txt` + capturas | 1.41, 1.32, 1.35 e 1.38 concluídas | ☐ |
| 1.43 | Conferir 5 indicadores do mês e registrar o aceite do painel pela diretoria | Ângela Ferreira | SPEC-1-012 | CA-1-62 | GREEN 5 | `aceite.md` | 1.42 concluída | ☐ |

## Emendas

<!-- Append-only (D19): mudanças aprovadas depois da geração. A história não é reescrita. -->

| Data | Origem do sinal | Micro-spec/task | Motivo |
|---|---|---|---|
| | | | |
