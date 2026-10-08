# SPEC-1-005 — Ficha do cliente (visão 360°) com registro manual de contatos

**Fase:** 1  
**Status:** planejada  
**Dono:** Marco Carvalho (TI Platina) · **Consultoria:** Kimberly Prestes (Adapta)  
**Origem no escopo:** `02-Escopo-Definitivo.md` §9.4 (Ficha do cliente), §7.1 (`contatos`), §7.3 (`interacoes`), §4.2 (permissões "Registrar resultado / interação"), D9 (contatos de Teams, e-mail e telefone registrados manualmente), §12.2 (LGPD)  
**Degrau da solução:** construção mínima no Skip com Recharts e shadcn/ui, sobre as tabelas das SPECs 1-002 e 1-003; uma tabela nova (`interacoes`) e políticas de escrita em `contatos`. Nenhuma integração.

## Contexto e decisões fechadas

- **Estado atual:**
  - Para entender um cliente, o vendedor gera relatórios no FOCCO e lembra das conversas de cabeça.
  - O histórico de contatos não fica registrado; cerca de 70% acontece no WhatsApp pessoal ou do setor (1ª Consultoria).
  - Não existe tela que mostre família abandonada, pendências e evolução de compras juntas.
- **Estado desejado:** uma tela por cliente reúne cadastro, contatos, indicadores, gráfico de 24 meses, mix por família e itens-chave, pendências abertas e linha do tempo. O vendedor registra em poucos cliques cada contato feito por telefone, WhatsApp, Teams, e-mail ou visita, e mantém os contatos atualizados.
- **Decisões já fechadas:**
  - **Rota:** `/clientes/:id`. Abre a partir da Carteira, da busca global ou de link direto (respeitando o RLS: cliente fora da carteira → "Cliente não encontrado").
  - **Registro manual:** na fase 1 todo contato é registrado manualmente, inclusive os de WhatsApp. A integração com o WhatsApp é da fase 2.
  - **Linha do tempo:** junta `interacoes` e `historico_carteira`. Ações concluídas (SPEC-1-007) e ocorrências (SPEC-1-010) entram depois na mesma linha do tempo; mensagens de WhatsApp, na fase 2.
  - **Fora desta SPEC:** sinais e ações na ficha e botão "Nova ação" (SPEC-1-007), botão "Abrir ocorrência" (SPEC-1-010). Fora da fase 1: "Iniciar conversa" (WhatsApp) e resumo por IA (fase 2). Esses botões não aparecem até a SPEC que os entrega.
  - **Telefones:** o botão de WhatsApp de cada contato abre `https://wa.me/<telefone normalizado>` em nova aba. É um atalho de navegador, não uma integração.
  - **Interações:** depois de gravadas, só o autor edita em até 24 h. Ninguém apaga (histórico comercial). A supervisora pode marcar uma interação como "anulada", com motivo.
- **Bloqueios:** nenhum.

## Resultado observável

Ao abrir a ficha da Tonini, o vendedor vê:

- que o cliente está "Em queda" (−70%);
- que parou de comprar pistão linha pesada desde 15/08;
- que a média caiu de R$ 10.000 para R$ 3.000;
- que há 4 peças pendentes há 36 dias;
- quando foi o último contato registrado.

Ele liga, registra "Telefone · saída · cliente vai fazer pedido na semana que vem" e a interação aparece na hora na linha do tempo e na coluna "Última interação" da Carteira.

## Limites e dependências

- **Inclui:**
  - tabela `interacoes` com RLS;
  - políticas de escrita em `contatos`;
  - recriação de `vw_carteira` com `ultima_interacao`;
  - rota `/clientes/:id` com cabeçalho, KPIs, gráfico, mix, itens-chave, pendências, contatos editáveis, linha do tempo e modal "Registrar contato";
  - auditoria em `contatos` e `interacoes`.
- **Fora de escopo:** os itens listados em "Fora da fase 1" acima; edição de dados vindos do FOCCO (cadastro, faturamento, pendências); exclusão de contatos de origem FOCCO.
- **Entradas e pré-condições:** SPECs 1-001, 1-002 e 1-003 (tasks 1.10 e 1.11) concluídas; SPEC-1-004 (task 1.13) para a navegação a partir da Carteira e para `vw_carteira`.
- **Saídas/artefatos:** migração SQL; tela; evidências em `05_entregas/fase-1/SPEC-1-005/`.
- **Dependências e responsáveis:** Marco constrói no Skip e no Supabase, com orientação da consultora Kimberly; Ângela valida com 3 clientes reais escolhidos por ela.
- **Atores e permissões mínimas:**

| Ator | Ver ficha | Registrar interação | Editar interação | Anular interação | Criar ou editar contato manual |
|---|---|---|---|---|---|
| vendedor | própria carteira | própria carteira | as próprias, até 24 h | — | própria carteira |
| supervisora | todas | todas | as próprias, até 24 h | ✔ (com motivo) | todas |
| diretoria | todas (leitura) | — | — | — | — |
| admin | todas (leitura) | — | — | — | — |
| pcp | — | — | — | — | — |

- **Superfícies/arquivos/configurações afetadas:** Supabase: tabela `interacoes`, políticas `insert` e `update` em `contatos` e `interacoes`, gatilhos de auditoria, `vw_carteira` (recriada), função `registrar_interacao`; Skip: rota `/clientes/:id` e componentes.
- **Risco e plano B:** se a ficha passar de 2 s, as seções abaixo da dobra (linha do tempo e mix) carregam depois dos KPIs.
- **Rollback ou reversão:** as tabelas e políticas novas têm script de reversão. Interações gravadas são exportadas antes de qualquer reversão (`copy` para CSV em `05_entregas/fase-1/SPEC-1-005/backup-interacoes.csv`).

## Dados e integrações

Sem integração externa (o link `wa.me` só abre o navegador).

**Tabela `interacoes`** (RLS ativada e forçada; auditoria):

| Campo | Tipo e regra |
|---|---|
| `id` | uuid PK |
| `cliente_id` | FK `clientes`, obrigatório |
| `contato_id` | FK `contatos`, opcional (deve ser do mesmo cliente — check por gatilho) |
| `usuario_id` | FK `perfis`, preenchido pela função com `perfil_atual_id()` |
| `canal` | check (`whatsapp`,`telefone`,`teams`,`email`,`visita`) |
| `direcao` | check (`entrada`,`saida`) |
| `resumo` | text, 5 a 1.000 caracteres |
| `data_hora` | timestamptz, obrigatório, não futura (tolerância de 5 min), no máximo 30 dias para trás |
| `origem` | check (`manual`,`automatica`,`ia`), default `manual` (as outras origens são usadas a partir da fase 2) |
| `anulada` | boolean default false · `anulada_motivo` text · `anulada_por` FK perfis |
| `criado_em`, `atualizado_em` | timestamptz |

Índice: (`cliente_id`, `data_hora` desc).

**Função `registrar_interacao(cliente_id, contato_id, canal, direcao, resumo, data_hora)`** (`security invoker`): valida as regras acima e insere. É a única forma de escrita usada pela interface.

**Políticas:**

| Tabela | select | insert | update |
|---|---|---|---|
| `interacoes` | mesma regra de `clientes` (vendedor só a própria carteira; gestão tudo) | `papel_atual() in ('vendedor','supervisora')` e cliente visível ao usuário | autor e `criado_em > now() − 24h` (campos `canal`, `direcao`, `resumo`, `contato_id`, `data_hora`); supervisora somente nos campos de anulação |
| `contatos` | (SPEC-1-002) | `papel_atual() in ('vendedor','supervisora')`, cliente visível, `origem = 'manual'` | contatos do cliente visível; em contatos `origem = 'focco'` só os campos `nome`, `cargo` e `principal` (telefone e e-mail do FOCCO são mantidos pelo FOCCO) |

**Recriação de `vw_carteira`:** `ultima_interacao` passa a ser `max(data_hora)` de `interacoes` não anuladas do cliente.

| Regra de negócio | Condição | Ação/resultado | Exceção | Fonte |
|---|---|---|---|---|
| RN-01 | Cabeçalho | Fundo grafite `#111213`: nome fantasia (Montserrat 700, 28 px, branco), razão social e código FOCCO, cidade/UF, badge de mercado, vendedor responsável, badge de situação comercial; selo "Bloqueado no FOCCO" quando `situacao_focco = 'bloqueado'` | — | §9.4 |
| RN-02 | KPIs | 6 cartões: Média 6m (R$ e peças), Média recente, Variação (%, cor pela situação), Ticket médio, Dias sem compra, Intervalo médio de compra ("a cada {n} dias") | Valor null → "—" com dica "Histórico insuficiente" | §9.4 |
| RN-03 | Gráfico | Barras do valor mensal de 24 meses (`metricas_cliente_mensal`) em ardósia, mês atual em vermelho `#ED1C24` com rótulo "parcial", linha tracejada teal com a média de referência; alternância R$ / peças; tooltip com mês, valor, peças e notas | — | §9.4 |
| RN-04 | Mix por família | Tabela de `metricas_cliente_familia` (exceto `sem_historico`): família, valor 12 meses, participação (barra), meses com compra na referência (x/6), última compra, badge "Ativa" ou "Abandonada" (vermelho) | — | §9.4, §8.2 |
| RN-05 | Itens-chave | Lista de `metricas_cliente_item_chave`: código, descrição, participação, última compra, dias sem compra; destaque vermelho quando `abandonado` | Nenhum item-chave → seção oculta | §8.2 |
| RN-06 | Pendências | Pendências `aberta` do cliente: pedido, item, quantidade pendente, data do pedido e dias em aberto (vermelho quando > 30 dias) | Sem pendências → seção oculta | §9.4 |
| RN-07 | Contatos | Lista com nome, cargo, telefone formatado (`(51) 99999-9999`), e-mail, selo "Principal" e origem; botão WhatsApp (`wa.me`) quando é celular, `tel:` quando fixo, `mailto:` para e-mail; "Adicionar contato" (nome obrigatório e, no mínimo, telefone ou e-mail; telefone passa por `normalizar_telefone`) | Telefone já cadastrado em outro cliente → erro "Este telefone já está no cliente {nome}." | §7.1, §6.2 |
| RN-08 | Registrar contato | Modal: canal (5 botões com ícone), direção (Recebido / Feito), contato (opcional, lista dos contatos do cliente), data e hora (padrão agora), resumo (obrigatório, contador de caracteres); "Salvar" chama `registrar_interacao` | Erros de validação mostrados no campo | §7.3, D9 |
| RN-09 | Linha do tempo | Feed por `data_hora` decrescente: ícone do canal, autor, data relativa ("há 2 dias") com a data completa no tooltip, resumo; entradas de `historico_carteira` com ícone de troca ("Carteira transferida de X para Y"); filtro por canal; paginação de 20 em 20; interações anuladas aparecem riscadas com o motivo | — | §9.4 |
| RN-10 | Navegação | "Voltar para a Carteira" mantém os filtros (URL da SPEC-1-004) | — | usabilidade |

## Fluxo e regras

1. O vendedor clica num cliente na Carteira. `/clientes/:id` carrega o cabeçalho e os KPIs primeiro (skeleton) e, em seguida, o gráfico, o mix, os itens-chave, as pendências, os contatos e a linha do tempo.
2. **Layout em computador:**
   - coluna principal (2/3): KPIs, gráfico, mix, itens-chave, pendências e linha do tempo;
   - coluna lateral (1/3): contatos e o botão primário vermelho "Registrar contato".
3. **No celular:** uma coluna, com "Registrar contato" fixo no rodapé.
4. "Registrar contato" → modal (RN-08) → "Salvar". Em seguida:
   - toast "Contato registrado";
   - o item aparece no topo da linha do tempo sem recarregar a página;
   - `ultima_interacao` da Carteira passa a refletir o registro.
5. "Adicionar contato" → formulário lateral → "Salvar" → contato aparece na lista.
6. **Estados:**
   - cliente inexistente ou fora da carteira → "Cliente não encontrado" e "Voltar para a Carteira";
   - erro de rede → "Não foi possível carregar a ficha." e "Tentar de novo".

| Cenário | Dado/condição | Resultado esperado | Caminho de erro/recuperação |
|---|---|---|---|
| Principal | Ficha de C001 da fixture | Situação "Em queda", variação −70,0%, `pistao_pesada` "Abandonada", item I2 como item-chave não abandonado | — |
| Principal | Registrar telefone, saída, resumo de 40 caracteres | Interação salva e no topo da linha do tempo; "Última interação" na Carteira = hoje | — |
| Limite | Resumo com 4 caracteres | Bloqueado: "Escreva pelo menos 5 caracteres." | Completar |
| Limite | Data e hora no futuro | Bloqueado: "A data não pode estar no futuro." | Corrigir |
| Limite | Pendência aberta há 36 dias | "36 dias" em vermelho | — |
| Falha | Vendedor abre a URL de cliente de outro vendedor | "Cliente não encontrado" | — |
| Falha | Vendedor tenta editar interação de 2 dias atrás | Botão "Editar" ausente; update direto no banco é recusado pelo RLS | — |
| Falha | Diretoria tenta registrar contato | Botão ausente; insert direto recusado pelo RLS | — |

## Instruções de execução para o Ethos

1. **Ler antes de alterar:** `02-Escopo-Definitivo.md` §7.1, §7.3, §9.4 e §12.2; SPECs 1-001 a 1-004; esta SPEC.
2. **Alterar somente:** migração de `interacoes`, `registrar_interacao`, políticas de `contatos`, gatilhos de auditoria, recriação de `vw_carteira`; a rota `/clientes/:id` e a página provisória da SPEC-1-004 (substituída pela ficha).
3. **Não alterar:** tabelas e regras de importação; métricas; colunas da `vw_carteira` (somente a origem de `ultima_interacao`).
4. **Executar nesta ordem:**
   1. Migração.
   2. Testes de RLS (GREEN 1 e 2).
   3. Cabeçalho e KPIs.
   4. Gráfico.
   5. Mix e itens-chave.
   6. Pendências.
   7. Contatos.
   8. Registrar contato.
   9. Linha do tempo.
   10. Celular.
   11. Validação com 3 clientes reais.
5. **Parar e pedir validação quando:** a Ângela pedir campo ou seção fora desta SPEC; ou algum número da ficha divergir de `metricas_cliente_atual`.
6. **Estado válido ao parar:** a ficha abre sem erro e mostra ao menos cabeçalho e KPIs.

## Checklist de execução

- [ ] `interacoes`, `registrar_interacao`, políticas e auditoria criadas
- [ ] `vw_carteira` recriada com `ultima_interacao`
- [ ] Cabeçalho, KPIs, gráfico, mix, itens-chave e pendências
- [ ] Contatos com criação manual e atalhos WhatsApp, telefone e e-mail
- [ ] Modal Registrar contato e linha do tempo com filtro e paginação
- [ ] Versão celular (390 px)
- [ ] Validação com 3 clientes reais
- [ ] Evidências salvas em `05_entregas/fase-1/SPEC-1-005/`

## Critérios de aceite

- [ ] **CA-1-21:** Na fixture, a ficha de C001 mostra média 6m R$ 10.000, média recente R$ 3.000, variação −70,0%, 22 dias sem compra, intervalo "a cada 30 dias", `pistao_pesada` Abandonada e I2 como item-chave; os números são idênticos aos de `metricas_cliente_atual`.
- [ ] **CA-1-22:** Registrar um contato leva no máximo 3 cliques depois de abrir a ficha (abrir modal → escolher canal → salvar, com resumo digitado) e aparece na linha do tempo e na coluna "Última interação" da Carteira.
- [ ] **CA-1-23:** Pelo banco, um vendedor não lê nem grava interações ou contatos de clientes de outra carteira; a diretoria não grava; a edição pelo autor é recusada depois de 24 h.
- [ ] **CA-1-24:** As pendências abertas do cliente aparecem com os mesmos pedidos, itens e quantidades da tabela `pendencias`, e os dias em aberto ficam em vermelho acima de 30.
- [ ] **CA-1-25:** A Ângela confirma, para 3 clientes reais escolhidos por ela, que o gráfico de 24 meses e o mix conferem com o FOCCO (registro em `validacao.md`).

## TDD da SPEC

| Etapa | Prova | Comando/ação | Resultado esperado | Evidência |
|---|---|---|---|---|
| RED 1 | Tabela inexistente | `select registrar_interacao(...)` | Erro "function does not exist" | `red.txt` |
| GREEN 1 | RLS de leitura e escrita | Como vendedor A: `select count(*) from interacoes where cliente_id = '<cliente do vendedor B>'` e `select registrar_interacao('<cliente do vendedor B>', null, 'telefone', 'saida', 'teste de permissão', now())`; como diretoria, o mesmo insert no cliente de A | 0; erro de permissão; erro de permissão | `rls.txt` |
| GREEN 2 | Janela de edição | Inserir interação com `criado_em` ajustado para 25 h atrás (branch de teste) e tentar `update` como autor | Recusado | `edicao.txt` |
| GREEN 3 | Ficha da fixture | Abrir C001 da fixture com D = 06/11/2026 | Valores do CA-1-21 | Capturas |
| GREEN 4 | Registro em 3 cliques | Gravação de tela: abrir modal, canal Telefone, digitar resumo, Salvar | Toast; topo da linha do tempo; Carteira com "Última interação" = hoje | Vídeo curto ou 3 capturas |
| GREEN 5 | Pendências | Fixture: pendência 30677 (C002, `PS 864 S STD`, 4 un, desde 01/10/2026), D = 06/11/2026 | Linha com "36 dias" em vermelho; igual a `select * from pendencias where situacao='aberta'` do cliente | Captura |
| REFACTOR/REGRESSÃO | Bordas | Resumo curto, data futura, telefone duplicado em outro cliente, URL de cliente de outra carteira, interação anulada pela supervisora, celular 390 px | Comportamentos da tabela de cenários | Capturas |

**Dados/fixtures:** fixture da SPEC-1-003 + pendência da SPEC-1-002 em ambiente de teste; 3 clientes reais para o CA-1-25.  
**Caminhos de erro obrigatórios:** permissão de leitura e escrita, edição fora da janela, validação de resumo e data, telefone duplicado, cliente não encontrado, erro de rede.  
**Evidência exigida:** arquivos citados em `05_entregas/fase-1/SPEC-1-005/`.

## Handoff e operação

- **Como demonstrar:**
  1. Ângela abre a ficha de um cliente em queda.
  2. Ela mostra a família abandonada e a pendência antiga.
  3. Ela registra um contato telefônico ao vivo e volta à Carteira mostrando a "Última interação".
- **Como operar depois:** toda conversa relevante com o cliente, em qualquer canal, é registrada na ficha. A supervisora confere semanalmente os clientes "Em queda" sem interação recente pela Carteira (filtro "Situação" + ordenação por "Última interação").
- **Como monitorar:** coluna "Última interação" na Carteira.
- **Pendência conhecida:** nenhuma.

## Tasks vinculadas

| ID | Task | Dono | SPEC | Critério | Recorte da prova | Evidência esperada | Pré-condições | Status |
|---|---|---|---|---|---|---|---|---|
| 1.16 | Criar `interacoes`, `registrar_interacao`, políticas de `contatos` e `interacoes`, auditoria e recriar `vw_carteira` | Marco Carvalho | SPEC-1-005 | CA-1-23 | RED 1 → GREEN 1, GREEN 2 | `rls.txt`, `edicao.txt` | 1.05 e 1.13 concluídas | ☐ |
| 1.17 | Construir cabeçalho, KPIs, gráfico de 24 meses, mix por família, itens-chave e pendências da ficha | Marco Carvalho | SPEC-1-005 | CA-1-21, CA-1-24 | GREEN 3, GREEN 5 | Capturas de C001 e da pendência | 1.11 concluída; 1.03 concluída | ☐ |
| 1.18 | Construir contatos editáveis, modal Registrar contato e linha do tempo | Marco Carvalho | SPEC-1-005 | CA-1-22 | GREEN 4 e REGRESSÃO | Vídeo/capturas do registro e das bordas | 1.16 concluída | ☐ |
| 1.19 | Validar a ficha de 3 clientes reais com o FOCCO | Ângela Ferreira | SPEC-1-005 | CA-1-25 | GREEN 3 com dados reais | `validacao.md` com os 3 clientes e o resultado | 1.08, 1.17 e 1.18 concluídas | ☐ |

## Emendas

<!-- Append-only (D19): mudanças aprovadas depois da geração. A história não é reescrita. -->

| Data | Origem do sinal | Micro-spec/task | Motivo |
|---|---|---|---|
| | | | |
