# SPEC-1-006 — Motor de sinais de reativação e geração de ações

**Fase:** 1  
**Status:** planejada  
**Dono:** Marco Carvalho (TI Platina) · **Consultoria:** Kimberly Prestes (Adapta)  
**Origem no escopo:** `02-Escopo-Definitivo.md` §7.3 (`sinais`, `acoes`, `resultados_tipo`, `motivos_perda`), §8.2 (sinais e situação comercial), §8.3 (geração de ações e prioridade), §10 (rotinas; nota da fase 1), D2, D14  
**Degrau da solução:** recurso nativo da plataforma — funções SQL e pg_cron no Supabase, reaproveitando as métricas da SPEC-1-003; sem IA e sem integração.

## Contexto e decisões fechadas

- **Estado atual:**
  - Ninguém é avisado quando um cliente reduz compras, passa do prazo de recompra ou para de comprar uma família (Kickoff; vídeo *Monitoramento da carteira*, 05:19).
  - Depois da SPEC-1-003, as métricas existem, mas não viram trabalho para ninguém.
- **Estado desejado:**
  - Depois de cada importação de faturamento (e às 09:30 como garantia), a Central Sly compara a carteira inteira com as regras, abre e encerra **sinais** e gera **ações** priorizadas para o vendedor responsável.
  - A situação comercial do cliente passa a ser definida pelos sinais.
- **Decisões já fechadas:**
  - **Ordem de execução:** `recalcular_metricas()` → `motor_sinais()` → `gerar_acoes()`, em sequência, pela função `rodar_rotina_comercial(D)`.
  - **Gatilhos da rotina:**
    - fim de `confirmar_importacao` de L3 (substitui a chamada direta a `recalcular_metricas` da SPEC-1-003);
    - fim de `confirmar_importacao` de L4 (somente `motor_sinais` e `gerar_acoes`, para os sinais de pendência);
    - job **09:30 BRT** dos dias úteis, somente se a rotina ainda não rodou no dia;
    - o job de métricas das 05:15 continua só com `recalcular_metricas`.
  - **Uma ação de reativação por cliente:** todos os sinais **de consumo** ativos do cliente (queda, recompra vencida, família abandonada, item-chave abandonado, silencioso, inativo) se juntam numa única ação de reativação. O motivo lista todos; o valor em risco é o maior entre eles; o peso é o maior entre eles. Isso evita 3 ações para o mesmo cliente no mesmo dia.
  - **Sinal de pendência antiga** gera **uma ação por pendência**, do tipo `pendencia`.
  - **Cliente inativo:** só o sinal `inativo` é aberto; os demais sinais de consumo ficam suprimidos para não duplicar.
  - **Situação comercial** (substitui a regra provisória RN-08 da SPEC-1-003), na ordem:
    1. `inativo` se `dias_sem_compra ≥ 120` ou sem compra em 24 meses;
    2. `queda` se há sinal crítico de queda, recompra ou silencioso, ou 2 ou mais sinais de consumo ativos;
    3. `atencao` se há exatamente 1 sinal de consumo de severidade atenção;
    4. `ativo` nos demais casos.
    - Sinais de pendência não mudam a situação.
  - **Sinal de lote C/D:** é da SPEC-1-011, que reutiliza este motor.
  - **Tabelas de ações e listas fixas** (`acoes`, `resultados_tipo`, `motivos_perda`) são criadas nesta SPEC; a tela e o registro de resultado são da SPEC-1-007.
- **Bloqueios:** nenhum.

## Resultado observável

Logo depois da importação do faturamento do dia:

- cada vendedor tem ações abertas para os clientes que caíram, passaram do prazo de recompra, abandonaram uma família, estão silenciosos ou inativos, e para pendências abertas há mais de 30 dias;
- cada ação tem motivo com números e pontuação de prioridade;
- a coluna "Sinais ativos" aparece na Carteira;
- a situação comercial de cada cliente reflete os sinais.

A Ângela confere 10 sinais reais e todos estão corretos.

## Limites e dependências

- **Inclui:**
  - tabelas `sinais`, `acoes`, `resultados_tipo`, `motivos_perda` com listas iniciais;
  - parâmetros do motor;
  - funções `motor_sinais`, `gerar_acoes`, `rodar_rotina_comercial`;
  - ajuste dos gatilhos de `confirmar_importacao`;
  - job das 09:30;
  - coluna "Sinais ativos" na Carteira (`vw_carteira` + tela da SPEC-1-004).
- **Fora de escopo:**
  - tela Meu dia e registro de resultado (SPEC-1-007);
  - alertas de estagnação (SPEC-1-008);
  - sinal de lote C/D (SPEC-1-011);
  - ações de prospecção e pós-venda (SPECs 1-009 e 1-010, que reutilizam `acoes`);
  - qualquer IA ou integração.
- **Entradas e pré-condições:** SPEC-1-003 (tasks 1.10, 1.11), SPEC-1-005 (task 1.16, tabela `interacoes`), SPEC-1-002 (`pendencias`, `parametros`, `feriados`).
- **Saídas/artefatos:** migração SQL; fixture provada; conferência de 10 sinais reais.
- **Dependências e responsáveis:** Marco constrói no Skip e no Supabase, com orientação da consultora Kimberly; Ângela escolhe e confere 10 sinais.
- **Atores e permissões mínimas:**
  - `sinais` e `acoes`: leitura pela regra de `clientes` (vendedor só a própria carteira, ou ações em que é o responsável; gestão tudo).
  - Escrita nesta SPEC somente pelas funções (`security definer`).
  - `resultados_tipo` e `motivos_perda`: leitura por qualquer papel ativo; escrita pelo admin (tela na SPEC-1-008).
- **Superfícies/arquivos/configurações afetadas:**
  - Supabase: tabelas, funções, parâmetros e job `rotina-comercial-0930` (`30 12 * * 1-5` UTC);
  - alteração em `confirmar_importacao` (chamadas);
  - `vw_carteira` (nova coluna `sinais_ativos` text[] e `qtd_sinais` int);
  - Skip: coluna e filtro "Sinal" na Carteira.
- **Risco e plano B:** se o volume de ações sobrecarregar os vendedores na primeira semana, a Ângela ajusta os limites pela tela Parâmetros (SPEC-1-008) ou o limite diário (`acoes_limite_diario`).
- **Rollback ou reversão:**
  - Desligar o job e retirar as chamadas em `confirmar_importacao` interrompe a geração sem apagar dados.
  - A situação comercial volta à regra provisória ao reverter a função.
  - A migração tem script de reversão.

## Dados e integrações

Sem integração externa. Fonte de verdade: `metricas_cliente_atual`, `metricas_cliente_familia`, `metricas_cliente_item_chave`, `faturamento_itens`, `pendencias`, `interacoes`, `clientes`, `parametros`, `feriados`.

**Tabela `sinais`** (RLS de leitura igual a `clientes`):
- `cliente_id` · `tipo` check (`queda_consumo`,`recompra_vencida`,`familia_abandonada`,`item_chave_abandonado`,`cliente_silencioso`,`cliente_inativo`,`pendencia_antiga`,`lote_cd`) · `chave` text (família, `item_id` ou `pendencia_id`; vazio quando não se aplica) · `grupo` (`consumo`,`pendencia`,`lote`) · `severidade` (`atencao`,`critica`) · `valor_em_risco` numeric(14,2) · `peso` numeric(3,2) · `evidencia` text · `detectado_em`, `atualizado_em` · `situacao` (`ativo`,`tratado`,`encerrado`) · `encerrado_em` · `encerrado_motivo` (`condicao_resolvida`,`resultado_registrado`).
- Índice único parcial (`cliente_id`,`tipo`,`chave`) `where situacao = 'ativo'`.

**Tabela `acoes`** (RLS de leitura: `vendedor_id = perfil_atual_id()` ou gestão):
- `cliente_id` (ou `lead_id`, acrescentado pela SPEC-1-009) · `vendedor_id` FK perfis · `tipo` check (`reativacao`,`pendencia`,`retorno`,`compromisso`,`primeiro_contato`,`follow_up`,`lote_cd`,`pos_venda`,`prospeccao`,`manual`) · `sinais_ids` uuid[] · `titulo` · `motivo` (texto com números) · `valor_em_risco` · `peso` · `pontuacao` numeric(14,2) · `faixa` (`alta`,`normal`) · `data_prevista` date (null quando na fila) · `na_fila` boolean · `prazo` date · `situacao` (`aberta`,`concluida`,`cancelada`) · `resultado_codigo` FK `resultados_tipo` · `observacao` · `valor_pedido` · `data_retorno` · `hora` time (compromissos) · `tipo_compromisso` (`ligacao`,`reuniao_online`,`visita`) · `assunto` · `quantidade` · `motivo_perda_codigo` · `concorrente` · `origem` (`motor`,`manual`,`ia`) · `acao_origem_id` (para retornos) · `concluida_em` · `concluida_por`.
- Índices (`vendedor_id`,`situacao`,`data_prevista`) e (`cliente_id`,`situacao`).

**`resultados_tipo` (carga inicial; regras usadas pela SPEC-1-007):**

| codigo | descrição | exige | encerra sinal | cria retorno |
|---|---|---|---|---|
| `pedido_gerado` | Pedido gerado | valor aproximado | sim | não |
| `vai_comprar` | Cliente vai comprar | data prevista; quantidade em ação de lote | não | sim, na data |
| `retornar` | Retornar em outra data | data | não | sim, na data |
| `agendado` | Reunião/visita agendada | data, hora, tipo e assunto | não | sim, compromisso na data e hora |
| `estoque_alto` | Cliente com estoque alto | data para retomar | sim | sim, na data |
| `concorrente` | Comprando de concorrente | motivo de perda; concorrente | sim | não |
| `problema` | Problema de atendimento ou qualidade | descrição (abre ocorrência — SPEC-1-010) | sim | não |
| `sem_contato` | Sem contato | nova tentativa (data) | não | sim, na data |
| `pendencia_liberada` | Pendência liberada / combinada | — (só em ação `pendencia`) | sim | não |
| `nao_se_aplica` | Não se aplica | justificativa (≥ 10 caracteres) | sim | não |

**`motivos_perda` (carga inicial):** `preco` Preço · `prazo_entrega` Prazo de entrega · `falta_produto` Falta de produto · `concorrente_rebate` Concorrente com rebate/plano de negócio · `concorrente_importado` Concorrente importado · `estoque_alto` Estoque alto no cliente · `qualidade` Qualidade · `credito` Crédito · `outro` Outro.

**Parâmetros inseridos:**

| Chave | Valor |
|---|---|
| `recompra_fator` / `recompra_dias_extra` / `recompra_fator_critico` | 1,3 / 10 / 2,0 |
| `silencioso_dias` | 45 |
| `pendencia_antiga_dias` | 30 |
| `preco_referencia_dias` | 90 |
| `peso_queda_critica` / `peso_silencioso` / `peso_recompra` / `peso_lote_cd` / `peso_queda_atencao` / `peso_abandono` / `peso_pendencia_antiga` / `peso_inativo` | 1,0 / 0,9 / 0,9 / 0,8 / 0,8 / 0,7 / 0,6 / 0,5 |
| `fator_atraso_por_dia` / `fator_atraso_maximo` | 0,1 / 2,0 |
| `faixa_alta_percentual` | 0,30 |
| `acoes_limite_diario` | 15 |
| `sla_dias_uteis_alta` / `sla_dias_uteis_normal` | 2 / 5 |
| `cooldown_dias` | 30 |

**Regras de negócio**

| Regra | Condição | Ação/resultado | Exceção | Fonte |
|---|---|---|---|---|
| RN-01 Queda | Elegível (RN-06 SPEC-1-003) e `variacao ≤ −0,30` | Sinal `queda_consumo`; crítico se `< −0,50`; valor = `media_ref_valor − media_recente_valor`; evidência "Comprou R$ {recente×2} nos últimos 60 dias; média de R$ {ref}/mês ({var}%)" | — | §8.2 |
| RN-02 Recompra | Elegível e `dias_sem_compra > max(intervalo × 1,3; intervalo + 10)` | `recompra_vencida`; crítico se `> 2 × intervalo`; valor = `media_ref_valor`; evidência "Compra a cada {intervalo} dias; já são {dias} dias sem pedido" | `intervalo` null → não avalia | §8.2 |
| RN-03 Família | `metricas_cliente_familia.situacao = 'abandonada'` | `familia_abandonada` (chave = família), atenção; valor = média mensal da família na referência | — | §8.2 |
| RN-04 Item-chave | `metricas_cliente_item_chave.abandonado` | `item_chave_abandonado` (chave = item), atenção; valor = valor 12m do item ÷ 12 | — | §8.2 |
| RN-05 Silencioso | `dias_sem_compra ≥ 45` e nenhuma interação não anulada nos últimos 45 dias | `cliente_silencioso`, crítico; valor = `media_ref_valor` | Não exige elegibilidade, mas exige `media_ref_valor > 0` | §8.2 |
| RN-06 Inativo | `dias_sem_compra ≥ 120` | `cliente_inativo`, crítico; valor = `media_ref_valor` (ou média dos últimos 12 meses com compra, se a de referência for 0); suprime RN-01 a RN-05 | Cliente nunca comprou em 24 meses → sem sinal | §8.2 |
| RN-07 Pendência antiga | Pendência `aberta` há mais de 30 dias | `pendencia_antiga` (chave = pendência), atenção; valor = quantidade × preço de referência (RN-08); evidência "{qtd} un de {item} pendentes há {dias} dias (pedido {pedido})" | — | §8.2 |
| RN-08 Preço de referência | — | Último `valor_unitario` de venda do item para o cliente; senão, média ponderada do item em todas as vendas dos últimos 90 dias; senão, 0 | — | §8.2 |
| RN-09 Mercados | `mercado in ('industria','exportacao')` | Não avalia RN-01 a RN-05; avalia RN-06 e RN-07 | — | §8.1 |
| RN-10 Encerramento | Condição deixou de existir | `situacao = 'encerrado'`, `encerrado_motivo = 'condicao_resolvida'`; a ação aberta vinculada só com sinais encerrados é cancelada com observação "Condição resolvida antes do contato" | — | §8.2 |
| RN-11 Atualização | Sinal ativo cuja condição continua | Atualiza severidade, valor e evidência | Severidade piorou → marca `piorou = true` (rompe o cooldown) | §8.2 |
| RN-12 Cooldown | Mesmo cliente + tipo + chave com resultado registrado há menos de 30 dias | Não gera nova ação | Sinal piorou de atenção para crítico → gera | §8.2 |
| RN-13 Ação de reativação | Cliente com ≥ 1 sinal de consumo ativo, fora do cooldown e sem ação `reativacao` aberta | Cria 1 ação: título "Reativar {cliente}", motivo = evidências unidas por " · ", valor = maior valor, peso = maior peso | Ação aberta já existe → atualiza motivo, valor, peso e `sinais_ids` | §8.3 |
| RN-14 Ação de pendência | Sinal de pendência ativo sem ação `pendencia` aberta para a mesma pendência | Cria ação "Pendência {pedido} · {item}" | — | §8.3 |
| RN-15 Responsável | — | `vendedor_id` do cliente; sem vendedor → `parametros.vendedor_padrao_id` | — | §8.3 |
| RN-16 Pontuação | Toda ação `aberta` de origem motor, todo dia | `pontuacao = valor_em_risco × peso × fator_atraso`; `fator_atraso = min(1 + 0,1 × dias úteis desde data_prevista, 2,0)` | Ações `retorno` ficam fora da pontuação (prioridade máxima por bloco, SPEC-1-007) | §8.3 |
| RN-17 Faixa | Por vendedor, entre as ações abertas de origem motor | `alta` se algum sinal é crítico **ou** está entre os `ceil(n × 0,30)` maiores; senão `normal`; `prazo = data_prevista + 2` (alta) ou `+ 5` (normal) dias úteis | — | §8.3 |
| RN-18 Limite diário | Mais de 15 ações novas de origem motor para um vendedor no dia | As 15 de maior pontuação recebem `data_prevista = D`; as demais `na_fila = true` e entram nos dias seguintes por pontuação, até completar 15 por dia | — | §8.3 |
| RN-19 Dias úteis | Toda contagem "dias úteis" | Segunda a sexta, exceto `feriados` | — | §8.5 |

## Fluxo e regras

1. A importação L3 é confirmada → `rodar_rotina_comercial(D)`, que executa métricas → `motor_sinais(D)` → `gerar_acoes(D)` e registra `integracao_execucoes` com `conjunto = 'rotina_comercial'`, contagens e duração.
2. `motor_sinais`:
   1. avalia RN-01 a RN-09 para todos os clientes;
   2. faz upsert dos sinais ativos;
   3. encerra os que deixaram de existir (RN-10);
   4. grava a situação comercial;
   5. atualiza `sinais_ativos` e `qtd_sinais` em `vw_carteira`.
3. `gerar_acoes`:
   1. aplica RN-12 a RN-18;
   2. recalcula a pontuação e a faixa de todas as ações abertas de origem motor;
   3. promove ações da fila.
4. Às 09:30, se `rotina_comercial` não rodou no dia, o job executa `rodar_rotina_comercial(current_date)`.
5. A Carteira ganha:
   - a coluna "Sinais", com chips curtos (Queda, Recompra, Família, Item-chave, Silencioso, Inativo, Pendência) e tooltip com a evidência;
   - o filtro "Sinal".

**Fixture de prova** — D = **06/11/2026**:
- fixture de métricas da SPEC-1-003 (C001 a C006), **mais**:
  - `C007` (RS, reposicao_direta): dia 01 de nov/2025 a set/2026 (11 notas), I1 30 un R$ 3.000; sem interações;
  - pendência `30677` de C002, item I2, 4 un, aberta desde 01/10/2026;
- Todos os clientes com o mesmo vendedor de teste.
- Preço de referência de I2 para C002 = R$ 100 (média de I2 nos últimos 90 dias, vinda de C001 em 15/08).

**Resultados esperados:**

| Cliente | Sinais ativos | Situação | Ação | Valor em risco | Peso | Pontuação | Faixa |
|---|---|---|---|---|---|---|---|
| C001 | `queda_consumo` crítico (7.000); `familia_abandonada` pistao_pesada (4.000) | queda | 1 reativação | 7.000,00 | 1,0 | 7.000,00 | alta |
| C002 | `pendencia_antiga` (36 dias; 4 × 100) | ativo | 1 pendência | 400,00 | 0,6 | 240,00 | normal |
| C003 | `cliente_inativo` (5.333,33); demais suprimidos | inativo | 1 reativação | 5.333,33 | 0,5 | 2.666,67 | alta (crítico) |
| C004 | — (não elegível) | ativo | — | — | — | — | — |
| C005 | — (mercado indústria) | ativo | — | — | — | — | — |
| C006 | `queda_consumo` atenção (3.200) | atencao | 1 reativação | 3.200,00 | 0,8 | 2.560,00 | normal |
| C007 | `queda_consumo` crítico (3.000); `recompra_vencida` crítico (66 dias > 2 × 30,4); `cliente_silencioso` (66 dias, sem interação); `familia_abandonada` pistao_leve (3.000) | queda | 1 reativação | 3.000,00 | 1,0 | 3.000,00 | alta |

Faixa: 5 ações → `ceil(5 × 0,3) = 2` maiores (C001 e C007) + críticos (C003) = alta; C006 e C002 normal.

| Cenário | Dado/condição | Resultado esperado | Caminho de erro/recuperação |
|---|---|---|---|
| Principal | Fixture com D = 06/11/2026 | Tabela de resultados esperados | — |
| Limite | Rodar a rotina 2 vezes no mesmo dia | Nenhum sinal ou ação duplicado; pontuações iguais | — |
| Limite | C001 recebe nota de R$ 12.000 em 07/11 e a rotina roda em 07/11 | `queda_consumo` de C001 encerrado (condição resolvida); a ação de reativação continua aberta por causa da família abandonada, com o motivo atualizado | — |
| Limite | 20 sinais novos para o mesmo vendedor | 15 com data de hoje; 5 na fila | — |
| Limite | Resultado registrado em C006 há 10 dias e a queda continua em atenção | Nenhuma nova ação (cooldown) | Se virar crítica, gera nova ação |
| Falha | Erro no meio do motor | Transação desfeita; execução `falhou` visível na tela Importações; sinais e ações anteriores intactos | Corrigir e "Recalcular agora" (passa a executar a rotina completa) |

## Instruções de execução para o Ethos

1. **Ler antes de alterar:** `02-Escopo-Definitivo.md` §8.2, §8.3 e §10; SPECs 1-002, 1-003, 1-004 e 1-005; esta SPEC (RN-01 a RN-19 e a fixture).
2. **Alterar somente:**
   - tabelas, listas, parâmetros e funções desta SPEC;
   - chamadas em `confirmar_importacao`;
   - o botão "Recalcular agora", que passa a chamar `rodar_rotina_comercial`;
   - a coluna e o filtro de sinais em `vw_carteira` e na tela Carteira;
   - o job das 09:30.
3. **Não alterar:** fórmulas de métricas da SPEC-1-003 (exceto a substituição da RN-08 pela situação por sinais); layouts de importação.
4. **Executar nesta ordem:**
   1. Tabelas e listas.
   2. `motor_sinais` com a fixture.
   3. `gerar_acoes` com a fixture.
   4. Gatilhos e job.
   5. Coluna na Carteira.
   6. Base real.
   7. Conferência dos 10 sinais.
5. **Parar e pedir validação quando:**
   - a base real gerar mais de 40 ações novas por vendedor no primeiro dia (os limites podem precisar de ajuste antes do uso);
   - a conferência da Ângela apontar sinal incorreto.
6. **Estado válido ao parar:** importação e métricas funcionam; nenhuma ação duplicada.

## Checklist de execução

- [ ] Tabelas, listas iniciais e parâmetros criados, com RLS
- [ ] `motor_sinais`, `gerar_acoes` e `rodar_rotina_comercial` reproduzem a fixture
- [ ] Gatilhos após L3 e L4 e job das 09:30
- [ ] Coluna e filtro "Sinal" na Carteira
- [ ] Rodada sobre a base real com volume de ações por vendedor registrado
- [ ] 10 sinais reais conferidos pela Ângela
- [ ] Evidências salvas em `05_entregas/fase-1/SPEC-1-006/`

## Critérios de aceite

- [ ] **CA-1-26:** Com a fixture, os sinais, a situação, as ações, os valores, a pontuação e a faixa são exatamente os da tabela de resultados esperados.
- [ ] **CA-1-27:** Rodar a rotina duas vezes no mesmo dia não duplica sinais nem ações; um sinal cuja condição deixou de existir é encerrado automaticamente.
- [ ] **CA-1-28:** Com mais de 15 ações novas para um vendedor, só 15 recebem a data do dia e as demais vão para a fila.
- [ ] **CA-1-29:** Depois da importação L3 confirmada, sinais e ações estão atualizados em até 2 minutos sem ação manual; sem importação, rodam às 09:30.
- [ ] **CA-1-30:** A Ângela confere 10 sinais da base real (ao menos 1 de cada tipo existente na base) e todos estão corretos.

## TDD da SPEC

| Etapa | Prova | Comando/ação | Resultado esperado | Evidência |
|---|---|---|---|---|
| RED 1 | Funções inexistentes | `select rodar_rotina_comercial('2026-11-06')` | Erro "function does not exist" | `red.txt` |
| GREEN 1 | Fixture | Branch de teste com a fixture; `select rodar_rotina_comercial('2026-11-06')`; `select c.codigo_focco, s.tipo, s.severidade, s.valor_em_risco from sinais s join clientes c on c.id=s.cliente_id where s.situacao='ativo' order by 1,2`; `select c.codigo_focco, a.tipo, a.valor_em_risco, a.peso, a.pontuacao, a.faixa from acoes a join clientes c on c.id=a.cliente_id where a.situacao='aberta' order by 1`; `select codigo_focco, situacao_comercial from clientes order by 1` | Igual à tabela de resultados esperados | `fixture.txt` |
| GREEN 2 | Idempotência e encerramento | Rodar de novo no mesmo dia; inserir nota de R$ 12.000 para C001 em 07/11 e rodar com D = 07/11 | Contagens iguais; `queda_consumo` de C001 encerrado; ação de C001 atualizada | `idempotencia.txt` |
| GREEN 3 | Limite diário | Gerar 20 clientes em queda para o vendedor de teste | 15 com `data_prevista = D`; 5 com `na_fila = true` | `limite.txt` |
| GREEN 4 | Gatilho | Confirmar uma importação L3 no branch de teste | `integracao_execucoes` com `rotina_comercial` em ≤ 2 min | `gatilho.txt` |
| GREEN 5 | Base real | Planilha com 10 sinais escolhidos pela Ângela: cliente, tipo, evidência e conferência no FOCCO | 10 corretos | `conferencia-sinais.xlsx` |
| REFACTOR/REGRESSÃO | Cooldown, RLS e falha | Registrar resultado (via SQL) em C006 e rodar de novo; como vendedor A, contar sinais de clientes do vendedor B; forçar erro no branch | Sem nova ação; 0; transação desfeita | `regressao.txt` |

**Caminhos de erro obrigatórios:** idempotência, condição resolvida, cooldown, piora de severidade, limite diário, cliente sem vendedor, preço de referência ausente (valor 0), falha da rotina.  
**Evidência exigida:** arquivos citados em `05_entregas/fase-1/SPEC-1-006/`.

## Handoff e operação

- **Como demonstrar:**
  1. Marco importa o faturamento do dia e, 2 minutos depois, a Carteira mostra os sinais.
  2. Ângela mostra 3 dos 10 sinais conferidos com o FOCCO.
- **Como operar depois:** a rotina é automática após a importação diária. A Ângela ajusta limites e pesos pela tela Parâmetros (SPEC-1-008).
- **Como monitorar:** execuções `rotina_comercial` no histórico da tela Importações.
- **Pendência conhecida:** nenhuma.

## Tasks vinculadas

| ID | Task | Dono | SPEC | Critério | Recorte da prova | Evidência esperada | Pré-condições | Status |
|---|---|---|---|---|---|---|---|---|
| 1.20 | Criar `sinais`, `acoes`, `resultados_tipo`, `motivos_perda`, listas iniciais e parâmetros do motor, com RLS | Marco Carvalho | SPEC-1-006 | CA-1-26 (estrutura) | RED 1; REGRESSÃO (RLS) | `red.txt`, `regressao.txt` | 1.10 e 1.16 concluídas | ☐ |
| 1.21 | Implementar `motor_sinais` (RN-01 a RN-11) e a situação comercial por sinais | Marco Carvalho | SPEC-1-006 | CA-1-26, CA-1-27 | GREEN 1 (sinais e situação) e GREEN 2 | `fixture.txt`, `idempotencia.txt` | 1.20 concluída | ☐ |
| 1.22 | Implementar `gerar_acoes` (RN-12 a RN-19), `rodar_rotina_comercial`, gatilhos, job das 09:30 e coluna "Sinais" na Carteira | Marco Carvalho | SPEC-1-006 | CA-1-26, CA-1-28, CA-1-29 | GREEN 1 (ações), GREEN 3, GREEN 4 | `fixture.txt`, `limite.txt`, `gatilho.txt` + captura da Carteira | 1.21 e 1.13 concluídas | ☐ |
| 1.23 | Conferir 10 sinais da base real com o FOCCO | Ângela Ferreira | SPEC-1-006 | CA-1-30 | GREEN 5 | `conferencia-sinais.xlsx` | 1.22 e 1.08 concluídas | ☐ |

## Emendas

<!-- Append-only (D19): mudanças aprovadas depois da geração. A história não é reescrita. -->

| Data | Origem do sinal | Micro-spec/task | Motivo |
|---|---|---|---|
| | | | |
