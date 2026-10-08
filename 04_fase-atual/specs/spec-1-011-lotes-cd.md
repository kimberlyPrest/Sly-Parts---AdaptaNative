# SPEC-1-011 — Lotes C/D: demanda ativa para fechar lote de produção

**Fase:** 1  
**Status:** planejada  
**Dono:** Marco Carvalho (TI Platina) · **Consultoria:** Kimberly Prestes (Adapta)  
**Origem no escopo:** `02-Escopo-Definitivo.md` §8.4 (oportunidades de lote curva C/D), §7.5 (`oportunidades_lote`, `compromissos_lote`), §8.5 (alertas de lote), §9.5 (aba Lotes C/D), §9.1 (destino do PCP); Kickoff, Gabrielle: "itens curva C e D… fica na pendência 100 peças e precisa ter 300 para produzir… o sistema poderia dizer ao vendedor: vá atrás do cliente"  
**Degrau da solução:** reuso — o motor de sinais e ações da SPEC-1-006 ganha o tipo `lote_cd`; tabelas e telas novas no Skip/Supabase; nenhuma integração.

## Contexto e decisões fechadas

- **Estado atual:** itens de curva C e D (maior valor agregado) ficam parados na pendência porque a soma dos pedidos não atinge o lote mínimo de produção, e nenhum vendedor é avisado para buscar a demanda que completaria o lote (Kickoff).
- **Estado desejado:**
  - Para cada item C/D com pendência abaixo do lote mínimo, a Central Sly abre uma **oportunidade de lote**, sugere os clientes que já compraram o item e cria a ação "Oferecer item X" para os vendedores.
  - Quando o vendedor registra "Cliente vai comprar" com quantidade, ela soma como **compromisso**.
  - Ao atingir o lote, o PCP é avisado e registra a programação.
- **Decisões já fechadas:**
  - **Fonte de curva e lote mínimo:** layout L5 (curva e lote) da SPEC-1-002. Item sem `curva` ou sem `lote_minimo` não entra.
  - **Pendência considerada:** soma de `quantidade_pendente` das pendências `aberta` do item em todos os clientes.
  - **Quando avalia:**
    - ao fim da rotina comercial depois de importação L4 ou L5;
    - toda segunda-feira dentro da rotina das 09:30.
  - **Clientes sugeridos:** até **5**, os que compraram o item nos últimos 12 meses, por quantidade comprada (decrescente), sem pendência aberta do item e com situação diferente de `inativo`.
  - **Uma ação por cliente sugerido**, do tipo `lote_cd`, pelo motor (sinal `lote_cd`, peso 0,8, valor em risco = quantidade faltante × preço de referência do item).
  - **Compromisso:** o resultado `vai_comprar` numa ação `lote_cd` exige quantidade (1 a 10.000) e cria `compromissos_lote`.
  - **Lote atingido:** quando `pendência + compromissos ≥ lote mínimo` → situação `lote_atingido` + alertas para o PCP e a supervisora. O PCP marca `programada` com a data prevista de produção, que aparece na ficha dos clientes envolvidos.
  - **Usuário do PCP:** criado nesta SPEC pelo admin, com destino `/lotes`.
- **Bloqueios:** nenhum. Depende de a planilha L5 (curva e lote) estar carregada (task 1.08).

## Resultado observável

O item `PS 864 S STD` (curva D, lote mínimo 300) tem 100 peças pendentes. A Central Sly abre a oportunidade com 200 faltantes e cria ações "Oferecer PS 864 S STD" para Tonini, Giros e Serraf, os maiores compradores do item nos últimos 12 meses. Marcio registra "Tonini vai comprar 120"; Camila registra "Giros vai comprar 90". O total chega a 310, o PCP recebe o alerta "Lote atingido: PS 864 S STD" e marca "Programada para 25/11", que aparece na ficha da Tonini e da Giros.

## Limites e dependências

- **Inclui:**
  - tabelas `oportunidades_lote` e `compromissos_lote`;
  - função `avaliar_lotes(D)`;
  - sinal e ação `lote_cd` no motor;
  - quantidade obrigatória em `vai_comprar` de lote;
  - verificação de compromisso convertido;
  - alertas `lote_atingido` e `lote_parado`;
  - rota `/lotes` (PCP, supervisora, diretoria);
  - aba Lotes C/D em Oportunidades;
  - informação de lote na ficha;
  - criação do usuário do PCP e item de menu.
- **Fora de escopo:**
  - programação de produção, capacidade, ferramental ou qualquer decisão do PCP além de registrar a data prevista;
  - consulta de estoque (fora do escopo, D15);
  - envio de mensagens ao cliente (fase 2).
- **Entradas e pré-condições:** SPECs 1-002 (`pendencias`, `itens` com curva e lote via L5), 1-006 (motor), 1-007 (resultado), 1-008 (alertas).
- **Saídas/artefatos:** migração SQL; telas; validação com o PCP e a Ângela.
- **Dependências e responsáveis:** Marco constrói no Skip e no Supabase, com orientação da consultora Kimberly, e cria o usuário do PCP; o analista de PCP e a Ângela validam com 1 item real.
- **Atores e permissões mínimas:**

| Ator | Ver oportunidades | Registrar compromisso | Marcar programada / encerrar sem lote |
|---|---|---|---|
| vendedor | as que têm ação para clientes da própria carteira (aba em Oportunidades) | pelas próprias ações | — |
| supervisora | todas | por qualquer ação | encerrar sem lote |
| pcp | todas (`/lotes`) | — | marcar programada; encerrar sem lote |
| diretoria | todas (leitura) | — | — |

- **Superfícies/arquivos/configurações afetadas:** Supabase: tabelas, `avaliar_lotes`, ajustes em `motor_sinais`, `gerar_acoes` e `registrar_resultado`, tipos de alerta, parâmetros `lote_clientes_sugeridos` (5), `lote_compromisso_prazo_dias` (15), `lote_parado_dias` (15); Skip: `/lotes`, aba em `/oportunidades`, ficha, menu, destino do PCP.
- **Risco e plano B:** curva ou lote mínimo desatualizados geram oportunidades erradas → o PCP pode "Encerrar sem lote" com motivo, e a planilha L5 é corrigida na segunda seguinte.
- **Rollback ou reversão:** desligar a chamada de `avaliar_lotes` e os sinais `lote_cd` (situação `encerrado`) interrompe tudo sem afetar a reativação.

## Dados e integrações

Sem integração externa.

**`oportunidades_lote`:**
- `item_id` · `curva` · `lote_minimo` · `pendencia_qtd` · `compromissos_qtd` · `faltante_qtd` (gerado: `max(lote_minimo − pendencia_qtd − compromissos_qtd, 0)`) · `valor_potencial` · `situacao` check (`aberta`,`lote_atingido`,`programada`,`encerrada_sem_lote`,`concluida`) · `data_programada` · `programada_por` · `encerrada_motivo` · `aberta_em` · `ultimo_compromisso_em` · `atualizado_em`;
- único parcial por `item_id` com situação `aberta` ou `lote_atingido`.

**`compromissos_lote`:** `oportunidade_id` · `cliente_id` · `vendedor_id` · `acao_id` · `quantidade` · `data_compromisso` · `convertido` boolean · `convertido_em` · `expirado` boolean.

| Regra | Condição | Ação/resultado | Exceção | Fonte |
|---|---|---|---|---|
| RN-01 Abertura | Item ativo com `curva in ('C','D')`, `lote_minimo > 0`, pendência aberta > 0 e pendência < lote mínimo, sem oportunidade aberta | Cria a oportunidade | Item sem pendência → não abre | §8.4 |
| RN-02 Atualização | A cada avaliação | Atualiza pendência, compromissos válidos (não expirados) e faltante | — | §8.4 |
| RN-03 Clientes sugeridos | Oportunidade `aberta` | Até 5 clientes (RN dos clientes sugeridos acima); para cada um, sinal `lote_cd` (chave = oportunidade) e ação `lote_cd` "Oferecer {item} — faltam {n} para o lote" via `gerar_acoes` | Cliente em cooldown para o mesmo item → pula e usa o próximo | §8.4 |
| RN-04 Compromisso | `vai_comprar` numa ação `lote_cd` | `quantidade` obrigatória; cria compromisso; a ação de retorno do resultado tem título "Confirmar pedido de {qtd} {item}" | — | §8.4 |
| RN-05 Lote atingido | `pendencia_qtd + compromissos_qtd ≥ lote_minimo` | `situacao = 'lote_atingido'`; alerta `lote_atingido` para todos os usuários pcp e para a supervisora; ações `lote_cd` ainda abertas da oportunidade são canceladas com "Lote atingido" | — | §8.4, §8.5 |
| RN-06 Programada | PCP informa data prevista (hoje até D + 120) | `situacao = 'programada'`; a ficha de cada cliente com compromisso ou pendência do item mostra "Lote de {item} programado para dd/mm" | — | §8.4 |
| RN-07 Conversão | Para cada compromisso, pendência nova do item para o cliente com data ≥ data do compromisso, ou venda importada do item | `convertido = true` | — | §8.6 |
| RN-08 Compromisso sem pedido | Compromisso com mais de 15 dias e não convertido | `expirado = true`, sai da soma; ação `retorno` "Compromisso de {qtd} {item} sem pedido" para o vendedor | — | §8.4 |
| RN-09 Lote parado | Oportunidade `aberta` sem novo compromisso há 15 dias | Alerta `lote_parado` para a supervisora (sem duplicar) | — | §8.5 |
| RN-10 Encerrar sem lote | PCP ou supervisora, com motivo (≥ 10 caracteres) | `encerrada_sem_lote`; sinais `lote_cd` encerrados; ações abertas canceladas | — | operação |
| RN-11 Conclusão | Oportunidade `programada` cujo item não tem mais pendência aberta | `concluida` | — | §8.4 |

## Telas

**`/lotes`** (tela inicial do PCP):
1. **Cabeçalho:** contadores (Abertas, Lote atingido, Programadas, Peças viabilizadas nos últimos 90 dias).
2. **Tabela:** item (código e descrição), curva, lote mínimo, pendência, compromissos, faltante, barra de progresso (pendência + compromissos ÷ lote), situação, aberta há (dias), data programada.
3. **Detalhe** (painel lateral):
   - pendências por cliente;
   - compromissos (cliente, vendedor, quantidade, data, convertido/expirado);
   - clientes sugeridos e situação das ações;
   - botões "Marcar programada" (PCP) e "Encerrar sem lote" (PCP, supervisora).
4. Filtros: situação, curva.

**`/oportunidades` — aba Lotes C/D:** as mesmas linhas, com destaque para as ações do vendedor logado. Para o vendedor, só oportunidades com ação para clientes da carteira dele.

**Ficha do cliente:** seção "Lotes" quando o cliente tem compromisso ou pendência de item com oportunidade, mostrando o item, a situação e a data programada.

**Meu dia:** cartões `lote_cd` com o motivo "Faltam {n} peças de {item} para o lote de {lote} — você vendeu {qtd} para este cliente nos últimos 12 meses".

| Cenário | Dado/condição | Resultado esperado | Caminho de erro/recuperação |
|---|---|---|---|
| Principal | Fixture abaixo | Oportunidade com faltante 200; 3 ações | — |
| Principal | Compromissos 120 + 90 | Situação `lote_atingido`; alertas ao PCP e à supervisora; ações restantes canceladas | — |
| Principal | PCP marca 25/11 | `programada`; ficha dos clientes mostra a data | — |
| Limite | Compromisso de 20 dias sem pedido | Expirado; retorno para o vendedor; faltante recalculado | — |
| Limite | Item curva A | Não abre oportunidade | — |
| Falha | `vai_comprar` em ação de lote sem quantidade | Bloqueado | Informar quantidade |
| Falha | Vendedor tenta marcar programada | Botão ausente; função recusa | — |

**Fixture** (D = 06/11/2026):
- `PS 864 S STD`: curva D, lote 300.
- Pendências abertas de 100 un (C002 40, C004 60).
- Vendas nos últimos 12 meses do item: C001 400 un, C006 250 un, C003 200 un (C003 inativo), C005 150 un, C007 50 un.

**Resultado esperado:**
- oportunidade com `faltante_qtd = 200`;
- clientes sugeridos, nesta ordem: C001, C006, C005, C007. C003 fica fora por estar inativo; C002 e C004 ficam fora por terem pendência do item.

## Instruções de execução para o Ethos

1. **Ler antes de alterar:** `02-Escopo-Definitivo.md` §8.4 e §8.5; SPECs 1-002, 1-006, 1-007 e 1-008; esta SPEC.
2. **Alterar somente:** objetos desta SPEC e os trechos `lote_cd` em `motor_sinais`, `gerar_acoes` e `registrar_resultado`; tipos de alerta; telas listadas.
3. **Não alterar:** as regras de reativação e de pendência; a importação.
4. **Executar nesta ordem:**
   1. Tabelas.
   2. `avaliar_lotes` com a fixture.
   3. Sinal e ação.
   4. Compromisso e conversão.
   5. Alertas.
   6. `/lotes`.
   7. Aba em Oportunidades.
   8. Ficha.
   9. Usuário do PCP.
   10. Validação com 1 item real.
5. **Parar e pedir validação quando:** a primeira avaliação real abrir mais de 30 oportunidades (curva ou lote mínimo podem estar desatualizados; revisar com o PCP antes de gerar ações).
6. **Estado válido ao parar:** nenhuma oportunidade duplicada por item; compromissos somados corretamente.

## Checklist de execução

- [ ] Tabelas, `avaliar_lotes` e parâmetros
- [ ] Sinal e ação `lote_cd`; quantidade obrigatória no compromisso
- [ ] Conversão e expiração de compromissos
- [ ] Alertas de lote atingido e lote parado
- [ ] `/lotes`, aba em Oportunidades e seção na ficha
- [ ] Usuário do PCP criado com destino `/lotes`
- [ ] Validação com 1 item real
- [ ] Evidências salvas em `05_entregas/fase-1/SPEC-1-011/`

## Critérios de aceite

- [ ] **CA-1-53:** Com a fixture, a oportunidade de `PS 864 S STD` tem faltante 200 e os clientes sugeridos são, nesta ordem, C001, C006, C005 e C007, cada um com uma ação `lote_cd` para o seu vendedor.
- [ ] **CA-1-54:** O resultado "Cliente vai comprar" numa ação de lote só salva com quantidade e soma no compromisso; ao atingir o lote, PCP e supervisora recebem o alerta e as ações restantes são canceladas.
- [ ] **CA-1-55:** O PCP marca a oportunidade como programada, e a data aparece na ficha dos clientes envolvidos.
- [ ] **CA-1-56:** Compromisso sem pedido em 15 dias expira, sai da soma e gera retorno para o vendedor; compromisso com pedido fica `convertido`.
- [ ] **CA-1-57:** O analista de PCP e a Ângela acompanham 1 item real C/D do início ao "lote atingido" ou ao "encerrada sem lote", com o registro em `validacao.md`.

## TDD da SPEC

| Etapa | Prova | Comando/ação | Resultado esperado | Evidência |
|---|---|---|---|---|
| RED 1 | Função inexistente | `select avaliar_lotes('2026-11-06')` | Erro "function does not exist" | `red.txt` |
| GREEN 1 | Fixture | Branch de teste com a fixture; `select rodar_rotina_comercial('2026-11-06')`; consultar `oportunidades_lote` e as ações `lote_cd` | Conforme o CA-1-53 | `fixture.txt` |
| GREEN 2 | Compromissos | `registrar_resultado` `vai_comprar` 120 em C001 e 90 em C006; tentar sem quantidade | Lote atingido; alertas; ações de C005 e C007 canceladas; bloqueio sem quantidade | `compromissos.txt` |
| GREEN 3 | Programada | Como pcp, marcar programada para D + 19 | Situação e ficha de C001 e C006 | `programada.txt` + captura |
| GREEN 4 | Expiração e conversão | Compromisso com data D − 16 sem pedido; outro com pendência nova do item | Expirado + retorno; convertido | `conversao.txt` |
| GREEN 5 | Item real | Acompanhar 1 item real | Registro do percurso | `validacao.md` |
| REFACTOR/REGRESSÃO | Bordas | Item curva A; item sem lote mínimo; vendedor marcando programada; rodar a avaliação 2 vezes | Sem oportunidade; sem oportunidade; recusado; sem duplicata | `regressao.txt` |

**Caminhos de erro obrigatórios:** item fora de C/D, sem lote mínimo, compromisso sem quantidade, expiração, permissão do PCP, idempotência.  
**Evidência exigida:** arquivos citados em `05_entregas/fase-1/SPEC-1-011/`.

## Handoff e operação

- **Como demonstrar:**
  1. O PCP abre `/lotes` com um item real.
  2. A Ângela mostra as ações dos vendedores.
  3. Um compromisso registrado faz a barra avançar.
- **Como operar depois:**
  - O PCP confere `/lotes` às segundas, depois da importação da curva e do lote.
  - Os vendedores tratam as ações `lote_cd` no Meu dia.
- **Como monitorar:** "Peças viabilizadas" e painel (SPEC-1-012).
- **Pendência conhecida:** nenhuma.

## Tasks vinculadas

| ID | Task | Dono | SPEC | Critério | Recorte da prova | Evidência esperada | Pré-condições | Status |
|---|---|---|---|---|---|---|---|---|
| 1.38 | Criar `oportunidades_lote`, `compromissos_lote`, `avaliar_lotes`, o sinal e a ação `lote_cd`, compromissos, conversão, expiração e alertas | Marco Carvalho | SPEC-1-011 | CA-1-53, CA-1-54, CA-1-56 | RED 1 → GREEN 1, GREEN 2, GREEN 4; REGRESSÃO | `fixture.txt`, `compromissos.txt`, `conversao.txt`, `regressao.txt` | 1.22, 1.24 e 1.28 concluídas | ☐ |
| 1.39 | Construir `/lotes`, a aba Lotes C/D em Oportunidades e a seção de lotes na ficha | Marco Carvalho | SPEC-1-011 | CA-1-55 | GREEN 3 | `programada.txt` + capturas | 1.38 e 1.26 concluídas | ☐ |
| 1.40 | Criar o usuário do PCP e acompanhar 1 item real C/D com a Ângela | Marco Carvalho | SPEC-1-011 | CA-1-57 | GREEN 5 | `validacao.md` com o percurso do item | 1.39 e 1.08 concluídas | ☐ |

## Emendas

<!-- Append-only (D19): mudanças aprovadas depois da geração. A história não é reescrita. -->

| Data | Origem do sinal | Micro-spec/task | Motivo |
|---|---|---|---|
| | | | |
