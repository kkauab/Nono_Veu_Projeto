# Abertura de RPG — chegada ao Porto dos Esquecidos

A abertura atual é uma pequena cena de RPG encenada em tempo real. Senu chega de barca, desembarca, conversa com um pescador e segue uma pista sobre seu mestre. Não é uma sequência de ilustrações nem um vídeo. A direção anterior de três planos foi substituída a pedido do usuário.

## Contexto e diálogo

O pescador situa o jogador no Porto dos Esquecidos, em Alexandria. Senu explica que procura Iri após o ataque à ordem. O pescador viu um homem com um livro embrulhado perguntar pelo Santuário da Primeira Palavra; não afirma saber quem ele era. Senu reconhece um hábito do mestre e decide seguir a pista. A Inversão ganha um exemplo humano: o irmão do pescador esqueceu seu nome. Senu oferece voltar com alguma resposta. São falas originais coerentes com as premissas das seções 3.1 e A01 de `O_NONO_VEU_GDD.md`.

Há seis caixas de diálogo, em duas linhas cada, com revelação gradual a cada 0,02 s por caractere. **Enter ou E** durante a escrita revela a fala completa; outra pressão continua. A cena espera a leitura do jogador. Portanto, o tempo real varia: `DURATION = 21` identifica o último marco da encenação, não uma duração fixa imposta às falas. Os deslocamentos antes e depois da conversa são automáticos e mostram os quadros reais de caminhada de Senu. A contagem e os marcos de diálogo derivam da lista de falas.

## Obrigatoriedade e salto

A cena pertence ao fluxo obrigatório de Nova jornada. Não possui botão de pular, e Esc e cliques não a encerram. É preciso manter **Espaço pressionado por 3 segundos contínuos**, com barra de progresso. Soltar a tecla ou perder o foco da janela cancela o progresso acumulado. Esse relógio funciona mesmo quando a história está esperando uma resposta no diálogo. O salto e o final da encenação emitem `finished` somente uma vez.

## Cenário e animação

- Mapa de chegada independente do mapa explorável, com piso, barca, pescador, lamparinas e placa próprios.
- Atlas do cais `assets/cinematics/rpg_v11/intro_atlas.png`, 512×256. Os quadros 0/1 fornecem piso de pedra/madeira, 6 a lamparina e 7 a placa. As antigas poses 2–5 foram substituídas pelos projetos abaixo.
- Pescador `assets/cinematics/rpg_v12/fisherman.png`, oito poses de corpo adulto a 40 px, com rosto, lenço de linho, túnica, rede e cesto compatíveis com Senu. Fonte `art/pixelorama/fisherman_v13/fisherman.pxo`; geração integrada guiada pela arte de Senu, paleta comum, escala única, exportação real pelo Pixelorama. Caminhada acompanha distância; gestos alternam entre conversa, escuta e despedida.
- Barca `assets/cinematics/rpg_v12/arrival_boat.png`, quatro cels nativos: casco interior, bordo frontal e duas linhas d'água. Fonte de cinco camadas em `art/pixelorama/opening_boat_v12/arrival_boat.pxo`. Perspectiva 2:1, casco paralelo ao cais, bancos, rede, corda e remo guardado. O bordo frontal aparece à frente dos pés do passageiro. A passarela une a entrada do casco à margem real do piso; Senu percorre esses apoios antes de entrar no cais.
- Projeto nativo `art/pixelorama/opening_rpg_v11/intro_atlas.pxo`; exportação pelo Pixelorama instalado. O kit não reutiliza os armazéns, a barca ou o atlas de cenário do jogo.
- Água original animada por shader, bordas com faces de pedra e madeira, estacas de sustentação, corrimão de corda, rolos de amarração e silhuetas discretas do porto ao fundo.
- Senu preserva seu modelo do jogo. O ator da encenação é separado do jogador real, sem colisão e fora do grupo `player`. Seus passos acompanham a distância percorrida, sem alterar o tamanho da imagem.
- A câmera acompanha discretamente a partida; o pescador dá passos para receber Senu e volta à amarração depois da conversa. O mundo real e o HUD de exploração permanecem pausados durante a cena.

## Arquivos e verificação

- Componente: `scripts/ui/opening_cutscene.gd`.
- Água: `assets/shaders/opening_rpg_water_v11.gdshader`.
- API: `begin()`, `finished`, `elapsed`, `seek(seconds)`, `dialogue_active`, `dialogue_index`, `dialogue_visible_characters` e `advance_dialogue()`.
- Teste: `tests/opening_rpg_v11_test.gd`, registro `qa/opening_v13_component.log` — 28 verificações aprovadas, incluindo as seis falas por Enter/E, leitura gradual, pausa, dois deslocamentos reais, proteção do jogador e regra de Espaço.
- Capturas em `qa/opening_rpg_v11_boat.png`, `opening_rpg_v11_landing.png`, `opening_rpg_v11_dialogue.png`, `opening_rpg_v11_reply.png` e `opening_rpg_v11_leaving.png`.
- Captura de quadros: `tools/qa/capture_opening_rpg_v11.gd`.
- Gravação para revisão: `tools/qa/film_opening_rpg_v11.gd`. Somente esse roteiro de QA envia Enter automaticamente após tempo de leitura; a versão do jogo espera o jogador.

A chamada obrigatória de Nova jornada e a persistência ficam em `port_demo.gd`, validadas por testes de integração separados. Os antigos nomes de teste/captura `*_v9` continuam como atalhos para a cena atual.
