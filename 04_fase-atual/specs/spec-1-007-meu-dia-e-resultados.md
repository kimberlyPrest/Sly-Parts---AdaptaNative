# SPEC-1-007 — Meu dia, registro de resultado e Oportunidades de reativação

**Fase:** 1  
**Status:** planejada  
**Dono:** Marco Carvalho (TI Platina) · **Consultoria:** Kimberly Prestes (Adapta)  
**Origem no escopo:** `02-Escopo-Definitivo.md` §9.2 (Meu dia), §9.2.1 (resultados), §9.4 (sinais e ações na ficha), §9.5 (Oportunidades — aba Reativação), §9.1 (destino do vendedor), §12.4 (no máximo 3 cliques), D2  
**Degrau da solução:** construção mínima no Skip sobre `acoes` e `resultados_tipo` da SPEC-1-006; duas funções SQL de escrita; nenhuma integração.

## Contexto e decisões fechadas

- **Estado atual:** a venda é passiva. Os vendedores, com 15 a 20 anos de casa, atendem quem pede e não têm uma lista diária do que fazer (Kickoff). Depois da SPEC-1-006, as ações existem no banco mas não têm tela.
- **Estado desejado:**
  - O vendedor entra e cai no **Meu dia**, com a lista priorizada de ações: retornos agendados, atrasadas e novas.
  - Cada ação só fecha com um resultado da lista fixa, com os campos que ele exige.
  - Retornos combinados voltam sozinhos na data.
  - A ficha do cliente mostra sinais e ações.
  - A página Oportunidades mostra a reativação por valor em jogo.
- **Decisões já fechadas:**
  - **Rota:** `/meu-dia`, tela inicial do vendedor (altera o destino definido na SPEC-1-001).
  - A supervisora também acessa, com seletor de vendedor ("Todos" ou um nome).
  - **Registro de resultado:** somente pela função `registrar_resultado`, que valida os campos exigidos (tabela da SPEC-1-006) e, na mesma transação:
    1. conclui a ação;
    2. encerra os sinais quando o resultado encerra;
    3. cria a ação de retorno quando o resultado pede;
    4. grava uma interação na ficha.
  - **Canal do resultado:** o modal tem "Como foi o contato" (Telefone, WhatsApp, Teams, E-mail, Visita), com Telefone como padrão. A interação gerada usa esse canal e o resumo "Resultado: {descrição}. {observação}".
  - O resultado `problema` (Problema de atendimento ou qualidade) só aparece quando a SPEC-1-010 for entregue, porque ele abre ocorrência.
  - **Nova ação manual:** pela função `criar_acao_manual`; tipo `manual`, faixa normal, sem pontuação; aparece na data escolhida.
  - **Bloco "Mensagens fora do horário" (§9.2):** é da fase 2 (WhatsApp) e não aparece agora.
- **Bloqueios:** nenhum.

## Resultado observável

O Marcio entra às 09:40 e vê:
- **Retornos de hoje:** 2 (um cliente que pediu para ligar hoje);
- **Atrasadas:** 1;
- **Novas de hoje:** 9, ordenadas por valor em jogo.

Ele abre "Reativar Tonini" (motivo: "Comprou R$ 6.000 nos últimos 60 dias; média de R$ 10.000/mês (−70%) · parou de comprar Pistão linha pesada"), liga e registra "Cliente vai comprar — 14/11". O cartão sai da lista, os contadores atualizam e, no dia 14/11, aparece um retorno "Tonini — confirmar pedido".

## Limites e dependências

- **Inclui:**
  - funções `registrar_resultado`, `criar_acao_manual`, `reagendar_acao`;
  - políticas de atualização de `acoes`;
  - rota `/meu-dia` (cabeçalho, KPIs, blocos, cartão, modal, aba Fila, nova ação, versão celular);
  - seções "Sinais ativos" e "Ações" na ficha, com o botão "Nova ação";
  - ações concluídas na linha do tempo da ficha;
  - rota `/oportunidades` com a aba **Reativação**;
  - itens "Meu dia" e "Oportunidades" no menu;
  - destino do vendedor → `/meu-dia`.
- **Fora de escopo:**
  - alertas de estagnação e reatribuição (SPEC-1-008);
  - resultado `problema` (SPEC-1-010);
  - abas Novos clientes (SPEC-1-009) e Lotes C/D (SPEC-1-011) de Oportunidades;
  - WhatsApp e sugestão por IA (fase 2).
- **Entradas e pré-condições:** SPEC-1-006 (tasks 1.20 a 1.22); SPEC-1-005 (ficha, tasks 1.17 e 1.18).
- **Saídas/artefatos:** funções SQL; telas; relato de 3 dias de uso em `05_entregas/fase-1/SPEC-1-007/`.
- **Dependências e responsáveis:** Marco constrói no Skip e no Supabase, com orientação da consultora Kimberly; Ângela acompanha 3 dias de uso com 2 vendedores.
- **Atores e permissões mínimas:**

| Ator | Ver ações | Registrar resultado / reagendar | Criar ação manual |
|---|---|---|---|
| vendedor | as próprias | as próprias | para clientes da própria carteira |
| supervisora | todas | todas | para qualquer cliente, escolhendo o vendedor |
| diretoria | todas (leitura em Oportunidades e na ficha) | — | — |
| admin, pcp | — | — | — |

- **Superfícies/arquivos/configurações afetadas:** Supabase: funções e políticas desta SPEC; Skip: `/meu-dia`, `/oportunidades`, seções da ficha `/clientes/:id`, menu e destino do vendedor.
- **Risco e plano B:**
  - Resistência de vendedores veteranos: modal com no máximo 3 cliques, lista de no máximo 15 novas e acompanhamento diário da Ângela nos primeiros 3 dias.
  - Se o volume incomodar, a Ângela reduz `acoes_limite_diario` (SPEC-1-008).
- **Rollback ou reversão:** as telas podem ser ocultadas do menu sem perda de dados. Um resultado registrado por engano é corrigido pela supervisora com "Reabrir ação" (até 24 h), que desfaz o retorno criado e reativa os sinais encerrados por ele.

## Dados e integrações

Sem integração externa.

**Função `registrar_resultado(acao_id, resultado_codigo, canal, observacao, valor_pedido, data_retorno, hora, tipo_compromisso, assunto, quantidade, motivo_perda_codigo, concorrente)`** (`security invoker`; a RLS garante que o usuário pode alterar a ação):

| Regra | Condição | Ação/resultado | Exceção | Fonte |
|---|---|---|---|---|
| RN-01 | Ação não `aberta` | Erro "Esta ação já foi concluída." | — | §9.2 |
| RN-02 | Campos exigidos | `pedido_gerado` → `valor_pedido > 0`; `vai_comprar`, `retornar`, `estoque_alto`, `sem_contato` → `data_retorno` entre amanhã e D + 90; `agendado` → `data_retorno` entre hoje e D + 60, `hora` entre 07:00 e 19:00 e não no passado, `tipo_compromisso` e `assunto` (5 a 120 caracteres); `concorrente` → `motivo_perda_codigo` obrigatório e `concorrente` obrigatório quando o motivo começa com `concorrente_`; `nao_se_aplica` → `observacao` com ≥ 10 caracteres; `pendencia_liberada` → só em ação do tipo `pendencia` | Mensagem por campo, em português | §9.2.1 |
| RN-03 | Conclusão | `situacao = 'concluida'`, `concluida_em = now()`, `concluida_por = perfil_atual_id()` e os campos informados | — | §9.2 |
| RN-04 | Encerra sinal (`resultados_tipo.encerra_sinal`) | Sinais de `sinais_ids` → `tratado`, `encerrado_motivo = 'resultado_registrado'` (inicia o cooldown de 30 dias da SPEC-1-006) | — | §8.2 |
| RN-05 | Cria retorno | Nova ação `tipo = 'retorno'`, mesmo cliente e vendedor, `data_prevista = data_retorno`, título "{cliente} — {descrição do retorno}" (ex.: "confirmar pedido", "retomar contato", "nova tentativa"), `acao_origem_id`, motivo = observação anterior. Para `agendado`, a nova ação é `tipo = 'compromisso'`, com data, hora, tipo e assunto, título "{Ligação/Reunião on-line/Visita} com {cliente} — {assunto}" | — | §9.2.1, §9.9 |
| RN-06 | Interação | Insere em `interacoes` (`origem = 'automatica'`, canal informado, `direcao = 'saida'`, resumo "Resultado: …"), exceto em `sem_contato`, que registra "Tentativa sem contato" | — | §7.3 |
| RN-07 | Reabrir | Só supervisora, até 24 h depois da conclusão: volta para `aberta`, cancela o retorno criado e reativa os sinais tratados por ela | — | rollback |

**Função `criar_acao_manual(cliente_id, titulo, data_prevista, observacao, vendedor_id)`**:
- título com 5 a 120 caracteres; data entre hoje e D + 90;
- `vendedor_id` só pode ser informado pela supervisora; para o vendedor, é ele mesmo;
- tipo `manual`, faixa `normal`.

**Função `reagendar_acao(acao_id, nova_data, motivo)`**:
- muda `data_prevista` (amanhã até D + 30) e registra o motivo na observação;
- não conclui a ação nem inicia cooldown;
- no máximo 2 reagendamentos por ação; no terceiro, só com resultado.

**Políticas de `acoes`:** `update` somente via as funções acima (sem política de update direto para `authenticated`; funções `security definer` com checagem explícita: vendedor dono, ou supervisora).

## Telas

**`/meu-dia`**
1. **Cabeçalho:**
   - "Bom dia, {primeiro nome}" (ou "Boa tarde" depois das 12:00), em Montserrat 700;
   - data por extenso;
   - "Dados atualizados até …";
   - para a supervisora, o seletor de vendedor.
2. **KPIs:** 4 cartões, com números em Montserrat 700, 36 px:
   - Ações de hoje (retornos + novas + atrasadas);
   - Atrasadas (faixa vermelha no topo quando > 0);
   - Concluídas hoje;
   - Valor em jogo hoje (soma de `valor_em_risco` das abertas de hoje).
   - Abaixo, uma barra fina vermelha de progresso (concluídas ÷ total do dia).
3. **Blocos**, com rótulo em maiúsculas:
   1. "AGENDA DE HOJE" (`tipo = 'compromisso'` com data = hoje, em ordem de hora; cartão com horário em destaque; 1 h depois do horário, o cartão ganha o selo "Registrar resultado");
   2. "RETORNOS AGENDADOS" (`tipo = 'retorno'` e data = hoje);
   3. "ATRASADAS" (abertas com `data_prevista < hoje`, ordenadas pela mais antiga);
   4. "NOVOS LEADS" (`tipo in ('primeiro_contato','follow_up')`, criados pela SPEC-1-009; o bloco aparece quando ela for entregue);
   5. "NOVAS DE HOJE" (data = hoje, por `pontuacao` decrescente; manuais ao final).
4. **Cartão da ação:**
   - barra vertical à esquerda (vermelha = alta, teal = normal);
   - nome do cliente com link para a ficha, cidade/UF e badge de situação;
   - ícone e rótulo do tipo;
   - **motivo** com os números em negrito;
   - à direita, "Valor em risco" (R$) e "Prazo dd/mm" (vermelho quando vencido);
   - botões "Ver ficha", "Reagendar" e "Registrar resultado" (primário vermelho).
5. **Modal "Registrar resultado":**
   - os 9 resultados (10 depois da SPEC-1-010) em cartões selecionáveis com ícone;
   - campos condicionais (RN-02);
   - "Como foi o contato";
   - observação opcional, salvo onde é obrigatória;
   - "Salvar" → o cartão sai com animação curta, toast "Resultado registrado" e KPIs atualizados.
   - **Caminho mínimo:** Registrar resultado → escolher cartão → Salvar (3 cliques), quando o resultado não exige campo.
6. **Aba "Fila"** (ao lado de "Hoje"): ações com `na_fila = true`, por pontuação, com o botão "Puxar para hoje".
7. **Botão flutuante "Nova ação"** → formulário de ação manual.
8. **Dia concluído:** ícone de check e "Carteira em dia. Bom trabalho!".
9. **Celular:** cartões em coluna única; botões fixos no rodapé do cartão.

**Ficha do cliente** (acréscimos à SPEC-1-005):
- seção "Sinais ativos" com chips, evidência e data;
- seção "Ações": abertas (com "Registrar resultado") e histórico (resultado, quem, quando);
- botão "Nova ação" no cabeçalho;
- na linha do tempo, as ações concluídas com ícone de check.

**`/oportunidades` — aba Reativação** (abas Novos clientes e Lotes C/D entram nas SPECs 1-009 e 1-011):
- tabela de clientes com sinais de consumo ativos: cliente, situação, sinais (chips), valor em risco, ação aberta (situação e data), vendedor (gestão);
- filtros por vendedor, UF, tipo de sinal e faixa; ordenação padrão por valor em risco;
- total "R$ {soma} em jogo em {n} clientes".

| Cenário | Dado/condição | Resultado esperado | Caminho de erro/recuperação |
|---|---|---|---|
| Principal | Vendedor registra `vai_comprar` com data 14/11 | Ação concluída; retorno criado para 14/11; interação na ficha; sinal continua ativo | — |
| Principal | `pedido_gerado` R$ 8.000 | Ação concluída; sinais tratados; cooldown iniciado | — |
| Limite | `concorrente` sem motivo | Bloqueado no campo | Preencher |
| Limite | `retornar` com data no passado ou acima de 90 dias | Bloqueado | Corrigir |
| Limite | 3º reagendamento | Botão "Reagendar" desabilitado: "Registre um resultado" | — |
| Falha | Vendedor tenta concluir ação de outro (via API) | Erro de permissão | — |
| Falha | Duas abas registram resultado na mesma ação | A segunda recebe "Esta ação já foi concluída." | Recarregar |
| Falha | Supervisora reabre depois de 24 h | Botão ausente; função recusa | — |

## Instruções de execução para o Ethos

1. **Ler antes de alterar:** `02-Escopo-Definitivo.md` §9.2, §9.2.1, §9.4 e §9.5; SPEC-1-006 (tabelas e regras de resultado); SPEC-1-005 (ficha); SPEC-1-001 (identidade e menu); esta SPEC.
2. **Alterar somente:** funções e políticas desta SPEC; `/meu-dia`; `/oportunidades` (aba Reativação); as seções acrescentadas à ficha; o menu e o destino do vendedor.
3. **Não alterar:** regras do motor (SPEC-1-006); as demais seções da ficha.
4. **Executar nesta ordem:**
   1. Funções e testes SQL.
   2. Meu dia (KPIs, blocos, cartão, modal).
   3. Fila e nova ação.
   4. Ficha.
   5. Oportunidades.
   6. Celular.
   7. 3 dias de uso assistido.
5. **Parar e pedir validação quando:** a equipe pedir resultado novo ou mudança de campo obrigatório (vira emenda); ou o uso assistido mostrar mais de 30% de ações concluídas como "Não se aplica" (sinal de regra mal calibrada para a Ângela ajustar).
6. **Estado válido ao parar:** as ações continuam sendo geradas; nenhuma ação fica concluída sem resultado.

## Checklist de execução

- [ ] Funções `registrar_resultado`, `criar_acao_manual`, `reagendar_acao` com testes SQL
- [ ] Meu dia com KPIs, blocos, cartão, modal, fila, nova ação e versão celular
- [ ] Sinais, ações e "Nova ação" na ficha; ações concluídas na linha do tempo
- [ ] Oportunidades com a aba Reativação
- [ ] Menu e destino do vendedor → `/meu-dia`
- [ ] 3 dias de uso assistido com 2 vendedores
- [ ] Evidências salvas em `05_entregas/fase-1/SPEC-1-007/`

## Critérios de aceite

- [ ] **CA-1-31:** Uma ação não fica concluída sem resultado, e cada resultado só salva com os campos que exige (os 9 resultados testados).
- [ ] **CA-1-32:** Os resultados `vai_comprar`, `retornar`, `estoque_alto` e `sem_contato` criam um retorno que aparece no bloco "Retornos agendados" exatamente na data informada; `agendado` cria um compromisso que aparece na "Agenda de hoje" na data e no horário informados, também na ficha do cliente.
- [ ] **CA-1-33:** Registrar um resultado sem campo obrigatório leva no máximo 3 cliques a partir do Meu dia e gera a interação na linha do tempo da ficha.
- [ ] **CA-1-34:** Resultados que encerram sinal marcam os sinais como `tratado`, e o motor não gera nova ação para eles por 30 dias.
- [ ] **CA-1-35:** Um vendedor não vê nem altera ações de outro vendedor; a supervisora vê todas e filtra por vendedor.
- [ ] **CA-1-36:** Em 3 dias de uso assistido, 2 vendedores registram resultado em pelo menos 80% das ações do dia (relato em `uso-assistido.md`).

## TDD da SPEC

| Etapa | Prova | Comando/ação | Resultado esperado | Evidência |
|---|---|---|---|---|
| RED 1 | Função inexistente | `select registrar_resultado(...)` | Erro "function does not exist" | `red.txt` |
| GREEN 1 | Campos exigidos | Script SQL com uma chamada válida e uma inválida para cada um dos 9 resultados, sobre ações da fixture da SPEC-1-006 | 9 válidas aceitas; 9 inválidas recusadas com a mensagem do campo | `resultados.txt` |
| GREEN 2 | Retorno e agenda | `vai_comprar` com `data_retorno = D + 3`; `agendado` com D + 1, 14:30, visita; consultar `acoes` | Ação `retorno` com `data_prevista = D + 3` (bloco Retornos em D + 3); ação `compromisso` em D + 1 às 14:30 (bloco Agenda de hoje em D + 1) | `retorno.txt` + captura |
| GREEN 3 | Encerramento e cooldown | `pedido_gerado` em C001; rodar `rodar_rotina_comercial` no dia seguinte | Sinais `tratado`; nenhuma ação nova para C001 | `cooldown.txt` |
| GREEN 4 | 3 cliques | Gravação de tela registrando `pedido_gerado` | ≤ 3 cliques além da digitação do valor; interação na ficha | Vídeo curto |
| GREEN 5 | Permissão | Como vendedor A, `registrar_resultado` numa ação do vendedor B; como supervisora, listar com o filtro de vendedor | Erro; lista correta | `permissao.txt` |
| GREEN 6 | Uso assistido | 3 dias úteis com 2 vendedores | ≥ 80% das ações do dia com resultado | `uso-assistido.md` |
| REFACTOR/REGRESSÃO | Bordas | Concorrência (2 abas), 3º reagendamento, reabrir dentro e fora de 24 h, celular 390 px | Comportamentos da tabela de cenários | Capturas |

**Caminhos de erro obrigatórios:** campo obrigatório ausente, data fora da faixa, ação já concluída, permissão, limite de reagendamento, reabertura fora do prazo.  
**Evidência exigida:** arquivos citados em `05_entregas/fase-1/SPEC-1-007/`.

## Handoff e operação

- **Como demonstrar:** Marcio abre o Meu dia, registra 2 resultados (um pedido e um retorno) e mostra o retorno no dia seguinte.
- **Como operar depois:**
  - Os vendedores abrem o Meu dia todo dia útil, depois da importação das 09:00.
  - A Ângela acompanha pela Supervisão (SPEC-1-008).
- **Como monitorar:** KPI "Concluídas hoje" e painel de execução (SPEC-1-012).
- **Pendência conhecida:** nenhuma.

## Tasks vinculadas

| ID | Task | Dono | SPEC | Critério | Recorte da prova | Evidência esperada | Pré-condições | Status |
|---|---|---|---|---|---|---|---|---|
| 1.24 | Implementar `registrar_resultado`, `criar_acao_manual`, `reagendar_acao` e as políticas de `acoes` | Marco Carvalho | SPEC-1-007 | CA-1-31, CA-1-32, CA-1-34, CA-1-35 | RED 1 → GREEN 1, GREEN 2 (SQL), GREEN 3, GREEN 5 | `resultados.txt`, `retorno.txt`, `cooldown.txt`, `permissao.txt` | 1.22 concluída | ☐ |
| 1.25 | Construir a tela Meu dia (KPIs, blocos, cartão, modal, fila, nova ação, celular) e mudar o destino do vendedor | Marco Carvalho | SPEC-1-007 | CA-1-32, CA-1-33 | GREEN 2 (tela), GREEN 4, REGRESSÃO | Vídeo de 3 cliques + capturas | 1.24 concluída | ☐ |
| 1.26 | Acrescentar sinais, ações e "Nova ação" à ficha e criar Oportunidades com a aba Reativação | Marco Carvalho | SPEC-1-007 | CA-1-33, CA-1-35 | GREEN 4 (linha do tempo) e GREEN 5 (filtro da supervisora) | Capturas da ficha e de Oportunidades | 1.24, 1.17 e 1.18 concluídas | ☐ |
| 1.27 | Conduzir 3 dias de uso assistido do Meu dia com 2 vendedores | Ângela Ferreira | SPEC-1-007 | CA-1-36 | GREEN 6 | `uso-assistido.md` | 1.25, 1.26 e 1.23 concluídas | ☐ |

## Emendas

<!-- Append-only (D19): mudanças aprovadas depois da geração. A história não é reescrita. -->

| Data | Origem do sinal | Micro-spec/task | Motivo |
|---|---|---|---|
| | | | |
