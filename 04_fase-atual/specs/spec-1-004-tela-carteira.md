# SPEC-1-004 — Tela Carteira e Top clientes por UF

**Fase:** 1  
**Status:** planejada  
**Dono:** Marco Carvalho (TI Platina) · **Consultoria:** Kimberly Prestes (Adapta)  
**Origem no escopo:** `02-Escopo-Definitivo.md` §9.3 (Carteira), §4.2 (permissões), §12.3 (desempenho), §12.4 (usabilidade), critério de aceite da fase 1 ("Top clientes por UF")  
**Degrau da solução:** construção mínima no Skip sobre as tabelas e views prontas da SPEC-1-003, com componentes shadcn/ui e Recharts (biblioteca de gráficos padrão do Skip); nenhuma integração.

## Contexto e decisões fechadas

- **Estado atual:**
  - Para ver a situação de um cliente, o vendedor gera no FOCCO o relatório *COM – Vendas por Classificação*, cliente por cliente e período por período (vídeo *Monitoramento da carteira*, 01:15–05:19: cerca de 3 min de tela por consulta).
  - Não existe visão da carteira inteira.
- **Estado desejado:** uma tela lista a carteira com a situação de cada cliente, permite filtrar e ordenar, exporta para Excel e mostra o Top clientes por UF pronto. Ela substitui a consolidação manual da coordenação.
- **Decisões já fechadas:**
  - **Rota:** `/carteira`. Esta é a tela inicial de vendedor, supervisora e diretoria na fase 1 (SPEC-1-001).
  - **Dados:** a tela lê `vw_carteira`, criada nesta SPEC: `clientes` + `metricas_cliente_atual` + nome do vendedor + `ultima_interacao`. Nesta SPEC a coluna é criada como `null::timestamptz`; a SPEC-1-005 recria a view com o máximo de `interacoes.data_hora` do cliente, sem mudar o nome nem a ordem das colunas + `tem_celular` (existe contato com `celular = true`). A view usa `security_invoker = true`, então o RLS de `clientes` vale automaticamente.
  - **Paginação no servidor:** 50 linhas por página. Ordenação e filtros também no servidor (consulta Supabase com `.order`, `.range` e filtros).
  - **Exportar Excel:** gerado no navegador com SheetJS (mesma biblioteca da SPEC-1-002), contendo **todas** as linhas do filtro atual (até 5.000) e as mesmas colunas da tela.
  - **Sparkline:** valores mensais dos últimos 12 meses de `metricas_cliente_mensal`, buscados em uma única consulta para os clientes da página.
  - **Coluna "Sinais ativos":** fica fora desta SPEC; é acrescentada pela SPEC-1-006.
- **Bloqueios:** nenhum.

## Resultado observável

O vendedor abre a Carteira e vê só os seus clientes, com situação, médias, variação, dias sem compra e minigráfico. Ele filtra "Em queda" e ordena por variação. A supervisora vê todas as carteiras, filtra por vendedor e UF, exporta a lista e abre a aba **Top clientes por UF**, que já traz a média dos últimos 6 meses fechados dos 3 maiores clientes de cada estado.

## Limites e dependências

- **Inclui:**
  - view `vw_carteira`;
  - rota `/carteira` com faixa de resumo, filtros, tabela, sparkline, paginação e exportação;
  - aba Top clientes por UF;
  - busca global de clientes na barra superior (atalho Ctrl+K / ⌘K);
  - estados vazio, carregando e erro.
- **Fora de escopo:**
  - ficha do cliente (SPEC-1-005; a linha da tabela apenas navega para `/clientes/:id`);
  - sinais e ações (SPECs 1-006 e 1-007);
  - reatribuição de carteira (SPEC-1-008);
  - painéis de gestão (SPEC-1-012).
- **Entradas e pré-condições:**
  - SPEC-1-001 aceita (casca, papéis);
  - SPEC-1-003 com as tasks 1.10 e 1.11 concluídas (métricas e views);
  - base real carregada (task 1.08).
- **Saídas/artefatos:** view SQL; tela; evidências em `05_entregas/fase-1/SPEC-1-004/`.
- **Dependências e responsáveis:** Marco constrói no Skip e no Supabase, com orientação da consultora Kimberly; Ângela valida com um vendedor (Marcio ou Camila) e consigo mesma.
- **Atores e permissões mínimas:**

| Ator | Vê | Filtro "Vendedor" |
|---|---|---|
| vendedor | somente os próprios clientes | oculto |
| supervisora, diretoria, admin | todos os clientes | visível |
| pcp | não acessa (menu oculto; a rota redireciona para `/lotes`) | — |

- **Superfícies/arquivos/configurações afetadas:** Supabase: `vw_carteira` e índice `clientes(vendedor_id)`; Skip: rota `/carteira`, componente de busca global na barra superior.
- **Risco e plano B:** com mais de 3.000 clientes, se a ordenação por coluna calculada ficar lenta, cria-se índice em `metricas_cliente_atual(situacao_comercial, variacao)`.
- **Rollback ou reversão:** a tela e a view podem ser removidas sem afetar dados.

## Dados e integrações

Sem integração externa. Fonte de verdade: `clientes`, `metricas_cliente_atual`, `metricas_cliente_mensal`, `vw_top_clientes_uf`, `vw_media_movel_cliente` e `perfis`.

**Colunas da tabela**

| Coluna | Origem | Formato |
|---|---|---|
| Cliente | `nome_fantasia` (ou `razao_social` quando vazio) + `codigo_focco` em cinza, abaixo | texto |
| Cidade/UF | `cidade` – `uf` | texto |
| Mercado | `mercado` | Reposição direta · Reposição indireta · Indústria · Exportação |
| Situação | `situacao_comercial` | badge: Ativo verde, Em atenção âmbar, Em queda vermelho, Inativo cinza |
| Média 6m | `media_ref_valor` | R$ sem centavos (ex.: R$ 10.000) |
| Média recente | `media_recente_valor` | R$ sem centavos |
| Variação | `variacao` | % com 1 casa; seta ↑ verde (> 0), ↓ vermelha (< 0), "—" quando null |
| Últimos 12 meses | `metricas_cliente_mensal` | sparkline em ardósia `#2C3E50`, 80 × 24 px, sem eixos |
| Dias sem compra | `dias_sem_compra` | inteiro; vermelho quando ≥ 60 |
| Última interação | `ultima_interacao` | dd/mm/aaaa ou "—" |
| Vendedor | `perfis.nome` | texto (somente para gestão) |

| Regra de negócio | Condição | Ação/resultado | Exceção | Fonte |
|---|---|---|---|---|
| RN-01 | Faixa de resumo | 4 pills com contagem por situação no conjunto visível ao usuário; clicar filtra a tabela; clicar de novo remove o filtro | — | §9.3 |
| RN-02 | Filtros | Vendedor (gestão), UF (múltipla), Mercado (múltipla), Situação (múltipla), "Família abandonada" (lista das famílias; usa `familias_abandonadas`), "Sem celular cadastrado" (`tem_celular = false`), "Sem compra há mais de X dias" (número) e busca por nome, razão social, código ou CNPJ | Filtros combinam com E | §9.3, §6.1 |
| RN-03 | Ordenação padrão | Situação (queda → atenção → ativo → inativo), depois `media_ref_valor` decrescente | O usuário ordena por qualquer coluna, exceto sparkline | §9.3 |
| RN-04 | Persistência | Filtros e ordenação ficam na URL (query string), para compartilhar o link e manter ao voltar da ficha | — | usabilidade |
| RN-05 | Exportar | Botão "Exportar Excel" gera `carteira-aaaa-mm-dd.xlsx` com as linhas do filtro (até 5.000) e as colunas da tabela, exceto a sparkline, com valores numéricos reais | Acima de 5.000 → aviso "Refine os filtros para exportar até 5.000 clientes" | §9.3 |
| RN-06 | Top por UF | Aba com um cartão por UF (ordem alfabética), cada um listando os 3 clientes de `vw_top_clientes_uf` com posição, nome, média 6 meses fechados (R$ e peças) e mini gráfico de linha da média móvel de 6 meses (12 pontos, `vw_media_movel_cliente`) | Vendedor vê somente os próprios clientes no ranking (RLS); o título diz "Seus maiores clientes por UF" | §9.3, critério da fase 1 |
| RN-07 | Busca global | Ctrl+K / ⌘K ou clique na lupa da barra superior abre uma caixa de busca; a partir de 2 caracteres, mostra até 8 clientes (nome, código, UF e badge de situação) dentro do que o usuário pode ver; Enter ou clique abre `/clientes/:id` | Sem resultado → "Nenhum cliente encontrado" | §9 (barra superior) |
| RN-08 | Desempenho | A primeira página com resumo aparece em até 2 s com a base real | — | §12.3 |
| RN-09 | Linha clicável | Clicar na linha abre `/clientes/:id` (SPEC-1-005); antes da SPEC-1-005, abre uma página com o nome do cliente e o texto "Ficha em construção" | — | — |

## Fluxo e regras

1. O usuário entra em `/carteira`. O cabeçalho mostra o título "Carteira", o subtítulo "{n} clientes · dados atualizados até dd/mm hh:mm" e o botão "Exportar Excel".
2. Logo abaixo ficam a faixa de resumo (RN-01) e duas abas: **Clientes** (padrão) e **Top clientes por UF**.
3. Aba Clientes:
   - barra de filtros (RN-02), com o botão "Limpar filtros";
   - tabela (colunas acima) com skeleton enquanto carrega;
   - paginação "1–50 de 312".
4. No celular, a tabela vira lista de cartões com nome, situação, média 6m, variação e dias sem compra; os filtros ficam numa gaveta.
5. Aba Top clientes por UF: grade de cartões (RN-06). No topo, o texto "Média dos últimos 6 meses fechados ({mês inicial} a {mês final}), como no fechamento da coordenação."
6. Estados:
   - **vazio sem dados carregados:** "Ainda não há dados do FOCCO. Peça ao administrador para importar as planilhas." (com link para Importações quando o usuário é admin);
   - **vazio por filtro:** "Nenhum cliente com esses filtros." + "Limpar filtros";
   - **erro de rede:** "Não foi possível carregar a carteira." + "Tentar de novo".

| Cenário | Dado/condição | Resultado esperado | Caminho de erro/recuperação |
|---|---|---|---|
| Principal | Vendedor com 80 clientes | Vê 80; filtro Vendedor oculto | — |
| Principal | Supervisora filtra "Em queda" + UF RS | Somente clientes em queda do RS; URL com os filtros | — |
| Limite | Variação null | Mostra "—" e fica no fim quando ordenado por variação | — |
| Limite | Exportar 6.000 linhas | Aviso de limite; nenhum arquivo gerado | Refinar filtros |
| Falha | Rede cai ao paginar | Mensagem de erro com "Tentar de novo"; filtros mantidos | — |
| Falha | PCP digita `/carteira` | Redirecionado para `/lotes` | — |

## Instruções de execução para o Ethos

1. **Ler antes de alterar:** `02-Escopo-Definitivo.md` §9.3; SPEC-1-001 (identidade visual e casca); SPEC-1-003 (tabelas e views); esta SPEC.
2. **Alterar somente:** `vw_carteira`, o índice, a rota `/carteira`, a busca global e a página provisória da RN-09.
3. **Não alterar:** a lógica das métricas (SPEC-1-003); RLS de `clientes`; a casca, além de inserir a busca.
4. **Executar nesta ordem:**
   1. View e teste de RLS.
   2. Tabela com filtros e ordenação.
   3. Resumo.
   4. Sparkline.
   5. Exportação.
   6. Top por UF.
   7. Busca global.
   8. Versão celular.
   9. Validação com usuários.
5. **Parar e pedir validação quando:** a primeira página demorar mais de 2 s com a base real depois do índice; ou a Ângela pedir coluna ou filtro que não esteja nesta SPEC (vira emenda).
6. **Estado válido ao parar:** a tela abre sem erro com qualquer combinação de filtros já implementada.

## Checklist de execução

- [ ] `vw_carteira` criada com `security_invoker = true`
- [ ] Tabela, resumo, filtros, ordenação, paginação e URL com estado
- [ ] Sparkline dos últimos 12 meses
- [ ] Exportação em Excel com limite de 5.000
- [ ] Aba Top clientes por UF
- [ ] Busca global Ctrl+K
- [ ] Versão celular (390 px)
- [ ] Validação com 1 vendedor e com a supervisora
- [ ] Evidências salvas em `05_entregas/fase-1/SPEC-1-004/`

## Critérios de aceite

- [ ] **CA-1-16:** Logado como vendedor, a Carteira mostra exatamente o número de clientes com `vendedor_id` igual ao seu perfil; como supervisora, mostra o total de clientes.
- [ ] **CA-1-17:** Filtrar "Em queda" mostra exatamente os clientes com `situacao_comercial = 'queda'` visíveis ao usuário, e a contagem da pill confere com `select count(*)` equivalente.
- [ ] **CA-1-18:** O Excel exportado tem as mesmas linhas e valores do filtro aplicado na tela.
- [ ] **CA-1-19:** A aba Top clientes por UF mostra, para cada UF, os mesmos clientes e valores de `vw_top_clientes_uf` (conferidos pela Ângela na task 1.12).
- [ ] **CA-1-20:** A primeira página da Carteira, com resumo, carrega em até 2 s com a base real (medido no navegador do escritório).

## TDD da SPEC

| Etapa | Prova | Comando/ação | Resultado esperado | Evidência |
|---|---|---|---|---|
| RED 1 | View inexistente | `select count(*) from vw_carteira` | Erro "relation does not exist" | `red.txt` |
| GREEN 1 | RLS na view | Como vendedor e como supervisora (técnica da SPEC-1-001): `select count(*) from vw_carteira` | Vendedor = clientes dele; supervisora = total | `rls.txt` |
| GREEN 2 | Filtro e contagem | Na tela, aplicar "Em queda"; no SQL, `select count(*) from vw_carteira where situacao_comercial='queda'` com o mesmo usuário | Mesmo número | Captura + `contagem.txt` |
| GREEN 3 | Exportação | Exportar com filtro UF = RS; comparar número de linhas e soma de "Média 6m" com o SQL equivalente | Iguais | `exportacao.xlsx` + `export.txt` |
| GREEN 4 | Top por UF | Comparar a aba com `select * from vw_top_clientes_uf` | Iguais | Captura + `top.txt` |
| GREEN 5 | Desempenho | DevTools › Network: tempo até a tabela renderizada, 3 medições | ≤ 2 s em todas | `desempenho.png` |
| REFACTOR/REGRESSÃO | Bordas | Variação null, filtro sem resultado, exportação acima de 5.000 (forçada em teste), PCP acessando `/carteira`, celular 390 px | Comportamentos da tabela de cenários | 5 capturas |

**Dados/fixtures:** a fixture da SPEC-1-003 (6 clientes) para GREEN 1 a 4 em ambiente de teste; a base real para GREEN 5 e para a validação com usuários.  
**Caminhos de erro obrigatórios:** sem dados, filtro vazio, erro de rede, limite de exportação, acesso de papel sem permissão.  
**Evidência exigida:** arquivos citados em `05_entregas/fase-1/SPEC-1-004/`.

## Handoff e operação

- **Como demonstrar:**
  1. Marcio (vendedor) abre a Carteira, filtra "Em queda" e ordena por variação.
  2. Ângela filtra RS, exporta e mostra o Top por UF ao lado da planilha antiga.
- **Como operar depois:** uso diário pelos vendedores; Ângela usa o Top por UF no fechamento mensal no lugar da planilha.
- **Como monitorar:** "Último acesso" dos usuários na Administração.
- **Pendência conhecida:** nenhuma.

## Tasks vinculadas

| ID | Task | Dono | SPEC | Critério | Recorte da prova | Evidência esperada | Pré-condições | Status |
|---|---|---|---|---|---|---|---|---|
| 1.13 | Criar `vw_carteira` e a tela Carteira (resumo, filtros, ordenação, paginação, sparkline, exportação, versão celular) | Marco Carvalho | SPEC-1-004 | CA-1-16, CA-1-17, CA-1-18, CA-1-20 | RED 1 → GREEN 1, GREEN 2, GREEN 3, GREEN 5 | `rls.txt`, `contagem.txt`, `exportacao.xlsx`, `desempenho.png` | 1.03 e 1.11 concluídas | ☐ |
| 1.14 | Construir a aba Top clientes por UF e a busca global Ctrl+K | Marco Carvalho | SPEC-1-004 | CA-1-19 | GREEN 4 e REGRESSÃO (busca sem resultado) | `top.txt` + capturas | 1.11 concluída; 1.03 concluída | ☐ |
| 1.15 | Validar a Carteira com um vendedor e com a supervisora na base real | Ângela Ferreira | SPEC-1-004 | CA-1-16, CA-1-17 | GREEN 1 e GREEN 2 com usuários reais | Capturas das duas visões + observações em `05_entregas/fase-1/SPEC-1-004/validacao.md` | 1.08, 1.13 e 1.14 concluídas | ☐ |

## Emendas

<!-- Append-only (D19): mudanças aprovadas depois da geração. A história não é reescrita. -->

| Data | Origem do sinal | Micro-spec/task | Motivo |
|---|---|---|---|
| | | | |
