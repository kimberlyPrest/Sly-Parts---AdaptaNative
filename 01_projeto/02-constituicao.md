# Constituição técnica da Central Sly

Princípios fixos para quem constrói ou altera o sistema. Valem para todas as fases.

## Stack
- **Interface:** Skip — Vite + React + TypeScript + Tailwind + shadcn/ui; gráficos com Recharts; planilhas com SheetJS (`xlsx` 0.20.3, pacote oficial).
- **Back-end:** Supabase — PostgreSQL com Row Level Security, Auth (e-mail e senha), Edge Functions, Storage e pg_cron.
- **Fuso:** America/Sao_Paulo. Jobs pg_cron escritos em UTC (BRT + 3 h).

## Dados
- O **FOCCO é a fonte oficial** e é somente lido. Nada é gravado no FOCCO.
- Tabelas e colunas em português, `snake_case`, sem acento. Toda tabela tem `id`, `criado_em` e `atualizado_em`.
- Códigos de item e cliente normalizados (`normalizar_codigo`); telefones normalizados (`normalizar_telefone`, formato `55DDDNÚMERO`).
- Valores comerciais líquidos (venda − devolução; nota cancelada ignorada).

## Segurança
- RLS ativada e forçada em **todas** as tabelas. Permissão é garantida no banco, não só na tela.
- Papéis: `vendedor`, `supervisora`, `diretoria`, `pcp`, `admin`. Vendedor vê só a própria carteira.
- Chaves e credenciais somente nos segredos do Supabase ou em arquivos locais protegidos; nunca no código da interface nem neste repositório.
- Alterações relevantes registradas em `auditoria`.

## Interface
- Identidade visual Sly Parts (cores, fontes e componentes) conforme a SPEC-1-001.
- Português do Brasil; datas `dd/mm/aaaa`; valores `R$ 1.234,56`.
- Responsiva (computador e celular a partir de 390 px); estados vazio, carregando e erro em todas as telas.

## Qualidade
- Toda entrega segue uma SPEC com critérios de aceite e TDD (RED → GREEN → REGRESSÃO).
- Evidências em `05_entregas/fase-N/<SPEC>/`.
- Nenhuma funcionalidade fora das SPECs sem emenda aprovada.
