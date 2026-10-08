# SPEC-1-003 — Métricas da carteira e situação comercial

**Fase:** 1  
**Status:** planejada  
**Dono:** Marco Carvalho (TI Platina) · **Consultoria:** Kimberly Prestes (Adapta)  
**Origem no escopo:** `02-Escopo-Definitivo.md` §7.2 (`metricas_cliente_mensal`, `metricas_cliente_atual`), §8.1 (métricas base), §8.2 (limites de queda, família e item-chave, situação comercial), §9.3 (Top clientes por UF), §10 (recálculo diário)  
**Degrau da solução:** recurso nativo da plataforma — funções SQL no PostgreSQL do Supabase e pg_cron; nenhum serviço de BI externo e nenhuma integração.

## Contexto e decisões fechadas

- **Estado atual:**
  - A coordenação calcula à mão, no fechamento do mês, a média dos últimos 6 meses dos 2 a 3 maiores clientes de cada estado (vídeo *Monitoramento da carteira*, 05:59–07:12; 1 a 2 dias por mês, estimado).
  - Não existe forma confiável de ver as famílias ou itens que o cliente deixou de comprar (05:19).
- **Estado desejado:**
  - Depois de cada importação de faturamento (SPEC-1-002) e todo dia às 05:15, a Central Sly recalcula as métricas de todos os clientes:
    - médias, variação e dias sem compra;
    - intervalo médio entre compras e ticket médio;
    - famílias e itens-chave abandonados;
    - situação comercial;
    - ranking por UF.
  - As telas das SPECs 1-004 e 1-005 apenas leem esses resultados.
- **Decisões já fechadas:**
  - **Data de referência (D):** data atual no fuso America/Sao_Paulo, ou a data passada como parâmetro (testes).
  - **Valores e peças líquidos:**
    - venda − devolução; `cancelada` é ignorada;
    - **notas** = `numero_nota` distintos com `tipo_movimento = 'venda'`;
    - **datas de compra** = datas distintas com venda.
  - **Média de referência (6m):** soma dos 6 meses-calendário fechados que terminam no mês anterior ao mês de (D − 60 dias), dividida por 6. Meses sem compra contam como zero. Exemplo: D = 06/11/2026 → D − 60 = 07/09/2026 → março a agosto de 2026.
  - **Média recente:** soma das datas em (D − 60, D] dividida por 2.
  - **Média dos últimos 6 meses fechados:** soma dos 6 meses-calendário completos anteriores ao mês de D, dividida por 6. É o número que a coordenação calcula hoje e alimenta o **Top clientes por UF**. A média de referência é usada só na variação.
  - **Janela de 12 meses:** datas em (D − 365, D].
  - **Situação comercial provisória:** só por métricas (RN-08). Quando a SPEC-1-006 (motor de sinais) for entregue, ela passa a definir a situação (§8.2), sem mudar a coluna nem as telas.
  - Limites guardados em `parametros`; a tela de edição é da SPEC-1-008.
  - **Sem alertas nesta fase:** falhas aparecem no histórico da tela Administração › Importações.
- **Bloqueios:** nenhum.

## Resultado observável

Logo depois da importação do faturamento, cada cliente tem:

- média de referência e média recente (R$ e peças), variação, dias sem compra;
- intervalo médio entre compras, ticket médio;
- famílias e itens-chave abandonados;
- situação comercial (Ativo, Em atenção, Em queda, Inativo).

O **Top clientes por UF** reproduz a conta manual da coordenação. A fixture abaixo produz exatamente os números esperados.

## Limites e dependências

- **Inclui:**
  - tabelas `metricas_cliente_mensal`, `metricas_cliente_atual`, `metricas_cliente_familia` e `metricas_cliente_item_chave`;
  - função `recalcular_metricas(p_ref date)`;
  - views `vw_media_movel_cliente` e `vw_top_clientes_uf`;
  - parâmetros iniciais;
  - job pg_cron;
  - chamada automática ao confirmar uma importação L3;
  - cartão "Recálculo de métricas" na tela Importações.
- **Fora de escopo:**
  - sinais, ações, prioridade e alertas (SPECs 1-006 a 1-008);
  - painéis de gestão (SPEC-1-012);
  - qualquer integração.
- **Entradas e pré-condições:** SPEC-1-002 com a task 1.06 concluída (tabelas de origem e `confirmar_importacao`); funções de papel da SPEC-1-001.
- **Saídas/artefatos:** migração SQL; resultado da fixture; planilha de conferência do Top por UF.
- **Dependências e responsáveis:** Marco constrói no Skip e no Supabase, com orientação da consultora Kimberly; Ângela fornece a planilha do último cálculo manual por UF e confere.
- **Atores e permissões mínimas:**
  - Leitura das tabelas e views de métricas pela mesma regra de `clientes`: vendedor só a própria carteira; supervisora, diretoria e admin, todas.
  - Escrita somente por `recalcular_metricas` (`security definer`), executável por `admin` pela tela e pelo job.
- **Superfícies/arquivos/configurações afetadas:**
  - Supabase: tabelas, função, views, parâmetros e job `recalcular-metricas`;
  - alteração em `confirmar_importacao` (SPEC-1-002) para chamar `recalcular_metricas()` ao final de toda importação L3 confirmada ou desfeita;
  - Skip: cartão "Recálculo de métricas" na rota `/admin/importacoes` (última execução, situação, duração, botão "Recalcular agora").
- **Risco e plano B:**
  - Recálculo acima de 60 s: processar por blocos de 200 clientes dentro da mesma função.
  - Se ainda assim falhar, as telas mantêm o último cálculo, com a data.
- **Rollback ou reversão:** as tabelas são derivadas (apagar e recalcular é seguro). A migração tem script de reversão; a chamada em `confirmar_importacao` é removível sem afetar dados de origem.

## Dados e integrações

Esta SPEC não tem integração externa. Fonte de verdade: `faturamento_itens`, `clientes` e `itens` (SPEC-1-002).

**Parâmetros inseridos** (tabela `parametros`):

| Chave | Valor | Uso |
|---|---|---|
| `metricas_dias_recentes` | 60 | janela recente |
| `metricas_meses_referencia` | 6 | janela de referência |
| `elegibilidade_media_minima` | 1500 | R$/mês de referência mínimo para regras de consumo |
| `elegibilidade_faturamentos_minimos` | 4 | notas mínimas em 12 meses |
| `mercados_excluidos_consumo` | `["industria","exportacao"]` | fora das regras de queda |
| `queda_atencao` | −0,30 | variação ≤ −30% |
| `queda_critica` | −0,50 | variação < −50% |
| `dias_inativo` | 120 | inativo |
| `familia_meses_minimos` | 3 | família ativa na referência |
| `familia_dias_sem_compra` | 60 | família abandonada |
| `item_chave_percentual` | 0,05 | item-chave |
| `item_chave_dias_sem_compra` | 90 | item-chave abandonado |

**Tabelas derivadas:**

| Tabela | Campos |
|---|---|
| `metricas_cliente_mensal` | `cliente_id`, `mes` (1º dia), `valor`, `pecas`, `notas`, `familias` text[] — uma linha para **cada um dos 24 meses** até o mês de D, inclusive, para todo cliente com faturamento em 24 meses (meses sem compra = zero); único (`cliente_id`,`mes`) |
| `metricas_cliente_atual` | `cliente_id` único · `data_referencia` · `media_ref_valor`, `media_ref_pecas` · `media_recente_valor`, `media_recente_pecas` · `variacao` numeric(6,4) · `media_6m_fechados_valor`, `media_6m_fechados_pecas` · `ultima_compra` · `dias_sem_compra` · `intervalo_medio_dias` numeric(6,1) · `ticket_medio` numeric(14,2) · `valor_12m` · `notas_12m` · `elegivel_consumo` · `familias_ativas` text[] · `familias_abandonadas` text[] · `situacao_comercial` · `calculado_em` |
| `metricas_cliente_familia` | `cliente_id`, `familia`, `meses_com_compra_ref` (0–6), `ultima_compra`, `valor_12m`, `participacao_12m`, `situacao` (`ativa`,`abandonada`,`sem_historico`) |
| `metricas_cliente_item_chave` | `cliente_id`, `item_id`, `valor_12m`, `participacao_12m`, `ultima_compra`, `dias_sem_compra`, `abandonado` — somente itens com participação ≥ 5% |

**Views** (com `security_invoker = true`):
- `vw_media_movel_cliente`: por cliente e mês dos últimos 12 meses fechados, `media_movel_6m_valor` = média do mês e dos 5 anteriores.
- `vw_top_clientes_uf`: por UF, os 3 maiores `media_6m_fechados_valor` (desempate por `valor_12m` e depois `razao_social`), com `posicao`, valores em R$ e peças.

**Job:** `recalcular-metricas`, pg_cron `15 8 * * *` UTC (05:15 BRT), executa `select recalcular_metricas();`. Mantém dias sem compra e situação corretos mesmo nos dias sem importação.

| Regra de negócio | Condição | Ação/resultado | Exceção | Fonte |
|---|---|---|---|---|
| RN-01 | Janela de referência | Meses de `date_trunc('month', D − 60) − 6 meses` a `date_trunc('month', D − 60) − 1 mês`; soma ÷ 6 | — | §8.1 |
| RN-02 | Média recente | Soma em (D − 60, D] ÷ 2 | — | §8.1 |
| RN-03 | Variação | `media_recente_valor ÷ media_ref_valor − 1`, 4 casas | `media_ref_valor = 0` → null | §8.1 |
| RN-04 | Dias sem compra e intervalo | `dias_sem_compra = D − última data de venda`; `intervalo_medio_dias = (última − primeira data de venda na janela de 12 meses) ÷ (nº de datas − 1)` | Menos de 2 datas → null | §8.1 |
| RN-05 | Ticket médio | Valor líquido na janela de 12 meses ÷ notas de venda na mesma janela | 0 notas → null | §8.1 |
| RN-06 | Elegibilidade | `media_ref_valor ≥ 1500` e `notas_12m ≥ 4` e mercado fora de `mercados_excluidos_consumo` | — | §8.1 |
| RN-07 | Família | `abandonada` se comprada em ≥ 3 dos 6 meses de referência e sem compra em (D − 60, D]; `ativa` se comprada nos últimos 12 meses e não abandonada; demais → `sem_historico` (não exibida) | — | §8.2 |
| RN-08 | Situação provisória (ordem) | 1. `dias_sem_compra ≥ 120` ou nunca comprou em 24 meses → `inativo`; 2. elegível e `variacao < −0,50` → `queda`; 3. elegível e `variacao ≤ −0,30` → `atencao`; 4. demais → `ativo` | — | §8.2 |
| RN-09 | Item-chave | Participação ≥ 5% do valor líquido em 12 meses; `abandonado` quando `dias_sem_compra > 90` | — | §8.2 |
| RN-10 | Gravação | Uma transação para todos os clientes; atualiza `clientes.situacao_comercial`; registra `integracao_execucoes` com `conjunto = 'metricas'`, duração e situação | Erro → transação desfeita, métricas anteriores mantidas, execução `falhou` com a mensagem, exibida no cartão "Recálculo de métricas" | §10 |

## Fluxo e regras

1. **Gatilhos:**
   - confirmação ou desfazer de importação L3;
   - job das 05:15;
   - botão "Recalcular agora" (admin).
2. `recalcular_metricas(D)`:
   1. lê os parâmetros;
   2. monta os agregados mensais de 24 meses;
   3. calcula as métricas atuais, famílias e itens-chave;
   4. aplica RN-08;
   5. substitui as tabelas derivadas;
   6. atualiza `clientes.situacao_comercial`;
   7. registra a execução.
3. As telas (SPECs 1-004 e 1-005) leem as tabelas e views.

**Fixture de prova.** D = **06/11/2026**. Itens: `I1` = `PS 4938 STD` (pistao_leve) e `I2` = `PS 864 S STD` (pistao_pesada). Uma nota por data.

| Cliente | UF / mercado | Faturamento |
|---|---|---|
| C001 Tonini | RS / reposicao_direta | Dia 15 de nov/2025 a ago/2026 (10 notas): I1 60 un R$ 6.000 + I2 40 un R$ 4.000 na mesma nota. Dias 15/09 e 15/10/2026: I1 30 un R$ 3.000 |
| C002 Cooper | SC / reposicao_direta | Dia 10 de nov/2025 a out/2026 (12 notas): I1 50 un R$ 5.000. Devolução em 20/10/2026: I1 10 un R$ 1.000. Nota cancelada em 30/10/2026: I1 R$ 9.999 |
| C003 Serraf | PR / reposicao_direta | Dia 20 de nov/2025 a jun/2026 (8 notas): I1 80 un R$ 8.000 |
| C004 Mercantil | SP / reposicao_direta | Dia 05 de nov/2025 a ago/2026 (10 notas): I1 10 un R$ 1.000. Dias 25/09 e 25/10/2026: I1 3 un R$ 300 |
| C005 Compressores | MG / industria | Dia 20 de nov/2025 a ago/2026 (10 notas): I1 200 un R$ 20.000. Dias 20/09 e 20/10/2026: I1 20 un R$ 2.000 |
| C006 Rede União | RS / reposicao_direta | Dia 12 de nov/2025 a ago/2026 (10 notas): I1 80 un R$ 8.000. Dias 12/09 e 12/10/2026: I1 48 un R$ 4.800 |

**Resultados esperados (referência oficial do teste):**

| Cliente | media_ref_valor | media_recente_valor | variacao | dias_sem_compra | intervalo_medio_dias | notas_12m | ticket_medio | media_6m_fechados_valor | situacao_comercial |
|---|---|---|---|---|---|---|---|---|---|
| C001 | 10000.00 | 3000.00 | −0.7000 | 22 | 30.4 | 12 | 8833.33 | 7666.67 | queda |
| C002 | 5000.00 | 4500.00 | −0.1000 | 27 | 30.4 | 12 | 4916.67 | 4833.33 | ativo |
| C003 | 5333.33 | 0.00 | −1.0000 | 139 | 30.3 | 8 | 8000.00 | 2666.67 | inativo |
| C004 | 1000.00 | 300.00 | −0.7000 | 12 | 32.4 | 11 | 872.73 | 766.67 | ativo |
| C005 | 20000.00 | 2000.00 | −0.9000 | 17 | 30.4 | 12 | 17000.00 | 14000.00 | ativo |
| C006 | 8000.00 | 4800.00 | −0.4000 | 25 | 30.4 | 12 | 7466.67 | 6933.33 | atencao |

Pontos de atenção que a fixture prova:
- **C002:** a devolução de 20/10 subtrai (recente = (5.000 + 5.000 − 1.000) ÷ 2) e a nota cancelada é ignorada.
- **C003:** passa a inativo (139 dias), mesmo com variação −100%.
- **C004:** a nota de 05/11/2025 fica **fora** da janela de 12 meses, que começa em 07/11/2025. Por isso:
  - notas_12m = 11;
  - ticket = 9.600 ÷ 11;
  - intervalo = (25/10/2026 − 05/12/2025) ÷ 10 = 324 ÷ 10.
  - O cliente não é elegível (média < R$ 1.500).
- **C005:** mercado indústria, excluído das regras de queda.
- **C006:** variação de −40%, portanto "Em atenção".

**Famílias e itens-chave de C001:**
- `pistao_pesada` abandonada: comprada nos 6 de 6 meses de referência, sem compra desde 15/08/2026.
- `pistao_leve` ativa.
- I2 é item-chave: 40.000 ÷ 106.000 = 0,3774. Está com 83 dias sem compra, portanto `abandonado = false`.

**Top por UF:**
- RS: 1º C001 (7.666,67), 2º C006 (6.933,33);
- SC: C002; PR: C003; SP: C004; MG: C005.

| Cenário | Dado/condição | Resultado esperado | Caminho de erro/recuperação |
|---|---|---|---|
| Principal | Fixture com D = 06/11/2026 | Tabela de resultados esperados | — |
| Limite | Devolução e nota cancelada (C002) | Devolução subtrai; cancelada ignorada | — |
| Limite | Nota no limite da janela de 12 meses (C004) | Fora da janela | — |
| Limite | Cliente sem compra em 24 meses | `inativo`, médias 0, `dias_sem_compra` null | — |
| Limite | Média de referência zero | `variacao` null; `ativo`, salvo inatividade | — |
| Falha | Erro durante o recálculo | Transação desfeita; métricas anteriores preservadas; cartão vermelho com a mensagem | Corrigir e "Recalcular agora" |

## Instruções de execução para o Ethos

1. **Ler antes de alterar:** `02-Escopo-Definitivo.md` §8.1 e §8.2; SPEC-1-002 (tabelas de origem e `confirmar_importacao`); esta SPEC, principalmente RN-01 a RN-10 e a tabela de resultados esperados.
2. **Alterar somente:** migração das tabelas derivadas, função, views, parâmetros e job; a chamada em `confirmar_importacao`; o cartão "Recálculo de métricas".
3. **Não alterar:** tabelas de origem, layouts e telas de consulta.
4. **Executar nesta ordem:**
   1. Parâmetros.
   2. Tabelas.
   3. Função, testada com a fixture num branch de teste do Supabase.
   4. Views.
   5. Job e chamada pós-importação.
   6. Cartão na tela.
   7. Base real.
   8. Conferência do Top por UF.
5. **Parar e pedir validação quando:**
   - um valor da fixture divergir após 2 tentativas de correção;
   - a conferência do Top por UF divergir em mais de R$ 1,00 por cliente (pode indicar outra regra de média em uso pela coordenação).
6. **Estado válido ao parar:** métricas coerentes com a última execução bem-sucedida.

## Checklist de execução

- [ ] Parâmetros inseridos
- [ ] Tabelas derivadas, função, views e job criados
- [ ] Fixture produz a tabela de resultados, as famílias de C001 e o Top por UF
- [ ] Recálculo disparado ao confirmar e ao desfazer L3, e às 05:15
- [ ] Cartão "Recálculo de métricas" com "Recalcular agora" para o admin
- [ ] Base real recalculada em menos de 60 s
- [ ] Top por UF conferido com o último cálculo manual da coordenação
- [ ] Evidências salvas em `05_entregas/fase-1/SPEC-1-003/`

## Critérios de aceite

- [ ] **CA-1-12:** Com a fixture e D = 06/11/2026, `metricas_cliente_atual` reproduz a tabela de resultados esperados (valores com 2 casas, variação com 4, intervalo com 1); C001 tem `pistao_pesada` em `familias_abandonadas`; I2 é item-chave com `abandonado = false`.
- [ ] **CA-1-13:** Para a fixture, `vw_top_clientes_uf` devolve RS = C001 e C006 nessa ordem. Na base real, a média dos últimos 6 meses fechados dos 3 maiores clientes de cada UF confere com o último cálculo manual da coordenação (diferença ≤ R$ 1,00 por cliente).
- [ ] **CA-1-14:** Confirmar uma importação L3 atualiza `calculado_em` de todos os clientes em até 60 s, sem ação manual.
- [ ] **CA-1-15:** Como vendedor, `select count(*) from metricas_cliente_atual` devolve somente clientes da própria carteira.

## TDD da SPEC

| Etapa | Prova | Comando/ação | Resultado esperado | Evidência |
|---|---|---|---|---|
| RED 1 | Função inexistente | `select recalcular_metricas('2026-11-06')` | Erro "function does not exist" | `red.txt` |
| GREEN 1 | Fixture | Importar a fixture (L1, L2 e L3 nos layouts da SPEC-1-002) num branch de teste; `select recalcular_metricas('2026-11-06')`; `select c.codigo_focco, m.media_ref_valor, m.media_recente_valor, m.variacao, m.dias_sem_compra, m.intervalo_medio_dias, m.notas_12m, m.ticket_medio, m.media_6m_fechados_valor, m.situacao_comercial from metricas_cliente_atual m join clientes c on c.id = m.cliente_id order by 1` | Igual à tabela oficial | `fixture.txt` |
| GREEN 2 | Famílias e item-chave | Consultar `metricas_cliente_familia` e `metricas_cliente_item_chave` de C001 | `pistao_pesada` abandonada; I2 com participação 0.3774, 83 dias, `abandonado = false` | `familias.txt` |
| GREEN 3 | Top por UF | `select uf, posicao, codigo_focco, media_6m_fechados_valor from vw_top_clientes_uf order by uf, posicao` | Conforme o esperado | `top-uf.txt` |
| GREEN 4 | Disparo automático | Confirmar uma importação L3 de 1 nota; consultar `max(calculado_em)` | Atualizado em ≤ 60 s | `disparo.txt` |
| GREEN 5 | Base real | Comparar `vw_top_clientes_uf` com a planilha manual da coordenação do último mês fechado | Diferença ≤ R$ 1,00 | `conferencia-top-uf.xlsx` |
| REFACTOR/REGRESSÃO | RLS e falha | Como vendedor, contar `metricas_cliente_atual`; no branch de teste, gravar valor inválido em `queda_critica` e chamar a função | Somente a carteira; transação desfeita e execução `falhou` visível no cartão | `regressao.txt` + captura |

**Caminhos de erro obrigatórios:** devolução, nota cancelada, limite da janela de 12 meses, cliente sem compras, média de referência zero, mercado excluído, cliente não elegível, falha no recálculo.  
**Evidência exigida:** arquivos citados em `05_entregas/fase-1/SPEC-1-003/`.

## Handoff e operação

- **Como demonstrar:** Ângela abre a planilha do último fechamento ao lado do Top por UF e mostra os números iguais. Marco mostra C001 da fixture com a família abandonada.
- **Como operar depois:**
  - O recálculo é automático depois de cada importação de faturamento e às 05:15.
  - Até a tela Parâmetros (SPEC-1-008), uma mudança de limite é feita por Marco via SQL a pedido da Ângela e fica registrada em `auditoria`.
- **Como monitorar:** cartão "Recálculo de métricas" na tela Importações.
- **Pendência conhecida:** nenhuma.

## Tasks vinculadas

| ID | Task | Dono | SPEC | Critério | Recorte da prova | Evidência esperada | Pré-condições | Status |
|---|---|---|---|---|---|---|---|---|
| 1.10 | Criar parâmetros, tabelas derivadas, `recalcular_metricas`, views, job, chamada pós-L3 e cartão "Recálculo de métricas" | Marco Carvalho | SPEC-1-003 | CA-1-14, CA-1-15 | RED 1; GREEN 4; REGRESSÃO | `red.txt`, `disparo.txt`, `regressao.txt` | 1.06 concluída | ☐ |
| 1.11 | Provar a função com a fixture (métricas, famílias, itens-chave e Top por UF) | Marco Carvalho | SPEC-1-003 | CA-1-12, CA-1-13 (parte fixture) | GREEN 1, GREEN 2, GREEN 3 | `fixture.txt`, `familias.txt`, `top-uf.txt` | 1.10 concluída | ☐ |
| 1.12 | Conferir o Top clientes por UF da base real com o último cálculo manual da coordenação | Ângela Ferreira | SPEC-1-003 | CA-1-13 (parte base real) | GREEN 5 | `conferencia-top-uf.xlsx` | 1.09 e 1.11 concluídas | ☐ |

## Emendas

<!-- Append-only (D19): mudanças aprovadas depois da geração. A história não é reescrita. -->

| Data | Origem do sinal | Micro-spec/task | Motivo |
|---|---|---|---|
| | | | |
