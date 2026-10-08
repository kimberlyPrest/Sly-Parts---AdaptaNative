# SPEC-1-002 — Base comercial e importação de arquivos do FOCCO

**Fase:** 1  
**Status:** planejada  
**Dono:** Marco Carvalho (TI Platina) · **Consultoria:** Kimberly Prestes (Adapta)  
**Origem no escopo:** `02-Escopo-Definitivo.md` §6.1 (dados lidos, carga inicial, plano B, qualidade de dados), §7.1, §7.2 e §7.7 (modelo de dados), §9.12 (Importações), D3, D5  
**Degrau da solução:** construção mínima sobre recurso nativo — tabelas e funções SQL no Supabase e leitura de planilha no navegador com SheetJS; nenhum serviço extra.

## Contexto e decisões fechadas

- **Estado atual:**
  - O histórico comercial existe somente no FOCCO e é consultado tela a tela: relatório *COM – Vendas por Classificação* e relatório de pendências.
  - Cada consulta passa pelo Java WebStart, com 13 a 41 s de espera (vídeo *Monitoramento da carteira*, 01:50–03:52).
  - A documentação da API do FOCCO ainda não foi entregue.
- **Estado desejado:**
  - A Central Sly tem a base comercial completa (clientes, contatos, itens, 24 meses de faturamento, pendências, curva e lote mínimo dos itens), carregada por arquivo pela tela Administração › Importações.
  - Cada carga é validada linha a linha, mostra prévia e erros e só grava depois de confirmada.
  - Na fase 1 esta é a **única** forma de entrada de dados do FOCCO. Não há integração automática nesta fase. O conector automático fica para a fase 2 e vai reutilizar estes layouts e funções.
- **Decisões já fechadas:**
  - Cinco **layouts padrão Central Sly** (L1 a L5, abaixo). O arquivo precisa ter **exatamente** esses cabeçalhos, comparados depois de normalizados: minúsculas, sem acento, espaços trocados por `_`. A tela oferece o modelo `.xlsx` de cada layout para download.
  - Formatos aceitos: **.xlsx** (primeira aba) e **.csv** em UTF-8, separado por `;` ou `,` (detectado automaticamente). Tamanho máximo de **25 MB por arquivo**. XML fica fora desta fase: quando o FOCCO exportar só em XML, o TI abre o arquivo no Excel e salva como .xlsx.
  - Datas aceitas em `dd/mm/aaaa` ou `aaaa-mm-dd`. Números com vírgula ou ponto decimal; o separador de milhar é removido.
  - A leitura do arquivo acontece **no navegador** (biblioteca SheetJS `xlsx` 0.20.3, distribuída pelo pacote oficial `https://cdn.sheetjs.com/xlsx-0.20.3/xlsx-0.20.3.tgz`). As linhas são gravadas em lotes de **2.000** na tabela de preparo `importacao_linhas`. Validação e gravação final são feitas por funções SQL, sempre em operações de conjunto e nunca linha a linha no navegador.
  - O faturamento é gravado **por nota e item**, com data de faturamento. A extração em L3 é responsabilidade do TI, a partir de um relatório do FOCCO detalhado por nota ou de uma consulta ao banco do FOCCO. O relatório *Vendas por Classificação* consolidado por período **não** atende L3, porque não tem a data de cada nota.
  - Somente a empresa **1 (Platina/CD)** e a classificação de **produto acabado (código iniciado por `30`)** entram no faturamento.
  - Pendências são sempre tratadas como **fotografia completa**: cada carga substitui a anterior.
  - Ordem obrigatória da carga inicial: L1 clientes → L2 itens → L3 faturamento (em quantos arquivos forem necessários) → L4 pendências → L5 curva e lote mínimo.
- **Bloqueios:** nenhum para construir. A carga real (task 1.09) depende das extrações do TI (task 1.08).

## Resultado observável

O Marco envia pela tela de Importações os arquivos do FOCCO:

- vê a prévia com a contagem de linhas válidas e com erro;
- baixa a lista de erros;
- confirma a carga e vê o histórico com quantidade de linhas, situação e duração;
- consulta na barra superior o indicador "Dados atualizados até dd/mm hh:mm".

A Ângela confere que o faturamento de 3 clientes, num mês fechado, bate com o relatório do FOCCO com diferença zero.

## Limites e dependências

- **Inclui:**
  - tabelas da base comercial e de importação, com RLS;
  - layouts L1–L5;
  - funções `validar_importacao` e `confirmar_importacao`;
  - tela Administração › Importações;
  - modelos para download;
  - indicador de atualização;
  - bucket privado `importacoes`;
  - limpeza de arquivos com mais de 30 dias;
  - carga inicial real.
- **Fora de escopo:**
  - qualquer integração automática com o FOCCO (conector e API ficam para a fase 2);
  - cálculo de métricas (SPEC-1-003);
  - telas de consulta (SPECs 1-004 e 1-005);
  - importação de XML;
  - edição manual de faturamento ou pendências (os dados do FOCCO são somente leitura, D3).
- **Entradas e pré-condições:**
  - SPEC-1-001 aceita (papel `admin` e função `registrar_auditoria()`);
  - extrações nos layouts L1–L5 fornecidas pelo TI;
  - tabela de mercado (abaixo) aplicada como carga inicial de `mapeamento_mercado`.
- **Saídas/artefatos:**
  - migração SQL;
  - tela Importações;
  - 5 modelos `.xlsx`;
  - base carregada;
  - planilha de conferência em `05_entregas/fase-1/SPEC-1-002/conferencia-faturamento.xlsx`.
- **Dependências e responsáveis:** Marco constrói no Skip e no Supabase, com orientação da consultora Kimberly, e extrai e carrega; Ângela confere os totais.
- **Atores e permissões mínimas:**

| Ator | Pode | Não pode |
|---|---|---|
| admin | enviar arquivos, ver prévia, confirmar, cancelar, ver histórico e baixar erros | editar linhas gravadas |
| supervisora, diretoria | ver o histórico de importações (somente leitura) | enviar ou confirmar |
| vendedor, pcp | ver o indicador "Dados atualizados até" | acessar Importações |

- **Superfícies/arquivos/configurações afetadas:**
  - Supabase: tabelas listadas abaixo, funções `normalizar_codigo`, `normalizar_telefone`, `validar_importacao`, `confirmar_importacao`, view `vw_ultima_atualizacao`, bucket `importacoes`, job pg_cron `limpar-importacoes`;
  - Skip: rota `/admin/importacoes`, componente do indicador na barra superior.
- **Risco e plano B:**
  - Arquivo grande demais: dividir o faturamento por trimestre (24 meses = 8 arquivos).
  - Cabeçalho diferente: a prévia aponta as colunas faltantes ou sobrando, e o TI ajusta pelo modelo.
- **Rollback ou reversão:**
  - Cada importação confirmada registra `importacao_id` nas linhas gravadas.
  - A ação "Desfazer importação" fica disponível ao admin por **24 h** e somente para a importação mais recente de cada layout:
    - L3 apaga as linhas inseridas por ela e restaura os valores anteriores das atualizadas, a partir de `importacao_linhas.dados_anteriores`;
    - L4 restaura a fotografia anterior, guardada em `importacao_linhas.dados_anteriores`.
  - A migração tem script de reversão.

## Dados e integrações

### Tabelas (todas com `id uuid` PK, `criado_em`, `atualizado_em`, RLS ativada e forçada, auditoria por `registrar_auditoria()` nas tabelas marcadas com ✱)

| Tabela | Campos e restrições |
|---|---|
| `clientes` ✱ | `codigo_focco` text único obrigatório · `razao_social` text obrigatório · `nome_fantasia` text · `cnpj` text (14 dígitos, sem máscara) · `cidade` text · `uf` char(2) obrigatório (check na lista das 27 UFs) · `tipo_cliente_focco` text · `divisao_venda_focco` text · `mercado` text check (`reposicao_direta`,`reposicao_indireta`,`industria`,`exportacao`) · `mercado_inferido` boolean default false · `mercado_maduro` boolean gerado (`uf in ('SP','RS','MG','SC','PR')`) · `codigo_vendedor_focco` text · `vendedor_id` uuid FK `perfis` · `situacao_focco` text check (`ativo`,`bloqueado`) · `situacao_comercial` text check (`ativo`,`atencao`,`queda`,`inativo`) default `ativo` (preenchida pela SPEC-1-003) · `importacao_id` uuid |
| `contatos` ✱ | `cliente_id` FK `clientes` obrigatório · `nome` text · `cargo` text · `telefone` text (normalizado) único quando preenchido · `celular` boolean · `email` text · `principal` boolean default false · `origem` text check (`focco`,`manual`,`whatsapp`) |
| `itens` ✱ | `codigo_focco` text único obrigatório (normalizado) · `descricao` text obrigatório · `grupo_focco` text · `classificacao` text · `familia` text check (`pistao_leve`,`pistao_pesada`,`pistao_jogos`,`pca`,`kpm`,`pino`,`outros`) · `familia_manual` boolean default false · `curva` char(1) check (`A`,`B`,`C`,`D`) · `lote_minimo` integer ≥ 0 · `ativo` boolean |
| `faturamento_itens` | `empresa` smallint · `numero_nota` text · `serie` text default '' · `data_faturamento` date obrigatório · `cliente_id` FK obrigatório · `item_id` FK obrigatório · `quantidade` numeric(14,3) · `valor_unitario` numeric(14,4) · `valor_total` numeric(14,2) · `numero_pedido` text · `tipo_movimento` text check (`venda`,`devolucao`,`cancelada`) · `importacao_id` uuid · **único** (`empresa`,`numero_nota`,`serie`,`item_id`,`tipo_movimento`) · índices (`cliente_id`,`data_faturamento`) e (`item_id`,`data_faturamento`) |
| `pendencias` | `numero_pedido` text · `cliente_id` FK · `item_id` FK · `quantidade_solicitada` numeric · `quantidade_atendida` numeric · `quantidade_pendente` numeric > 0 · `data_pedido` date · `situacao` text check (`aberta`,`atendida`,`cancelada`) · `encerrada_em` timestamptz · `importacao_id` · **único** (`numero_pedido`,`item_id`) · índice (`cliente_id`,`situacao`) e (`item_id`,`situacao`) |
| `mapeamento_mercado` ✱ | `campo_focco` text check (`tipo_cliente`,`divisao_venda`) · `valor_focco` text · `mercado` text (mesmos valores de `clientes.mercado`) · único (`campo_focco`,`valor_focco`) |
| `historico_carteira` | `cliente_id` · `vendedor_anterior_id` · `vendedor_novo_id` · `alterado_por` (perfil ou null quando importação) · `motivo` text · `criado_em` |
| `feriados` ✱ | `data` date único · `descricao` text — carga inicial com os feriados nacionais de 2026 e 2027 e os municipais de Gravataí/RS |
| `parametros` ✱ | `chave` text único · `valor` jsonb · `descricao` text · `alterado_por` · `alterado_em` — carga inicial nesta SPEC: `vendedor_padrao_id` (perfil da Ângela), `importacao_janela_desfazer_horas` = 24, `importacao_retencao_dias` = 30 |
| `importacoes` | `layout` text check (`L1_clientes`,`L2_itens`,`L3_faturamento`,`L4_pendencias`,`L5_curva_lote`) · `origem` text default `arquivo` (a fase 2 acrescenta a origem do conector) · `nome_arquivo` text · `caminho_storage` text · `enviado_por` FK perfis · `situacao` text check (`recebendo`,`validada`,`confirmada`,`cancelada`,`desfeita`,`falhou`) · `linhas_total`, `linhas_validas`, `linhas_erro`, `inseridas`, `atualizadas` integer · `confirmada_em`, `desfeita_em` timestamptz |
| `importacao_linhas` | `importacao_id` FK `on delete cascade` · `numero_linha` integer · `dados` jsonb (linha original normalizada) · `valida` boolean · `erros` text[] · `acao` text (`inserir`,`atualizar`,`ignorar`) · `dados_anteriores` jsonb · único (`importacao_id`,`numero_linha`) |
| `integracao_execucoes` | `origem` text default `importacao` · `conjunto` text (= layout) · `importacao_id` FK · `iniciado_em`, `finalizado_em` · `linhas_lidas`, `inseridas`, `atualizadas`, `com_erro` integer · `situacao` text check (`em_andamento`,`sucesso`,`sucesso_com_erros`,`falhou`) · `mensagem_erro` text |

### Políticas RLS

| Tabela | select | insert / update / delete |
|---|---|---|
| `clientes`, `contatos`, `faturamento_itens`, `pendencias`, `historico_carteira` | `eh_gestao()` **ou** (`papel_atual() = 'vendedor'` e o cliente pertence a `perfil_atual_id()`); para tabelas filhas, por `exists` em `clientes` com a mesma regra | somente pelas funções `security definer` desta SPEC (escrita manual de `contatos` entra na SPEC-1-005) |
| `itens`, `feriados`, `vw_ultima_atualizacao` | qualquer usuário com `papel_atual() is not null` | somente funções |
| `parametros`, `mapeamento_mercado` | `eh_gestao()` | `papel_atual() = 'admin'` (a tela Parâmetros é da SPEC-1-008, que também libera a escrita para a supervisora; nesta SPEC a carga é por migração) |
| `importacoes`, `integracao_execucoes` | `eh_gestao()` | `importacoes` insert/update pelo admin, apenas nos campos `nome_arquivo`, `caminho_storage`, `situacao` = `recebendo`/`cancelada`; demais campos pelas funções |
| `importacao_linhas` | `papel_atual() = 'admin'` | insert pelo admin somente enquanto a importação está `recebendo` |
| Bucket `importacoes` | admin | admin (upload); remoção somente pelo job de limpeza |

### Layouts padrão (`*` = obrigatório)

**L1 — clientes:** `codigo_cliente`* · `razao_social`* · `nome_fantasia` · `cnpj` · `cidade` · `uf`* · `tipo_cliente` · `divisao_venda` · `codigo_vendedor` · `telefone_1` · `telefone_2` · `email` · `situacao` (`ATIVO`/`BLOQUEADO`; vazio = ATIVO)

**L2 — itens:** `codigo_item`* · `descricao`* · `grupo`* · `classificacao`* · `situacao` (`ATIVO`/`INATIVO`) · `familia` (opcional; quando informada, prevalece sobre a regra RN-07 e marca `familia_manual`)

**L3 — faturamento:** `numero_nota`* · `serie` · `data_faturamento`* · `codigo_cliente`* · `codigo_item`* · `quantidade`* · `valor_unitario` · `valor_total`* · `numero_pedido` · `tipo_movimento` (`VENDA`/`DEVOLUCAO`/`CANCELADA`; vazio = VENDA) · `empresa` (vazio = 1) · `classificacao`

**L4 — pendências:** `numero_pedido`* · `codigo_cliente`* · `codigo_item`* · `quantidade_solicitada` · `quantidade_atendida` · `quantidade_pendente`* · `data_pedido`*

**L5 — curva e lote:** `codigo_item`* · `curva` · `lote_minimo`

### Carga inicial de `mapeamento_mercado`

| campo_focco | valor_focco (normalizado) | mercado |
|---|---|---|
| divisao_venda | contém `INDIRETA` | reposicao_indireta |
| divisao_venda | contém `INDUSTRIA` | industria |
| divisao_venda | contém `EXPORT` | exportacao |
| divisao_venda | contém `DIRETA` ou `REPOSICAO` | reposicao_direta |

A comparação "contém" é feita sobre o texto normalizado (maiúsculas, sem acento). Valores que não casam viram `reposicao_direta` com `mercado_inferido = true`, e aparecem na prévia como aviso, não como erro.

### Regras de negócio

| Regra de negócio | Condição | Ação/resultado | Exceção | Fonte |
|---|---|---|---|---|
| RN-01 | Qualquer layout | Cabeçalhos faltando → importação inteira recusada na prévia, listando as colunas ausentes; colunas extras são ignoradas com aviso | — | §6.1 |
| RN-02 | Códigos de item e cliente | `normalizar_codigo`: `upper(trim())` com espaços múltiplos reduzidos a um (`PS  4938 0 50` → `PS 4938 0 50`) | — | vídeos *Consulta de peças* e *Inserção de pedido* |
| RN-03 | Telefones | `normalizar_telefone`: só dígitos; com 10 ou 11 dígitos, prefixa `55`; válido com 12 ou 13 dígitos; `celular = true` quando tem 13 dígitos e o 5º dígito é `9` | Inválido → contato gravado sem telefone, com aviso | §6.1, §6.2 |
| RN-04 | L1 vendedor | `vendedor_id` = perfil cujo `codigo_vendedor_focco` = `codigo_vendedor`; sem correspondência → `parametros.vendedor_padrao_id` (supervisora), com aviso | Mudança de vendedor em cliente existente → linha em `historico_carteira` com `motivo = 'importacao FOCCO'` | §4.1 |
| RN-05 | L1 contatos | `telefone_1` e `telefone_2` viram contatos `origem = 'focco'` com `nome = nome_fantasia`; e-mail vai para o contato do `telefone_1`; o primeiro vira `principal` | Telefone já pertencente a outro cliente → mantém o vínculo existente e registra aviso | §6.1 |
| RN-06 | L3 filtro | Grava somente `empresa = 1` e `classificacao` iniciada por `30` (quando a coluna vier preenchida) | Demais linhas → `acao = 'ignorar'`, sem erro | §6.1 |
| RN-07 | L2 família (sem `familia` informada) | `grupo = 020` → `pca`; `grupo = 030` → `kpm`; descrição iniciada por `PINO` → `pino`; `grupo = 010` com `JOGO` na descrição → `pistao_jogos`; `grupo = 010` com `PESAD` → `pistao_pesada`; `grupo = 010` com `LEVE` ou demais → `pistao_leve`; outros grupos → `outros` | `familia_manual = true` nunca é sobrescrita por importação sem `familia` | vídeo *Monitoramento da carteira* (Grupo 010/020/030) |
| RN-08 | L3 cliente ou item desconhecido | Linha inválida: "Cliente {código} não cadastrado — importe L1 antes" / "Item {código} não cadastrado — importe L2 antes" | — | ordem de carga |
| RN-09 | L3 linhas repetidas da mesma nota e item | Somadas no preparo antes da gravação (quantidade e valor total) | — | chave única |
| RN-10 | L3 `CANCELADA` | Remove a linha `venda` da mesma nota e item e grava a cancelada para histórico; métricas ignoram `cancelada` | — | §6.1 |
| RN-11 | L3 `DEVOLUCAO` | Gravada com quantidade e valor **positivos** e `tipo_movimento = 'devolucao'`; as métricas subtraem no mês da `data_faturamento` | — | §6.1 |
| RN-12 | L3 nota já existente | Atualiza quantidade, valores, data e pedido (`acao = 'atualizar'`, guardando `dados_anteriores`) | — | idempotência |
| RN-13 | L4 fotografia | Pendências do arquivo → `aberta` (upsert); pendências `aberta` ausentes no arquivo → `atendida` com `encerrada_em = now()` | `quantidade_pendente ≤ 0` → linha ignorada | §6.1 |
| RN-14 | L5 | Atualiza `curva` e `lote_minimo` dos itens informados; vazio mantém o valor atual | Curva fora de A–D → erro na linha | §6.1 |
| RN-15 | Validação geral | Datas futuras em L3 e L4 → erro; quantidade ou valor negativos em L3 → erro ("use tipo_movimento DEVOLUCAO"); `valor_total` ausente com `valor_unitario` presente → calculado | — | qualidade |
| RN-16 | Confirmação | Grava somente linhas válidas; a confirmação exige marcar "Importar {n} linhas válidas e ignorar {m} com erro" | Importação com 0 linhas válidas não pode ser confirmada | §6.1 |
| RN-17 | Simultaneidade | Não pode haver duas importações do mesmo layout em `recebendo` ou `validada` ao mesmo tempo | Segunda tentativa → mensagem "Há uma importação de {layout} em andamento" | integridade |
| RN-18 | Registro | Toda confirmação ou falha cria uma linha em `integracao_execucoes` com contagens e duração | — | §6.1 |
| RN-19 | Indicador | `vw_ultima_atualizacao` = maior `finalizado_em` com situação `sucesso` ou `sucesso_com_erros` por conjunto; a barra superior mostra o do L3 como "Dados atualizados até dd/mm hh:mm" (fuso America/Sao_Paulo) | Sem nenhuma carga → "Sem dados carregados" | §6.1, §12.3 |

## Fluxo e regras

1. O admin abre Administração › Importações e vê:
   - 5 cartões, um por layout, cada um com a última carga (data, situação, linhas), o botão "Baixar modelo" e o botão "Enviar arquivo";
   - abaixo, o histórico das últimas 50 importações.
2. Em "Enviar arquivo", ele escolhe o arquivo. A interface:
   - valida a extensão e o tamanho;
   - cria `importacoes` com situação `recebendo` e envia o original ao bucket `importacoes/{layout}/{aaaa-mm}/{id}-{nome}`;
   - lê o arquivo com SheetJS e confere os cabeçalhos (RN-01);
   - grava as linhas em lotes de 2.000, com barra de progresso "Lendo linhas: 12.000 de 48.312".
3. Ao terminar o envio, a interface chama `validar_importacao(id)`. A função:
   - normaliza;
   - aplica RN-02 a RN-15;
   - preenche `valida`, `erros` e `acao`;
   - grava as contagens em `importacoes`;
   - muda a situação para `validada`.
4. A prévia mostra:
   - contadores (Total, Válidas, Com erro, Inserir, Atualizar, Ignorar);
   - avisos agrupados (ex.: "37 clientes sem vendedor correspondente → carteira da supervisora");
   - tabela das 100 primeiras linhas com erro;
   - o botão "Baixar erros (.xlsx)", com número da linha, dados e motivo.
5. O admin marca a confirmação (RN-16) e clica em "Confirmar importação". A interface chama `confirmar_importacao(id)`, que:
   - grava em uma única transação;
   - registra `integracao_execucoes`;
   - muda a situação para `confirmada`;
   - mostra o toast "Importação concluída: {inseridas} inseridas, {atualizadas} atualizadas".
6. "Cancelar" em `recebendo` ou `validada` → situação `cancelada`; as linhas de preparo são apagadas.
7. "Desfazer" aparece por 24 h na importação confirmada mais recente de cada layout. Exige a confirmação "Desfazer a importação de {data}?" e restaura o estado anterior.
8. Job `limpar-importacoes` (pg_cron, domingo 03:00 BRT = `0 6 * * 0` UTC): remove do bucket os arquivos e apaga `importacao_linhas` das importações com mais de 30 dias. As contagens em `importacoes` são mantidas.

| Cenário | Dado/condição | Resultado esperado | Caminho de erro/recuperação |
|---|---|---|---|
| Principal | L3 com 3 notas válidas de 2 clientes cadastrados | Prévia 3 válidas; confirmação insere 3 | — |
| Principal | L4 reimportado sem o pedido 30677/`PS 864 S STD` | Essa pendência vira `atendida` | — |
| Limite | Mesma nota e item repetidos em 2 linhas | Uma linha gravada com a soma (RN-09) | — |
| Limite | Linha com empresa 2 | Ignorada, sem erro (RN-06) | — |
| Limite | Cliente sem vendedor correspondente | Vai para a supervisora, com aviso (RN-04) | Admin corrige o código no perfil e reimporta L1 |
| Falha | Arquivo sem a coluna `data_faturamento` | Importação recusada antes da gravação: "Coluna obrigatória ausente: data_faturamento" | Ajustar pelo modelo |
| Falha | Nota com item não cadastrado | Linha com erro (RN-08); demais seguem | Importar L2 e reenviar L3 |
| Falha | Queda da conexão durante o envio | Importação fica `recebendo`; botão "Cancelar e reenviar" | Reenviar o arquivo |
| Falha | Segunda importação L3 em paralelo | Bloqueada (RN-17) | Concluir ou cancelar a primeira |

## Instruções de execução para o Ethos

1. **Ler antes de alterar:** `02-Escopo-Definitivo.md` §6.1, §7 e §9.12; SPEC-1-001 (funções de papel e auditoria); esta SPEC inteira.
2. **Alterar somente:** migração com as tabelas, políticas, funções, view, bucket e job desta SPEC; rota `/admin/importacoes`; componente do indicador na barra superior.
3. **Não alterar:** `perfis` e políticas da SPEC-1-001; não criar telas de consulta; não permitir escrita direta do navegador em tabelas finais.
4. **Executar nesta ordem:**
   1. Tabelas e políticas.
   2. Funções de normalização.
   3. `validar_importacao` e `confirmar_importacao` para L1 e L2, testadas com a fixture.
   4. Repetir o passo 3 para L3 a L5.
   5. Tela e modelos.
   6. Desfazer e limpeza.
   7. Carga real.
5. **Parar e pedir validação quando:**
   - a extração do TI vier sem `data_faturamento` por nota;
   - a conferência de faturamento com o FOCCO divergir em qualquer valor;
   - aparecer um `grupo` de item não previsto na RN-07 com mais de 1% do faturamento.
6. **Estado válido ao parar:** nenhuma importação em `recebendo` esquecida; tabelas finais coerentes com a última importação confirmada.

## Checklist de execução

- [ ] Tabelas, políticas, funções, view, bucket e job criados
- [ ] Fixture de teste (abaixo) passa em L1 a L5
- [ ] Tela de Importações com modelos, prévia, erros, confirmação, cancelamento e desfazer
- [ ] Indicador "Dados atualizados até" na barra superior
- [ ] Carga inicial real concluída na ordem L1 → L5, com 24 meses de faturamento
- [ ] Conferência de 3 clientes × 1 mês fechado com diferença zero
- [ ] Evidências salvas em `05_entregas/fase-1/SPEC-1-002/`

## Critérios de aceite

- [ ] **CA-1-06:** A fixture de teste produz exatamente as contagens esperadas da tabela de fixture em cada layout.
- [ ] **CA-1-07:** Depois da carga inicial, o faturamento (valor e peças) de 3 clientes escolhidos pela Ângela, num mês fechado, é igual ao relatório *COM – Vendas por Classificação* do FOCCO para o mesmo cliente e período (empresa 1, classificação 30%).
- [ ] **CA-1-08:** Um arquivo com coluna obrigatória ausente é recusado antes de gravar qualquer linha final; um arquivo com linhas inválidas grava somente as válidas e permite baixar os erros.
- [ ] **CA-1-09:** "Desfazer" devolve as tabelas finais exatamente ao estado anterior à importação (contagens e somas iguais às de antes).
- [ ] **CA-1-10:** Vendedor, pcp, supervisora e diretoria não conseguem inserir em `importacao_linhas` nem confirmar importações (teste SQL com cada papel retorna erro de permissão).
- [ ] **CA-1-11:** A barra superior mostra "Dados atualizados até" com a data e hora da última carga de faturamento confirmada.

## TDD da SPEC

**Fixture mínima** (arquivos `.csv` criados pelo executor a partir destas tabelas e guardados em `05_entregas/fase-1/SPEC-1-002/fixture/`):

| Layout | Linhas | Conteúdo-chave | Resultado esperado |
|---|---|---|---|
| L1 | 4 | `C001` Tonini (RS, vendedor `12`), `C002` Cooper (SC, vendedor `12`), `C003` Serraf (PR, vendedor `99` inexistente), `C004` sem `uf` | 3 válidas, 1 erro (UF obrigatória); `C003` na carteira da supervisora com aviso; 4 contatos criados a partir de `telefone_1`/`telefone_2` válidos |
| L2 | 3 | `PS 4938 STD` grupo 010 "PISTAO LINHA LEVE"; `PS  864 S STD` grupo 010 "PISTAO LINHA PESADA" (dois espaços); `KPM 100` grupo 030 | 3 válidas; códigos normalizados; famílias `pistao_leve`, `pistao_pesada`, `kpm` |
| L3 | 6 | Nota 1001 `C001`/`PS 4938 STD` 100 un R$ 6.000,00 (2 linhas de 50 un e R$ 3.000,00); nota 1002 `C002`/`PS 864 S STD` 10 un R$ 400,00; nota 1003 empresa 2; nota 1004 item `XX 1` inexistente; nota 1005 com data futura | 3 linhas gravadas (1001 somada, 1002, 1003 ignorada); 2 erros (1004, 1005) |
| L4 | 2 | Pedido 30677 `C002`/`PS 864 S STD` pendente 4; pedido 30678 `C001`/`PS 4938 STD` pendente 0 | 1 aberta; 1 ignorada |
| L4 (2ª carga) | 0 linhas de dados | — | Pendência 30677 passa a `atendida` |
| L5 | 2 | `PS 864 S STD` curva D lote 300; `KPM 100` curva Z | 1 válida; 1 erro (curva) |

| Etapa | Prova | Comando/ação | Resultado esperado | Evidência |
|---|---|---|---|---|
| RED 1 | Funções inexistentes | `select validar_importacao('<id>')` antes da implementação | Erro "function does not exist" | `red-funcoes.txt` |
| GREEN 1 | Fixture L1–L5 | Enviar os arquivos da fixture pela tela, na ordem, e rodar as consultas: `select count(*) from clientes`; `select codigo_focco, familia from itens order by 1`; `select numero_nota, quantidade, valor_total from faturamento_itens order by 1`; `select numero_pedido, situacao from pendencias`; `select codigo_focco, curva, lote_minimo from itens order by 1` | Exatamente os resultados da tabela de fixture | `fixture-resultados.txt` + capturas das prévias |
| RED 2 | Permissão | Antes das políticas de escrita: como vendedor, `insert into importacao_linhas (...)` | Insert aceito (falha do CA-1-10) | `red-permissao.txt` |
| GREEN 2 | Permissão | Mesmo insert como vendedor, pcp, supervisora e diretoria | Erro de RLS para os quatro | `green-permissao.txt` |
| GREEN 3 | Desfazer | Somar `valor_total` de `faturamento_itens` antes de uma importação L3 de teste, importar, desfazer e somar de novo | Somas antes e depois iguais | `desfazer.txt` |
| GREEN 4 | Carga real | Carga L1–L5 real e conferência: `select date_trunc('month', data_faturamento), sum(quantidade) filter (where tipo_movimento='venda') - sum(quantidade) filter (where tipo_movimento='devolucao'), sum(valor_total) filter (where tipo_movimento='venda') - sum(valor_total) filter (where tipo_movimento='devolucao') from faturamento_itens f join clientes c on c.id=f.cliente_id where c.codigo_focco = '<código>' and data_faturamento between '<início>' and '<fim>' group by 1` para os 3 clientes | Igual ao relatório do FOCCO | `conferencia-faturamento.xlsx` com as duas colunas e a diferença |
| REFACTOR/REGRESSÃO | Arquivo inválido e simultaneidade | Enviar L3 sem `data_faturamento`; abrir duas importações L3 | Recusa antes de gravar; segunda bloqueada | 2 capturas |

**Caminhos de erro obrigatórios:** cabeçalho ausente, linha inválida, cliente ou item desconhecido, data futura, valor negativo, conexão interrompida no envio, importação simultânea, desfazer fora da janela de 24 h (botão não aparece).  
**Evidência exigida:** arquivos citados em `05_entregas/fase-1/SPEC-1-002/`.

## Handoff e operação

- **Como demonstrar:**
  1. Marco envia o arquivo L4 de pendências do dia.
  2. A prévia aparece, ele confirma e o indicador atualiza.
  3. Ângela mostra a planilha de conferência com diferença zero.
- **Como operar depois:**
  - **Rotina manual da fase 1** (Marco, ou substituto definido por ele):
    - todo dia útil, até as 09:00: L3 faturamento (notas dos últimos 7 dias) e L4 pendências;
    - toda segunda-feira, até as 09:00: L1 clientes, L2 itens e L5 curva e lote.
  - O indicador "Dados atualizados até" mostra a todos quando a carga do dia ainda não foi feita.
  - Itens com família errada são corrigidos por L2 com a coluna `familia`.
- **Como monitorar:** histórico de importações e indicador "Dados atualizados até".
- **Pendência conhecida:** nenhuma.

## Tasks vinculadas

| ID | Task | Dono | SPEC | Critério | Recorte da prova | Evidência esperada | Pré-condições | Status |
|---|---|---|---|---|---|---|---|---|
| 1.05 | Criar tabelas da base comercial e de importação, políticas RLS, normalizações e carga de `mapeamento_mercado`, `feriados` e `parametros` | Marco Carvalho | SPEC-1-002 | CA-1-10 | RED 2 → GREEN 2 | `red-permissao.txt`, `green-permissao.txt` | SPEC-1-001 aceita (1.01) | ☐ |
| 1.06 | Implementar `validar_importacao` e `confirmar_importacao` (L1–L5), desfazer e job de limpeza | Marco Carvalho | SPEC-1-002 | CA-1-06, CA-1-09 | RED 1 → GREEN 1 (via SQL) e GREEN 3 | `fixture-resultados.txt`, `desfazer.txt` | 1.05 concluída | ☐ |
| 1.07 | Construir a tela Administração › Importações, modelos `.xlsx` e o indicador "Dados atualizados até" | Marco Carvalho | SPEC-1-002 | CA-1-08, CA-1-11 | GREEN 1 pela tela e REGRESSÃO | Capturas das prévias, do erro de cabeçalho e do indicador | 1.06 concluída; 1.03 concluída | ☐ |
| 1.08 | Gerar as extrações do FOCCO nos layouts L1–L5 (L3 com 24 meses, por nota e item) e executar a carga inicial real na ordem L1 → L5 | Marco Carvalho | SPEC-1-002 | CA-1-06 (regra aplicada aos dados reais), CA-1-11 | Prévias sem erro de cabeçalho; 5 importações `confirmada` | Captura do histórico de importações com as 5 cargas | Modelos `.xlsx` disponíveis (1.07) | ☐ |
| 1.09 | Conferir o faturamento de 3 clientes × 1 mês fechado com o relatório do FOCCO | Ângela Ferreira | SPEC-1-002 | CA-1-07 | GREEN 4 | `conferencia-faturamento.xlsx` com diferença zero | 1.08 concluída | ☐ |

## Emendas

<!-- Append-only (D19): mudanças aprovadas depois da geração. A história não é reescrita. -->

| Data | Origem do sinal | Micro-spec/task | Motivo |
|---|---|---|---|
| | | | |
