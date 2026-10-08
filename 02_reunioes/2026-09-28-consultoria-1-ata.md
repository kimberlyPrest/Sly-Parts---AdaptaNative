# Ata de reunião

- Reunião: Adapta Native 1 Consultoria <> SLY Parts (Platina)
- Data: 2026-09-28
- Link tl;dv: https://tldv.io/app/meetings/6aba72cd35facb00131351fd
- Fonte: transcrição `2 consultoria.md`.

## Objetivo da reunião
Apresentar as ferramentas Skip e Maestro, conectar as integrações básicas e alinhar o escopo do sistema comercial da Sly Parts.

## Participantes
- Kimberly Prestes — Consultora (Adapta)
- Gabrielle Brust — Sponsor (Platina / Sly Parts)
- Ângela Ferreira — Supervisora de Vendas (Platina)
- Marco Carvalho — TI (Platina)

## Ferramentas apresentadas
- **Skip:** construção de sistemas por prompt; GitHub conectado; 5 licenças de convite disponíveis; publicação com link e login próprio.
- **Maestro:** agente autônomo com memória, automações, conectores e skills. Será usado para automações sobre o sistema pronto (ex.: enviar ao vendedor a lista de clientes a acionar no dia), não para a operação comercial em si, por custo.
- **Supabase:** banco de dados do sistema, no lugar do banco embutido do Skip, pela complexidade das integrações e dos agentes previstos.

## Decisões
- O projeto é um sistema de **inteligência comercial da carteira**: transformar a carteira passiva em demanda ativa e sistemática.
- A primeira parte é **determinística**: queda de consumo, recompra vencida e cliente parado geram ações de reativação; painel de carteira, painel de oportunidades e rotina comercial diária com ações priorizadas, resultado obrigatório e alerta de estagnação ao gestor.
- Será acrescentado um **CRM** (comercial e pós-venda) e o **WhatsApp integrado** ao sistema, com cada vendedor atendendo a própria carteira dentro do sistema.
- WhatsApp via **Z-API** (API de menor custo e mais estável), sem disparo em massa.
- Teams e e-mail não terão integração automática; servem para alimentar o histórico.
- A carteira é fixa e recorrente (rede nomeada). Por isso o funil de vendas vale só para novas oportunidades, e não é a rotina principal (Ângela).
- O sistema deve consultar cadastro de clientes e estoque do FOCCO, conforme o que a API oferecer.

## Pendências / próximos passos
- [ ] Marco: pedir à Focco a documentação da API.
- [ ] Marco: criar conta no Supabase e conectar ao Skip (Configurações → Integrações).
- [ ] Marco: criar conta na Z-API.
- [ ] Kimberly: escrever o escopo detalhado e enviar ao grupo para comentários.
- [ ] Ângela: revisar o escopo e comentar regras que não façam sentido.
- [ ] Agendar a reunião de início da implementação depois da revisão da Ângela.
