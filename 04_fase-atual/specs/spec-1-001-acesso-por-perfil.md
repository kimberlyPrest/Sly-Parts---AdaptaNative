# SPEC-1-001 — Acesso por perfil e casca da Central Sly

**Fase:** 1  
**Status:** planejada  
**Dono:** Marco Carvalho (TI Platina) · **Consultoria:** Kimberly Prestes (Adapta)  
**Origem no escopo:** `02-Escopo-Definitivo.md` §4 (usuários, perfis e matriz de permissões), §5 (arquitetura), §9.1 (login), §9.12 (Administração › Usuários), §12.1 (segurança), §12.4 (usabilidade), D12  
**Degrau da solução:** nativo da plataforma — Supabase Auth + Row Level Security + Edge Function, sem biblioteca de autenticação própria.

## Contexto e decisões fechadas

- **Estado atual:** não existe sistema comercial próprio. O CRM do FOCCO foi contratado e nunca usado por ser pouco amigável (Kickoff, 21/09/2026). O projeto Skip está criado e o Supabase está conectado em Configurações → Integrações (fase 0).
- **Estado desejado:** cada pessoa da equipe entra com login próprio na Central Sly, vê a identidade visual Sly Parts e cai na tela do seu perfil. O administrador cria, altera e desativa usuários pela própria tela. As permissões valem no banco, e não apenas na interface.
- **Decisões já fechadas:**
  - Autenticação por **Supabase Auth com e-mail e senha**, senha mínima de **8 caracteres**. Usuários entram **somente por convite**: o cadastro público fica desativado no Supabase (Authentication → Sign In / Providers → "Allow new users to sign up" desligado).
  - Os papéis são exatamente: `vendedor`, `supervisora`, `diretoria`, `pcp`, `admin`.
  - A sessão expira após **12 horas sem atividade**, controlada pela interface (ver RN-04).
  - O menu mostra **somente módulos já entregues**. Esta SPEC entrega Carteira (rota da SPEC-1-004) e Administração. Cada SPEC seguinte da fase 1 acrescenta o seu item ao menu (RN-03). Não se criam páginas vazias. Conversas (WhatsApp) é da fase 2.
  - Destino inicial após o login: vendedor, supervisora e diretoria vão para `/carteira`; admin vai para `/admin/usuarios`. O usuário do PCP é criado quando a tela de Lotes C/D for entregue (SPEC-1-011), já com destino `/lotes`. Os destinos finais de §9.1 são ligados pelas SPECs que entregam cada tela: vendedor → `/meu-dia` (SPEC-1-007), supervisora → `/supervisao` (SPEC-1-008), pcp → `/lotes` (SPEC-1-011), diretoria → `/paineis` (SPEC-1-012).
  - A identidade visual segue a tabela "Identidade visual", abaixo, extraída de slyparts.com.br.
- **Bloqueios:** nenhum para construir. Para concluir a task 1.04, Marco precisa fornecer o e-mail de cada usuário e o código de vendedor de cada vendedor no FOCCO.

## Resultado observável

Os 7 usuários iniciais entram na Central Sly com o próprio e-mail. Cada um vê o menu do seu papel e cai na sua tela inicial. O Marco cria um usuário novo pela tela de Administração, e a pessoa recebe o convite por e-mail e define a senha. Um vendedor que tenta ler perfis de outras pessoas direto no banco recebe somente o próprio registro.

## Limites e dependências

- **Inclui:**
  - tabela `perfis`;
  - funções de papel;
  - políticas RLS de `perfis`;
  - tabela e gatilho de `auditoria`;
  - Edge Function `admin-usuarios`;
  - telas Login, Esqueci minha senha e Definir senha;
  - casca da aplicação (sidebar, barra superior, menu por papel);
  - tela Administração › Usuários;
  - expiração por inatividade;
  - cadastro dos 7 usuários iniciais.
- **Fora de escopo:**
  - telas Meu dia, Supervisão, Parâmetros, Oportunidades, Novos clientes, Pós-venda, Lotes C/D e Painéis (SPECs 1-007 a 1-012);
  - Conversas/WhatsApp (fase 2);
  - login social ou SSO;
  - autenticação em dois fatores.
- **Entradas e pré-condições:**
  - projeto Skip criado e conectado ao Supabase;
  - lista de usuários com nome, e-mail, papel e código de vendedor FOCCO (vendedores), fornecida por Marco;
  - e-mail de convite do Supabase configurado com remetente da Platina **ou** com o remetente padrão do Supabase.
- **Saídas/artefatos:**
  - migração SQL de `perfis`, `auditoria` e funções;
  - Edge Function `admin-usuarios`;
  - telas da interface;
  - 7 usuários ativos;
  - capturas de evidência em `05_entregas/fase-1/SPEC-1-001/`.
- **Dependências e responsáveis:** Marco constrói no Skip e no Supabase, com orientação da consultora Kimberly, e fornece a lista de usuários e executa os cadastros; Ângela confirma a lista de vendedores e o código FOCCO de cada um.
- **Atores e permissões mínimas:**

| Ator | Pode | Não pode |
|---|---|---|
| vendedor | ler o próprio perfil; atualizar o próprio `ultimo_acesso_em` via RPC | ler outros perfis; alterar papel; criar usuários |
| supervisora | ler todos os perfis | criar, alterar ou desativar usuários |
| diretoria | ler todos os perfis | criar, alterar ou desativar usuários |
| pcp | ler o próprio perfil | ler outros perfis |
| admin | ler todos; criar, alterar, desativar e reativar usuários (pela Edge Function) | apagar usuários (somente desativar) |

- **Superfícies/arquivos/configurações afetadas:**
  - Supabase: Auth (configurações acima), schema `public` (`perfis`, `auditoria`, funções), Edge Function `admin-usuarios`, segredo `SUPABASE_SERVICE_ROLE_KEY` (já existente no ambiente das Edge Functions);
  - Skip: rotas `/login`, `/recuperar-senha`, `/definir-senha`, `/carteira`, `/admin/usuarios` e layout geral.
- **Risco e plano B:**
  - E-mail de convite cair no spam: o admin reenvia o convite pela tela, e o usuário procura por "Central Sly" no spam.
  - Remetente padrão do Supabase com limite de envio baixo: com 7 usuários isso não afeta; se afetar, configurar SMTP da Platina em Auth → SMTP Settings (Marco).
- **Rollback ou reversão:**
  - A migração tem script de reversão (`drop` das políticas, funções e tabelas criadas nesta SPEC, nessa ordem).
  - Usuários criados por engano são **desativados**, não apagados.

## Dados e integrações

**Tabela `perfis`**

| Campo | Tipo | Regra |
|---|---|---|
| `id` | uuid | PK, `default gen_random_uuid()` |
| `user_id` | uuid | único, FK `auth.users(id)` `on delete cascade`, obrigatório |
| `nome` | text | obrigatório, 2–80 caracteres |
| `email` | text | obrigatório, único, minúsculo |
| `papel` | text | obrigatório, `check (papel in ('vendedor','supervisora','diretoria','pcp','admin'))` |
| `codigo_vendedor_focco` | text | opcional, único quando preenchido; obrigatório quando `papel = 'vendedor'` (check) |
| `ativo` | boolean | `default true` |
| `ultimo_acesso_em` | timestamptz | opcional |
| `criado_em` / `atualizado_em` | timestamptz | `default now()`; `atualizado_em` atualizado por gatilho |

**Tabela `auditoria`**: `id` (bigserial), `usuario_id` (uuid, `auth.uid()` no momento), `tabela` (text), `registro_id` (text), `operacao` (`INSERT`/`UPDATE`/`DELETE`), `dados_anteriores` (jsonb), `dados_novos` (jsonb), `criado_em` (timestamptz). A função genérica `registrar_auditoria()` (gatilho `after insert or update or delete`) é anexada a `perfis` nesta SPEC e reutilizada pelas SPECs seguintes. Leitura de `auditoria`: `admin`, `supervisora` e `diretoria`. Escrita: somente pelo gatilho (`security definer`).

**Funções SQL** (todas `stable`, `security definer`, `set search_path = public`):
- `perfil_atual_id()` → uuid do perfil ativo de `auth.uid()`, ou null.
- `papel_atual()` → papel do perfil ativo de `auth.uid()`, ou null (usuário desativado = sem papel).
- `eh_gestao()` → `papel_atual() in ('supervisora','diretoria','admin')`.
- `registrar_acesso()` → atualiza `ultimo_acesso_em = now()` do próprio perfil; `security definer`, executável por `authenticated`.

**Políticas RLS de `perfis`** (RLS ativada e forçada):
- `select`: `user_id = auth.uid() or eh_gestao()`.
- `insert`, `update`, `delete`: nenhuma política para `authenticated`. As alterações passam somente pela Edge Function com service role.

**Edge Function `admin-usuarios`** (`verify_jwt = true`)

| Origem/destino | Fonte de verdade | Campos/contrato | Autenticação/permissão | Timeout/retry/idempotência | Tratamento de erro |
|---|---|---|---|---|---|
| Tela Administração › Usuários → `POST /admin-usuarios` | `perfis` + `auth.users` | `{ acao: 'criar', nome, email, papel, codigo_vendedor_focco? }` · `{ acao: 'alterar', perfil_id, nome?, papel?, codigo_vendedor_focco? }` · `{ acao: 'desativar' \| 'reativar' \| 'reenviar_convite', perfil_id }` | JWT do chamador; a função lê o perfil do chamador e exige `papel = 'admin'` e `ativo`; usa service role somente no servidor | Timeout 15 s; sem retry automático; `criar` com e-mail já existente devolve 409 e não duplica | 401 sem sessão · 403 papel diferente de admin · 409 e-mail ou código FOCCO já usado · 422 campos inválidos (mensagem em português por campo) · 500 erro inesperado (registra no log da função, sem dados pessoais) |
| `admin-usuarios` → Supabase Auth Admin API | `auth.users` | `criar`: `auth.admin.inviteUserByEmail(email, { redirectTo: '<URL publicada>/definir-senha' })` e depois `insert` em `perfis`; `desativar`: `perfis.ativo = false` e `auth.admin.updateUserById(user_id, { ban_duration: '876000h' })`; `reativar`: `ativo = true` e `ban_duration: 'none'` | Service role | Se o `insert` em `perfis` falhar depois do convite, a função apaga o usuário recém-convidado (`auth.admin.deleteUser`) para não deixar órfão | Erro do Auth repassado como 502 com mensagem "Não foi possível enviar o convite. Tente novamente." |

| Regra de negócio | Condição | Ação/resultado | Exceção | Fonte |
|---|---|---|---|---|
| RN-01 | Usuário autenticado com `perfis.ativo = true` | Entra e é redirecionado para o destino do papel | Perfil inexistente ou inativo: sessão encerrada e mensagem "Seu acesso está desativado. Fale com o administrador." | §4.1, §9.1 |
| RN-02 | Papel `vendedor` | `codigo_vendedor_focco` obrigatório | — | §4.1 |
| RN-03 | Menu lateral | Ordem e visibilidade finais por papel (§4.2): Meu dia (vendedor, supervisora) · Carteira (vendedor, supervisora, diretoria, admin) · Oportunidades (vendedor, supervisora, diretoria) · Novos clientes (vendedor, supervisora, diretoria) · Pós-venda (vendedor, supervisora, diretoria) · Lotes C/D (supervisora, diretoria, pcp) · Supervisão (supervisora) · Painéis (vendedor, supervisora, diretoria, pcp) · Administração (admin; supervisora vê só Parâmetros). Nesta SPEC entram Carteira e Administração; os demais são ligados pelas SPECs que os entregam | — | §4.2 |
| RN-04 | Mais de 12 h sem atividade (clique, tecla ou navegação) | No próximo carregamento ou foco da aba, a interface chama `signOut()` e leva para `/login` com o aviso "Sua sessão expirou por inatividade." | — | §12.1 |
| RN-05 | Login bem-sucedido | Chama `registrar_acesso()` | Falha da RPC não bloqueia o login | §12.1 |
| RN-06 | Tentativas de login | Mensagem genérica "E-mail ou senha incorretos." (não revela se o e-mail existe) | — | §12.1 |
| RN-07 | Desativação | O usuário perde o acesso na próxima renovação de sessão (até 1 h) e imediatamente nas consultas, porque `papel_atual()` devolve null para inativo | — | §12.1 |

## Identidade visual (obrigatória em toda a Central Sly)

| Elemento | Valor |
|---|---|
| Vermelho Sly (primária, ação principal, item ativo, críticos) | `#ED1C24`; hover `#C8141B` |
| Grafite (sidebar, títulos) | `#111213`; superfícies escuras `#202020`, `#303235` |
| Ardósia (títulos secundários, ícones, gráficos) | `#2C3E50` |
| Texto | principal `#111213`; secundário `#707980`; terciário `#696969` |
| Fundo da aplicação / cartões / bordas | `#F6F6F6` / `#FFFFFF` / `#D9D9D9` (1 px) |
| Apoio de dados | teal `#86B0B6` e `#91CCD2` |
| Status | Ativo `#1E9E5A` · Em atenção `#E8A317` · Em queda `#ED1C24` · Inativo `#696969` |
| Títulos e números de KPI | Montserrat 700; letter-spacing −0,5 px nos títulos e −1 px nos números grandes |
| Corpo, tabelas e formulários | Figtree 400/500/600 |
| Rótulos (seções, cabeçalho de tabela, badges) | Figtree 700, 11–12 px, MAIÚSCULAS, letter-spacing 0,06 em, cor `#707980` |
| Formas | raio 10 px (cartões) e 8 px (botões, inputs); sombra `0 1px 2px rgba(17,18,19,.06)`; grid de 8 px |
| Detalhe de marca | faixa vermelha de 3 px à esquerda do item ativo do menu |
| Ícones | lucide-react, traço 1,75 |
| Logo | `https://www.slyparts.com.br/wp-content/uploads/2025/01/Sly-Parts_vertical-300x171.png` |

Os tokens são definidos como variáveis CSS do tema shadcn/Tailwind (`--primary`, `--background`, `--card`, `--border`, `--muted-foreground` etc.), e nenhuma cor é escrita direto nos componentes.

## Fluxo e regras

1. O usuário abre a URL publicada da Central Sly e vê a tela de Login:
   - painel esquerdo grafite com a logo, o título "Central de Inteligência Comercial" e a frase "Sua carteira, ativa todos os dias.";
   - formulário à direita;
   - no celular, aparece somente o formulário com a logo.
2. Ele informa e-mail e senha. Com credenciais válidas e perfil ativo, a interface chama `registrar_acesso()` e redireciona conforme o papel (RN-01).
3. A casca mostra:
   - sidebar grafite de 248 px, recolhível para ícones, com logo, menu por papel (RN-03) e, no rodapé, avatar com iniciais, nome, papel e "Sair";
   - barra superior branca com o título da página (Montserrat 700, 24 px) e subtítulo `#707980`.
   - No celular, a sidebar vira barra inferior com os itens do papel.
4. "Esqueci minha senha" envia o e-mail de recuperação (`resetPasswordForEmail`) com retorno para `/definir-senha`. A tela sempre responde "Se o e-mail estiver cadastrado, você receberá o link." (RN-06).
5. `/definir-senha` aceita o link de convite e o de recuperação. Exige nova senha e confirmação iguais, com no mínimo 8 caracteres, e depois leva ao destino do papel.
6. Administração › Usuários (admin):
   - tabela com Nome, E-mail, Papel (badge), Código FOCCO, Situação (Ativo/Inativo), Último acesso, ações;
   - botão "Novo usuário" abre um formulário com validação por campo; o código FOCCO aparece e passa a ser obrigatório quando o papel é vendedor;
   - ações por linha: Editar, Desativar/Reativar (com confirmação) e Reenviar convite (somente para quem nunca acessou);
   - toda ação mostra toast de sucesso ou erro em português.

| Cenário | Dado/condição | Resultado esperado | Caminho de erro/recuperação |
|---|---|---|---|
| Principal | Vendedor ativo faz login | Cai em `/carteira`; menu com Carteira | — |
| Principal | Admin cria vendedor com código FOCCO `12` | Convite enviado; linha aparece como Ativo e "Nunca acessou" | — |
| Limite | Admin cria vendedor sem código FOCCO | Formulário bloqueia: "Informe o código do vendedor no FOCCO." | Corrigir e salvar |
| Limite | E-mail já cadastrado | 409 → toast "Já existe um usuário com este e-mail." | Editar o usuário existente |
| Falha | Usuário desativado tenta entrar | Mensagem de acesso desativado; nenhuma página interna abre | Admin reativa |
| Falha | Supervisora chama `admin-usuarios` | 403; nada muda | — |
| Falha | Aba aberta há 13 h sem uso | Ao focar, volta ao login com aviso de inatividade | Novo login |

## Instruções de execução para o Ethos

1. **Ler antes de alterar:** `02-Escopo-Definitivo.md` §4, §5, §9.1, §9.12 e §12; esta SPEC inteira.
2. **Alterar somente:**
   - configurações de Auth listadas;
   - migração com `perfis`, `auditoria`, funções e políticas desta SPEC;
   - Edge Function `admin-usuarios`;
   - rotas e layout listados.
3. **Não alterar:** tabelas, telas ou funções das SPECs 1-002 a 1-011. Não criar páginas de módulos de outras fases. Não expor a service role na interface.
4. **Executar nesta ordem:**
   1. Migração SQL e políticas.
   2. Teste SQL de RLS (TDD RED/GREEN 1).
   3. Edge Function.
   4. Telas de autenticação e casca visual.
   5. Administração › Usuários.
   6. Cadastro dos usuários reais.
5. **Parar e pedir validação quando:**
   - faltar e-mail ou código FOCCO de alguém;
   - o convite não chegar depois de reenviado;
   - o Supabase exigir plano pago para alguma configuração listada.
6. **Estado válido ao parar:** login funcionando para os usuários já criados; nenhuma política aberta (`using (true)`) em `perfis`.

## Checklist de execução

- [ ] Cadastro público desativado e senha mínima de 8 caracteres configurada no Supabase Auth
- [ ] `perfis`, `auditoria`, funções e políticas criadas, com RLS ativada e forçada
- [ ] Edge Function `admin-usuarios` publicada e recusando chamada de quem não é admin
- [ ] Login, recuperação e definição de senha funcionando com a identidade visual
- [ ] Menu e destino por papel conforme RN-03 e as decisões fechadas
- [ ] Expiração por inatividade testada
- [ ] 7 usuários iniciais criados e com primeiro acesso realizado
- [ ] Evidências salvas em `05_entregas/fase-1/SPEC-1-001/`

## Critérios de aceite

- [ ] **CA-1-01:** Cada um dos 7 usuários iniciais entra com o próprio e-mail e cai na tela definida para o seu papel.
- [ ] **CA-1-02:** Executando como vendedor no SQL Editor (TDD GREEN 1), `select count(*) from perfis` devolve 1; como supervisora, devolve o total de perfis.
- [ ] **CA-1-03:** O admin cria um usuário pela tela, o convite chega, a pessoa define a senha e entra; supervisora e vendedor recebem 403 ao chamar `admin-usuarios`.
- [ ] **CA-1-04:** Um usuário desativado não consegue entrar e não lê nenhum dado; reativado, volta a entrar.
- [ ] **CA-1-05:** Telas de login e casca seguem a tabela de identidade visual (cores, fontes, logo) no computador e no celular (largura de 390 px).

## TDD da SPEC

| Etapa | Prova | Comando/ação | Resultado esperado | Evidência |
|---|---|---|---|---|
| RED 1 | RLS de `perfis` ausente | Antes das políticas, no SQL Editor: `begin; set local role authenticated; set local request.jwt.claims = '{"sub":"<user_id do vendedor teste>","role":"authenticated"}'; select count(*) from perfis; rollback;` | Retorna todos os perfis (falha do CA-1-02) | `05_entregas/fase-1/SPEC-1-001/rls-red.png` |
| GREEN 1 | RLS aplicada | Mesmo comando depois da migração, com vendedor, e repetido com supervisora | Vendedor = 1; supervisora = total | `rls-green.png` |
| RED 2 | Função sem checagem de papel | `curl -X POST <url>/functions/v1/admin-usuarios` com o cabeçalho de autorização Bearer contendo o JWT da supervisora e corpo `{"acao":"criar","nome":"Teste","email":"teste.criado@...","papel":"pcp"}`, antes de implementar a checagem | Usuário criado indevidamente | Log do teste |
| GREEN 2 | Checagem de papel | Mesmo `curl` com JWT de supervisora e depois com JWT de admin | Supervisora 403; admin 200 com convite enviado | Saída do `curl` |
| GREEN 3 | Login por papel | Entrar com 1 usuário de cada papel | Destinos: `/carteira` ×3 papéis, `/admin/usuarios` (admin) | 4 capturas |
| REFACTOR/REGRESSÃO | Inatividade e desativação | Alterar no navegador a marca de última atividade para 13 h atrás e focar a aba; desativar usuário teste e tentar login | Volta ao login com aviso; desativado bloqueado | 2 capturas |

**Dados/fixtures:** 2 usuários de teste (`teste.vendedor@` e `teste.supervisora@` no domínio de e-mail da Platina), criados antes dos reais e **desativados** ao final.  
**Caminhos de erro obrigatórios:** e-mail duplicado, vendedor sem código FOCCO, papel não autorizado chamando a função, usuário inativo, sessão expirada, convite com link vencido (a tela `/definir-senha` mostra "Link expirado. Peça um novo convite ao administrador.").  
**Evidência exigida:** capturas e saídas citadas, salvas em `05_entregas/fase-1/SPEC-1-001/`.

## Handoff e operação

- **Como demonstrar:**
  1. Marco cria um usuário ao vivo.
  2. A pessoa recebe o convite e entra.
  3. Um vendedor entra e mostra o menu reduzido.
  4. Marco desativa o usuário teste.
- **Como operar depois:** Marco administra os usuários. Uma troca de vendedor exige atualizar o código FOCCO no perfil.
- **Como monitorar:** coluna "Último acesso" na Administração; a auditoria registra toda alteração de perfil.
- **Pendência conhecida:** nenhuma.

## Tasks vinculadas

| ID | Task | Dono | SPEC | Critério | Recorte da prova | Evidência esperada | Pré-condições | Status |
|---|---|---|---|---|---|---|---|---|
| 1.01 | Criar `perfis`, `auditoria`, funções de papel e políticas RLS | Marco Carvalho | SPEC-1-001 | CA-1-02 | RED 1 → GREEN 1 | `rls-red.png`, `rls-green.png` | Supabase conectado ao Skip | ☐ |
| 1.02 | Publicar Edge Function `admin-usuarios` e tela Administração › Usuários | Marco Carvalho | SPEC-1-001 | CA-1-03, CA-1-04 | RED 2 → GREEN 2 | Saídas do `curl`; captura da tela | 1.01 concluída | ☐ |
| 1.03 | Construir login, recuperação/definição de senha, casca visual e destino por papel | Marco Carvalho | SPEC-1-001 | CA-1-01, CA-1-05 | GREEN 3 e REGRESSÃO (inatividade) | 4 capturas por papel + captura no celular | 1.01 concluída | ☐ |
| 1.04 | Cadastrar os 7 usuários iniciais e confirmar o primeiro acesso de cada um | Marco Carvalho | SPEC-1-001 | CA-1-01, CA-1-04 | GREEN 3 com usuários reais; REGRESSÃO (desativação do usuário teste) | Captura da lista de usuários com "Último acesso" preenchido | 1.02 e 1.03 concluídas; lista de e-mails e códigos FOCCO | ☐ |

## Emendas

<!-- Append-only (D19): mudanças aprovadas depois da geração. A história não é reescrita. -->

| Data | Origem do sinal | Micro-spec/task | Motivo |
|---|---|---|---|
| | | | |
