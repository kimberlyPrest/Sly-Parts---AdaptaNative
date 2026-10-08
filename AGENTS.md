# Central de Inteligência Comercial Sly Parts — instruções para o agente

Este repositório é a pasta operacional da Platina (Sly Parts) no programa Adapta Labs Native. Ele contém o escopo, a fase atual com as SPECs e as tasks, e o lugar para registrar entregas e notas.

## Como trabalhar
1. Comece por `STATUS.md` e `04_fase-atual/fase.md` (tabela `## Tasks`).
2. Execute **uma task por vez**, respeitando a coluna "Pré-condições" e a "Leva".
3. Antes de alterar qualquer coisa, leia a SPEC da task em `04_fase-atual/specs/`, principalmente "Contexto e decisões fechadas", "Instruções de execução para o Ethos" e "TDD da SPEC".
4. Faça passar exatamente o "Recorte da prova" indicado na task e salve a evidência em `05_entregas/fase-1/<SPEC>/`.
5. Pare nos pontos de parada da SPEC e da fase. Não invente regra, campo, permissão ou critério de aceite.

## O que não fazer
- Não editar `04_fase-atual/fase.md` nem as SPECs (são seladas por hash em `handoff-manifest.json`). Mudanças são pedidas como **sinal** em `06_notas/sinais.md`; a consultora decide se vira emenda.
- Não criar integrações na fase 1 (FOCCO, WhatsApp, IA, Maestro): os dados do FOCCO entram somente por planilha (SPEC-1-002).
- Não gravar nada no FOCCO.
- Não colocar chaves, senhas ou credenciais em nenhum arquivo deste repositório.

## Stack e princípios
Ver `01_projeto/02-constituicao.md`.
