# Porteiro Sem Nome — fonte funcional v7

Oito vistas próprias, 167 cels por vista, cinco camadas: arma atrás, manto, corpo, rosto/cabelo, arma à frente. O rosto frontal v3 preferido pelo jogador foi preservado em pixels; as vistas traseiras usam cabelo. Não há espelhamento do personagem inteiro ou troca de mão da chave-lança.

Corpo57 px, tela192² e pivô(96,144). A tela maior acrescenta margem para ataques no chão, sem ampliar o corpo. Caminhada16 poses, assentamento32, nove golpes de9 poses, idles e atuação narrativa. Fontes foram construídas localmente com articulações/recortes dos concepts e composição em pixels; não são 1.336 desenhos manuais feitos na interface do Pixelorama.

`porteiro_live_v7.pxo` contém o mestre. `directions/*.pxo` permitem editar/exportar uma vista por vez sem carregar uma exportação gigante. `export_plan.json` mantém poses, tempos, direções, camadas e referências. Hashes impedem reconstruir sobre uma fonte/export manual alterado.

Pipeline, a partir da raiz do projeto:

1. `build_gatekeeper_live_v7.py` constrói a fonte inicial; não rodar após retoques manuais sem preservar as edições.
2. `split_gatekeeper_live_v7.py` separa vistas; `export_gatekeeper_live_v7.ps1` exporta pelo Pixelorama, com retomada por pasta de staging.
3. `pack_gatekeeper_live_v7.py` compacta os PNGs realmente exportados, preservando offsets/pivôs, e importa no Godot.
4. `validate_gatekeeper_live_v7.py` compara cada pixel de cada export com as camadas nativas e confere rosto, margens, alpha e tempos JSON.

Export preservado: `assets/sprites/porteiro_live_v7.png` + manifesto, 2048×2208/~18 MB RGBA. Fontes antigas V1–V6/ensaios preservados. O jogador rejeitou a silhueta tubular traseira; a revisão seguinte vive em `porteiro_live_v8`, mantendo estes originais. Detalhes de integração e limites em `docs/PORTEIRO_SEM_NOME.md`.
