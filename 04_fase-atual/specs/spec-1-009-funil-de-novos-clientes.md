# SPEC-1-009 — Funil de novos clientes (pipeline em kanban)

**Fase:** 1  
**Status:** planejada  
**Dono:** Marco Carvalho (TI Platina) · **Consultoria:** Kimberly Prestes (Adapta)  
**Origem no escopo:** `02-Escopo-Definitivo.md` §9.6 (Funil de novos clientes), §7.4 (`leads`, `leads_etapas_historico`), §9.5 (aba Novos clientes), §4.2 (permissões), D6; pedido de CRM com pipeline (1ª Consultoria, Gabrielle, 03:42); processo de cadastro de cliente novo (vídeo *Monitoramento da carteira*, 07:12–09:59)  
**Degrau da solução:** construção mínima no Skip (kanban com `@dnd-kit/core`, biblioteca de arrastar e soltar compatível com React) sobre tabelas novas no Supabase; nenhuma integração.

## Contexto e decisões fechadas

- **Estado atual:**
  - A prospecção chega por site, feiras, representantes e indicações.
  - O processo é:
    1. envio do formulário padrão de cadastro;
    2. análise de crédito (Serasa e referências);
    3. validação de mercado (mercados maduros SP, RS, MG, SC, PR só aceitam cliente com alto potencial ou com linha nova);
    4. proposta comercial.
  - Nada disso é medido: "não temos um indicador para medir esse processo" (vídeo *Monitoramento da carteira*, 09:59).
- **Estado desejado:**
  - Cada novo cliente em potencial é um **lead** num kanban com as etapas reais do processo.
  - A regra de mercado maduro é aplicada no sistema.
  - Leads parados viram ação no Meu dia.
  - O lead vira cliente automaticamente quando o CNPJ aparece com faturamento na importação do FOCCO.
- **Decisões já fechadas:**
  - **O kanban é só para clientes novos.** A carteira existente é trabalhada pelo Meu dia e pelas Oportunidades (D6, observação da Ângela).
  - **Etapas, na ordem:**
    1. `lead_recebido`
    2. `formulario_enviado`
    3. `formulario_recebido`
    4. `analise_credito`
    5. `validacao_mercado`
    6. `proposta_enviada`
    7. `primeiro_pedido`
    8. `cliente_ativo`
    - Coluna lateral `perdido`, com motivo obrigatório.
  - O lead pode avançar ou voltar uma ou mais etapas, exceto pelos bloqueios da RN-03 e da RN-05.
  - **Rota:** `/novos-clientes`. Aba "Novos clientes" em `/oportunidades`.
  - **Mercado maduro:** para avançar de `validacao_mercado` para `proposta_enviada` em UF de mercado maduro, o lead precisa de **potencial mensal ≥ R$ 10.000** ou da marcação **"traz linha de produto ainda não vendida na região"**. Sem isso, o lead fica "Aguardando aprovação" da supervisora, que aprova ou recusa com justificativa.
  - **Conversão automática:** depois de cada importação L1 ou L3, um lead com CNPJ igual ao de um cliente que tenha faturamento importado vai para `cliente_ativo` e é vinculado ao cliente (`cliente_id`). A etapa `primeiro_pedido` pode ser marcada manualmente antes disso.
  - **Origem WhatsApp:** criada automaticamente a partir de conversas só na fase 2. Nesta fase, a origem "WhatsApp" é escolhida manualmente.
- **Bloqueios:** nenhum.

## Resultado observável

A Ângela cadastra o lead "Dedé Autopeças" (BA, origem Feira, potencial de R$ 6.000/mês), arrasta para "Formulário enviado" e depois até "Validação de mercado". Como BA não é mercado maduro, o lead avança livremente para "Proposta enviada". Um lead de SC com potencial de R$ 4.000 e sem linha nova fica "Aguardando aprovação". Quando o CNPJ do Dedé aparece na importação de faturamento, o cartão vai sozinho para "Cliente ativo", com link para a ficha.

## Limites e dependências

- **Inclui:**
  - tabelas `leads` e `leads_etapas_historico`;
  - coluna `acoes.lead_id`;
  - funções `mover_lead`, `aprovar_mercado_lead`, `converter_leads`;
  - ação `prospeccao` para lead parado;
  - rota `/novos-clientes` (kanban, formulário, detalhe do lead com linha do tempo e registro de contato);
  - aba Novos clientes em Oportunidades;
  - item de menu.
- **Fora de escopo:**
  - criação automática de lead pelo WhatsApp (fase 2);
  - análise de crédito automática (Serasa continua fora do sistema; a etapa só registra o resultado);
  - geração de proposta em PDF;
  - painéis de conversão (SPEC-1-012, que lê estas tabelas).
- **Entradas e pré-condições:** SPEC-1-006 (`acoes`) e SPEC-1-007 (registro de resultado); SPEC-1-002 (`clientes` com CNPJ e `importacoes`); SPEC-1-005 (`interacoes`, que ganha `lead_id`).
- **Saídas/artefatos:** migração SQL; telas; validação com 2 leads reais.
- **Dependências e responsáveis:** Marco constrói no Skip e no Supabase, com orientação da consultora Kimberly; Ângela valida com leads reais.
- **Atores e permissões mínimas:**

| Ator | Ver leads | Criar e mover | Aprovar mercado | Marcar perdido |
|---|---|---|---|---|
| vendedor | os próprios | os próprios | — | os próprios |
| supervisora | todos | todos (escolhe o vendedor) | ✔ | todos |
| diretoria | todos (leitura) | — | — | — |
| admin, pcp | — | — | — | — |

- **Superfícies/arquivos/configurações afetadas:**
  - Supabase: tabelas e funções; `acoes.lead_id` (check: `cliente_id` ou `lead_id`, exatamente um); `interacoes.lead_id` (mesmo check);
  - chamada a `converter_leads()` no fim de `confirmar_importacao` de L1 e L3;
  - geração de ação `prospeccao` dentro de `gerar_acoes` (SPEC-1-006);
  - Skip: `/novos-clientes`, aba em `/oportunidades`, menu.
- **Risco e plano B:** lead criado em duplicidade (mesmo CNPJ) → bloqueio por CNPJ (RN-01); sem CNPJ, aviso de nome parecido.
- **Rollback ou reversão:** as tabelas novas podem ser removidas sem afetar a carteira. Uma conversão automática errada é desfeita pela supervisora ("Desvincular cliente"), que volta o lead para `primeiro_pedido`.

## Dados e integrações

Sem integração externa.

**Tabela `leads`** (RLS: vendedor os próprios; gestão todos; auditoria):
- `razao_social` (obrigatório) · `nome_fantasia` · `cnpj` (14 dígitos, único quando preenchido) · `cidade` · `uf` (obrigatório) · `mercado_maduro` (gerado pela UF) · `contato_nome` · `telefone` (normalizado) · `email` · `origem` check (`site`,`feira`,`representante`,`indicacao`,`whatsapp`,`outro`) · `origem_detalhe` (ex.: nome da feira ou do representante) · `vendedor_id` · `etapa` · `etapa_desde` timestamptz · `potencial_mensal` numeric · `linhas_interesse` text[] (famílias da SPEC-1-002) · `linha_nova_regiao` boolean · `credito_resultado` (`aprovado`,`aprovado_com_condicoes`,`reprovado`) · `credito_obs` · `aprovacao_mercado` (`nao_necessaria`,`pendente`,`aprovada`,`recusada`) · `aprovacao_justificativa` · `aprovado_por` · `motivo_perda_codigo` (lista de `motivos_perda` + `cadastro_recusado`, `sem_retorno`) · `perda_obs` · `cliente_id` (quando convertido) · `convertido_em`.

**Tabela `leads_etapas_historico`:** `lead_id`, `etapa_anterior`, `etapa_nova`, `por` (perfil ou `sistema`), `observacao`, `criado_em`.

| Regra | Condição | Ação/resultado | Exceção | Fonte |
|---|---|---|---|---|
| RN-01 Duplicidade | CNPJ igual ao de um lead aberto ou de um cliente da carteira | Bloqueia: "Este CNPJ já é o cliente {nome}" ou "já está no funil com {vendedor}" | — | qualidade |
| RN-02 Crédito | Mover para além de `analise_credito` | Exige `credito_resultado`; `reprovado` → só `perdido` (motivo `credito`) | — | vídeo 08:13 |
| RN-03 Mercado maduro | De `validacao_mercado` para `proposta_enviada`, com `mercado_maduro` e `potencial_mensal < 10.000` e sem `linha_nova_regiao` | `aprovacao_mercado = 'pendente'`; o cartão mostra "Aguardando aprovação"; alerta `lead_aprovacao` para a supervisora | Supervisora aprova (avança) ou recusa (vai para `perdido` com motivo `cadastro_recusado`), com justificativa ≥ 10 caracteres | §9.6, vídeo 08:24 |
| RN-04 Perdido | Mover para `perdido` | Exige motivo; observação opcional; sai do kanban principal (contador da coluna lateral) | Reabrir: volta para a última etapa | §9.6 |
| RN-05 Conversão | `converter_leads()`: lead não convertido com CNPJ = `clientes.cnpj` e cliente com ao menos 1 venda importada | `etapa = 'cliente_ativo'`, `cliente_id`, `convertido_em`; histórico "por sistema"; ações abertas do lead são concluídas como `pedido_gerado` com valor da primeira venda | Lead sem CNPJ → não converte (aviso no cartão "Informe o CNPJ para conversão automática") | §9.6 |
| RN-06 Lead parado | Lead aberto em `formulario_recebido`, `analise_credito`, `validacao_mercado` ou `primeiro_pedido` com `etapa_desde` há mais de 10 dias (`lead_parado_dias`) e sem ação aberta | `gerar_acoes` cria ação `prospeccao` "Avançar lead {nome} — {etapa} há {n} dias", faixa normal, pontuação = `potencial_mensal × 0,6` | Leads `pendente` de aprovação geram alerta, não ação | §9.6 |
| RN-07 Contatos do lead | Registrar contato no detalhe do lead | Usa `interacoes` com `lead_id`; o vínculo passa ao cliente na conversão | — | §7.3 |
| RN-08 Vendedor | Vendedor cria lead para si; supervisora escolhe | `vendedor_id` obrigatório | — | §4.2 |
| RN-09 Primeiro contato | Lead criado (por qualquer pessoa ou, na fase 2, pelo agente de IA) | Cria na hora a ação `primeiro_contato` "Primeiro contato com {nome}", `data_prevista = hoje`, faixa **alta**, para o vendedor do lead; concluída pelo registro de resultado ou pela primeira interação registrada no lead | Lead criado depois das 17:00 → data = próximo dia útil | §9.6, §9.9; 1ª Consultoria (~30:00) |
| RN-10 Follow-up | Lead em `formulario_enviado` ou `proposta_enviada` sem mudança de etapa | Depois de **3 dias úteis** (`followup_1_dias_uteis`) cria ação `follow_up` "Follow-up 1 — {etapa} — {nome}"; se ainda não houver mudança de etapa, depois de **mais 4 dias úteis** (`followup_2_dias_uteis`) cria "Follow-up 2"; ambas faixa alta | Mudança de etapa cancela o follow-up aberto com observação "Lead avançou" | §9.9; 1ª Consultoria (~18:00 "follow-up") |
| RN-11 Sem resposta | Follow-up 2 concluído sem mudança de etapa em 2 dias úteis | Alerta `lead_sem_resposta` para a supervisora; cartão com selo "Sem resposta" | O selo some quando o lead muda de etapa | §9.9 |

## Telas

**`/novos-clientes`:**
1. **Cabeçalho:** "Novos clientes", contadores (abertos, convertidos nos últimos 90 dias, taxa de conversão dos últimos 90 dias) e botão "Novo lead".
2. **Filtros:** vendedor (gestão), UF, origem, "Aguardando aprovação".
3. **Kanban:**
   - 8 colunas com rótulo em maiúsculas e contador; coluna lateral recolhível "Perdidos";
   - **cartão:** nome, UF, origem, potencial (R$), vendedor (gestão), dias na etapa (vermelho > 10), selos "Aguardando aprovação" e "Mercado maduro";
   - arrastar entre colunas chama `mover_lead` e abre um modal quando a etapa exige dado (crédito, motivo, aprovação);
   - no celular: lista agrupada por etapa, com o botão "Mover para…" em vez de arrastar.
4. **Detalhe do lead** (painel lateral):
   - dados editáveis;
   - linha do tempo (mudanças de etapa e contatos);
   - "Registrar contato";
   - "Marcar perdido";
   - para a supervisora: "Aprovar / Recusar mercado" e "Desvincular cliente".
5. **Formulário "Novo lead":** campos da tabela, com UF, origem e vendedor obrigatórios e potencial em R$. Validação de CNPJ por dígito verificador.

**`/oportunidades` — aba Novos clientes:** leads abertos ordenados por potencial, com etapa e dias parados.

| Cenário | Dado/condição | Resultado esperado | Caminho de erro/recuperação |
|---|---|---|---|
| Principal | Lead BA percorre todas as etapas | Avança sem aprovação; histórico com 6 mudanças | — |
| Principal | Lead SC, potencial 4.000, sem linha nova | Para em "Aguardando aprovação"; alerta à supervisora | Supervisora aprova → `proposta_enviada` |
| Principal | CNPJ do lead aparece com venda na importação L3 | Cartão em `cliente_ativo` com link para a ficha | — |
| Limite | Lead SP com linha nova marcada | Avança sem aprovação | — |
| Limite | Lead 12 dias em `formulario_enviado` | Ação `prospeccao` no Meu dia do vendedor | — |
| Falha | CNPJ já cliente | Bloqueado (RN-01) | Usar a ficha do cliente |
| Falha | Crédito reprovado e tentativa de avançar | Bloqueado; só `perdido` | — |
| Falha | Vendedor tenta aprovar mercado | Botão ausente; função recusa | — |

## Instruções de execução para o Ethos

1. **Ler antes de alterar:** `02-Escopo-Definitivo.md` §9.6 e §7.4; SPECs 1-006, 1-007 e 1-008 (alertas); esta SPEC.
2. **Alterar somente:**
   - tabelas e funções desta SPEC;
   - `acoes.lead_id` e `interacoes.lead_id`;
   - chamadas em `confirmar_importacao`;
   - o trecho de `prospeccao` em `gerar_acoes`;
   - os tipos de alerta `lead_aprovacao` e `lead_sem_resposta` em `alertas`;
   - os parâmetros `lead_parado_dias` (10), `followup_1_dias_uteis` (3) e `followup_2_dias_uteis` (4);
   - as telas listadas.
3. **Não alterar:** as regras de reativação; a ficha do cliente (exceto exibir "Originado do lead {nome}" quando houver).
4. **Executar nesta ordem:**
   1. Tabelas.
   2. Funções com testes SQL.
   3. Kanban.
   4. Detalhe e formulário.
   5. Aprovação.
   6. Aba em Oportunidades.
   7. Conversão automática.
   8. Validação com leads reais.
5. **Parar e pedir validação quando:** a Ângela pedir uma etapa diferente das 8 (vira emenda).
6. **Estado válido ao parar:** o kanban abre; nenhum lead fica sem etapa.

## Checklist de execução

- [ ] Tabelas, colunas `lead_id` e funções com RLS
- [ ] Kanban com arrastar, modais por etapa e versão celular
- [ ] Detalhe do lead com linha do tempo e contatos
- [ ] Regra de mercado maduro com aprovação da supervisora
- [ ] Conversão automática após L1 e L3
- [ ] Ações `primeiro_contato`, `follow_up` (cadência 3 + 4 dias úteis) e `prospeccao` para lead parado
- [ ] Aba Novos clientes em Oportunidades e item de menu
- [ ] Validação com 2 leads reais
- [ ] Evidências salvas em `05_entregas/fase-1/SPEC-1-009/`

## Critérios de aceite

- [ ] **CA-1-43:** Um lead percorre as 8 etapas, cada mudança fica no histórico, e etapas que exigem dado (crédito, motivo de perda) não avançam sem ele.
- [ ] **CA-1-44:** Em UF de mercado maduro, um lead com potencial < R$ 10.000 e sem linha nova não chega a `proposta_enviada` sem aprovação da supervisora; com potencial ≥ R$ 10.000 ou linha nova, avança direto.
- [ ] **CA-1-45:** Depois de uma importação com faturamento para o CNPJ do lead, ele vai para `cliente_ativo` vinculado ao cliente, sem ação manual.
- [ ] **CA-1-46:** Lead parado há mais de 10 dias gera uma ação `prospeccao` no Meu dia do vendedor.
- [ ] **CA-1-47:** O vendedor só vê os próprios leads; o CNPJ duplicado é bloqueado.
- [ ] **CA-1-48:** Todo lead novo gera "Primeiro contato" no bloco Novos leads do Meu dia no mesmo dia útil; um lead parado em `proposta_enviada` gera Follow-up 1 depois de 3 dias úteis e Follow-up 2 depois de mais 4, e depois disso a supervisora recebe o alerta "Sem resposta".

## TDD da SPEC

| Etapa | Prova | Comando/ação | Resultado esperado | Evidência |
|---|---|---|---|---|
| RED 1 | Tabela inexistente | `select mover_lead(...)` | Erro "function does not exist" | `red.txt` |
| GREEN 1 | Percurso | Lead teste BA: `mover_lead` por todas as etapas; tentativa de passar de `analise_credito` sem crédito | Histórico com 7 linhas; bloqueio no crédito | `percurso.txt` |
| GREEN 2 | Mercado maduro | 3 leads: SC 4.000 sem linha nova; SC 12.000; SP 3.000 com linha nova | 1º pendente + alerta; 2º e 3º avançam | `mercado.txt` |
| GREEN 3 | Conversão | Lead com CNPJ X; importar L1 com cliente CNPJ X e L3 com uma venda dele | Lead `cliente_ativo` com `cliente_id` | `conversao.txt` |
| GREEN 4 | Lead parado | `etapa_desde` = 11 dias atrás; rodar `gerar_acoes` | 1 ação `prospeccao` | `parado.txt` |
| GREEN 4b | Primeiro contato e follow-up | Criar lead às 10:00 → consultar `acoes`; colocar lead em `proposta_enviada` com `etapa_desde` 3 dias úteis atrás e rodar `gerar_acoes`; repetir com 7 dias úteis e follow-up 1 concluído; repetir com follow-up 2 concluído há 2 dias úteis | `primeiro_contato` hoje (alta); Follow-up 1; Follow-up 2; alerta `lead_sem_resposta` | `followup.txt` |
| GREEN 5 | Leads reais | A Ângela cadastra 2 leads reais e os move até a etapa atual | Kanban fiel ao estado real | `validacao.md` + captura |
| REFACTOR/REGRESSÃO | Permissão, duplicidade e celular | Vendedor A lista leads de B; criar CNPJ duplicado; celular 390 px | 0; bloqueio; lista por etapa | `regressao.txt` + captura |

**Caminhos de erro obrigatórios:** crédito reprovado, CNPJ inválido ou duplicado, aprovação recusada, perda sem motivo, permissão, desvinculação.  
**Evidência exigida:** arquivos citados em `05_entregas/fase-1/SPEC-1-009/`.

## Handoff e operação

- **Como demonstrar:**
  1. Ângela cadastra um lead de feira e o move até a validação de mercado.
  2. Ela aprova um lead de mercado maduro.
  3. Ela mostra um lead convertido automaticamente.
- **Como operar depois:**
  - Todo contato de prospecção vira lead no mesmo dia.
  - A Ângela revisa o kanban toda segunda.
- **Como monitorar:** contadores do cabeçalho e painel de prospecção (SPEC-1-012).
- **Pendência conhecida:** nenhuma.

## Tasks vinculadas

| ID | Task | Dono | SPEC | Critério | Recorte da prova | Evidência esperada | Pré-condições | Status |
|---|---|---|---|---|---|---|---|---|
| 1.32 | Criar `leads`, histórico, `lead_id` em `acoes` e `interacoes`, funções `mover_lead`, `aprovar_mercado_lead`, `converter_leads` e as ações `prospeccao`, `primeiro_contato` e `follow_up` | Marco Carvalho | SPEC-1-009 | CA-1-43, CA-1-44, CA-1-45, CA-1-46, CA-1-47, CA-1-48 | RED 1 → GREEN 1 a GREEN 4b (SQL) | `percurso.txt`, `mercado.txt`, `conversao.txt`, `parado.txt`, `followup.txt` | 1.24 e 1.28 concluídas | ☐ |
| 1.33 | Construir o kanban de Novos clientes, o detalhe do lead, o formulário, a aprovação e a aba em Oportunidades | Marco Carvalho | SPEC-1-009 | CA-1-43, CA-1-44, CA-1-47 | GREEN 1 e GREEN 2 pela tela; REGRESSÃO | Capturas do kanban, da aprovação e do celular | 1.32 e 1.26 concluídas | ☐ |
| 1.34 | Cadastrar e mover 2 leads reais e validar o funil | Ângela Ferreira | SPEC-1-009 | CA-1-43 | GREEN 5 | `validacao.md` | 1.33 concluída | ☐ |

## Emendas

<!-- Append-only (D19): mudanças aprovadas depois da geração. A história não é reescrita. -->

| Data | Origem do sinal | Micro-spec/task | Motivo |
|---|---|---|---|
| | | | |
