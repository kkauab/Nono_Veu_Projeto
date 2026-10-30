# Estado atual — O Nono Véu
Atualizado em 2026-10-30; base: `A:\nono veu` (máquina do Gustavo; a do Kauã é `D:\Nono_Veu`).

## Funcionalidades existentes
- Demo do Porto dos Esquecidos: 33 setores, atalhos, três puzzles de selos, chefe e entrada demonstrativa das Catacumbas.
- Senu: oito direções, caminhada/corrida, esquiva, ataques leves/fortes, parry, riposta; Khopesh e Adagas com poderes próprios.
- Inimigos animados, combate com efeitos/sons, XP, níveis, óbolos e drops; 13 habilidades na Árvore das Emanações.
- Moradores v3 (16 aparências: 12 do Kauã + 4 em `townsfolk_v3_extra.png`); aves e cães/gatos com fuga, pouso e colisão revisados.
- Claustro dos Iniciados junto ao santuário inicial; barco de Sabu até a Ilha do Bennu, a Ilha do Íbis Afogado e o Recife do Navio Esquecido.
- Mar com crocodilos do Nilo e de Sobek: mordem o casco, o barco pode afundar e Senu nada até escadas nos paredões.
- Ambientação por setor (som, vento, zumbido sagrado, luz); comércio, interiores, Mendigo das Cordas com alaúde.
- Menu animado, fonte Pixel Operator, bustos vivos, caderno de pausa e persistência restrita às torres.

## Última entrega (30/10) — junção do `3135f61` do Kauã, expansão e mar perigoso
- `gustavo/dev` partiu da `main` do Kauã (`eac8db1`); trabalho enviado à `gustavo/dev` a pedido do Gustavo (sem PR).
- Junção: `townsfolk.gd` usa a v3 do Kauã; nos 12 originais, `townsfolk_v1.png` voltou aos pixels de origem. `portrait_dialogue.gd` aceita retratos de um quadro.
- Fauna e moradores: poleiros presos a peças reais, susto lido por `fauna_threat.gd`, animais que deslizam em quinas e evitam água; moradores contornam Senu; Mendigo toca de pé.
- Mapa: Claustro (estelas abrem a Arca do Noviço), ilhas Íbis (enigma olho → pena → junco) e Recife (caixas, ânforas, arca do capitão), 96 peças nos setores vazios; 20 perfis de ambientação; 45 inimigos (614 XP, 311 óbolos).
- Vida nas áreas novas: 7 moradores, o Salgador, falcão, gaivotas, garça e gato. `port_demo.gd` monta ilhas e Claustro antes da vida.
- Mar: `sea_beasts.gd` (6 crocodilos), casco de 100 em `sea_boat.gd`, naufrágio em `sea.gd`, nado em `sea_swim.gd`, escadas em `sea_ladders.gd` (só em chão sem portão). Arte: `build_sea_v2.gd` → `sea_beasts_v1`. Detalhes em `MUNDO_BARCO_ILHA.md`.
- Sem campo novo no save; ids novos em `collected`. Análise do mapa: `docs/MUNDO_PROPOSTA_2026-10-30.md`. Capturas: `qa/mar/`, `qa/mapa/`, `qa/vida_novas/`, `qa/fauna_moradores/`.
- QA (`-- --qa`): bichos do mar 355, aves 469 (sorteio fixo), animais 118, fauna no mapa 163, vida no porto 367, NPC v3 2468, v3 extra 302, v2 286, Claustro 38, ilhas 107, ambientação 129, percurso 139, chão 2007, profundidade 293, mundo 134, barco 75, transferência 85, Senu no barco 683, ilha 59, torres 28, abertura 24, caderno 8254, menu 25, popup 32, missões 72, economia 45, combate 26.

## Pendências
- Falhas que já existem na `main` do Kauã (conferido numa cópia limpa): `progression_test` 122/123, `house_interior_test` 53/54 e `save_migration_test` 26/28. Três esperam gravar fora da torre; uma procura o botão "Iniciar nova jornada" fora do popup novo.
- `npc_walk_assets_test`: falta `assets/world/npc_walk_v4.png` (e manifesto), que o Kauã não enviou.
- `title_menu_test` pode falhar no som de seleção quando a máquina está carregada (passa 3/3 em condições normais).
- Retratos `dialogue_v15` divergem da aparência v3 (escriba, peregrina, aguadeira, padeira, estivador...); "Caravaneiro" usa o retrato do cervejeiro.
- HUD chama todo o mar de "Baía das Garças"; Arquivo, Praça dos Sinos e Observatório seguem o molde comum.
- Os caminhos dos moradores não enxergam as estelas e fixtures das ilhas (fora de `world_obstacles`).
- Ainda não há como entrar na água de propósito; nadar só depois de naufragar.
