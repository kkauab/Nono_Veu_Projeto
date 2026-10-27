# Abertura de RPG — chegada ao Porto dos Esquecidos

A abertura atual é uma pequena cena de RPG encenada em tempo real. Senu chega de barca, desembarca, conversa com um pescador e segue uma pista sobre seu mestre. Não é uma sequência de ilustrações nem um vídeo. A direção anterior de três planos foi substituída a pedido do usuário.

## Contexto e diálogo

O diálogo atual foi aprovado pelo autor antes da implementação e está em `resources/dialogue/opening_fisherman.gd`. O pescador ajuda a receber a corda antes de Senu desembarcar. No cais, Senu explica que procura Iri após o ataque à ordem. O pescador viu um homem com livros embrulhados seguir entre os armazéns; não sabe se era Iri. A Inversão ganha um exemplo humano: o irmão perguntou o preço de uma rede que ele próprio ensinou o pescador a fazer. Senu promete voltar com o que descobrir. A localização da guarita permanece como descoberta da exploração, sem antecipar a inscrição de Iri.

Há 24 falas com digitação gradual e pausas de pontuação. A primeira acontece na barca, no marco 1,8; Senu desembarca depois da interação e as demais começam no marco 4. **Enter, E ou clique na caixa** durante a escrita revela a fala completa; outra interação continua. A cena espera a leitura do jogador. Portanto, o tempo real varia: `DURATION = 21` identifica o último marco da encenação, não uma duração fixa imposta às falas. Os deslocamentos são automáticos e mostram os quadros reais de caminhada de Senu. A contagem e os marcos de diálogo derivam da lista aprovada.

O componente reutilizável `scripts/ui/portrait_dialogue.gd` mostra Senu à esquerda e o pescador à direita, recortados diretamente sobre o cenário, sem fundos ou molduras individuais. A caixa inferior fica à frente dos retratos e cobre a base dos bustos, conservando a identidade escura e hermética. Somente o interlocutor atual anima boca e piscadas; o ouvinte fica imóvel em repouso, com a expressão de sua última fala própria. A atuação usa ritmo próprio, com aberturas de boca e pequenas pausas independentes da digitação. Revelar o texto inteiro não acelera nem reinicia a atuação; avançar a fala encerra a entrega. Cada personagem tem quatro expressões. Os tempos foram escolhidos por fala em `DELIVERY_SECONDS`, sem cálculo por letras, vogais ou pontuação. Detalhes da API em [SISTEMA_DIALOGO_RETRATOS.md](SISTEMA_DIALOGO_RETRATOS.md).

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
- A câmera enquadra os dois atores entre os bustos e acima da caixa. O pescador recebe a corda e depois retorna à rede de trabalho. O mundo real e o HUD de exploração permanecem pausados durante a cena.
- Retratos de diálogo: `assets/ui/dialogue_v15/senu.png` e `fisherman.png`. São folhas novas de 20 poses completas por personagem, com quatro expressões e cinco estados: repouso, duas aberturas de boca, olhos semicerrados e olhos fechados. As fontes nativas ficam em `art/pixelorama/dialogue_v15/`, com os originais gerados e prompts preservados. Os PNGs são exportados pelo Pixelorama; a versão anterior com retoques de olhos e boca não é usada pela interface atual.

## Arquivos e verificação

- Componente: `scripts/ui/opening_cutscene.gd`.
- Água: `assets/shaders/opening_rpg_water_v11.gdshader`.
- API: `begin()`, `finished`, `elapsed`, `seek(seconds)`, `dialogue_active`, `dialogue_index`, `dialogue_visible_characters` e `advance_dialogue()`.
- Testes: `tests/opening_rpg_v11_test.gd`, `tests/portrait_dialogue_integration_test.gd` e `tests/opening_flow_v9_test.gd`. Exercitam as 24 falas, atuação independente do texto, ouvinte imóvel, interação por clique e teclas, layout 720p/1080p, desembarque, salto contínuo, proteção do jogador e retorno dos controles. Os registros atuais ficam em `qa/portrait_dialogue_*`.
- Capturas em `qa/opening_rpg_v11_boat.png`, `opening_rpg_v11_landing.png`, `opening_rpg_v11_dialogue.png`, `opening_rpg_v11_reply.png` e `opening_rpg_v11_leaving.png`.
- Captura de quadros: `tools/qa/capture_opening_rpg_v11.gd`.
- Gravação para revisão: `tools/qa/film_opening_rpg_v11.gd`. Somente esse roteiro de QA envia Enter automaticamente após tempo de leitura; a versão do jogo espera o jogador.

A chamada obrigatória de Nova jornada e a persistência ficam em `port_demo.gd`, validadas por testes de integração separados. Os antigos nomes de teste/captura `*_v9` continuam como atalhos para a cena atual.

`ABRIR_SENU_DIALOGO_PIXELORAMA.cmd` e `ABRIR_PESCADOR_DIALOGO_PIXELORAMA.cmd` abrem os bustos. `EXPORTAR_RETRATOS_DIALOGO.cmd` exporta os dois; `EXPORTAR_ABERTURA.cmd` exporta todos os projetos da abertura e importa no Godot.

