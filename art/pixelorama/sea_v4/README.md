# Barco v4 — revisão exclusiva do casco

O pedido desta revisão foi aumentar e harmonizar somente o barco. O casco tem 74 unidades de comprimento de base (proa 46 + popa 28, antes 50) e 28 de boca máxima (antes 17). A popa curta mantém a atracação existente; a proa ganha espaço. Bancos, fundo rebaixado, tábuas com emendas desencontradas, pequenos pregos e amarras usam madeira escura/desaturada e a referência visual do navio de `assets/world/port_pixel_v7.png`.

A pintura é feita em pixels nativos pelo construtor `tools/pixelorama/build_boat_hull_v4.py`. A textura segue coordenadas da madeira, não ruído da tela, mantendo-se estável nas 16 direções. Não há escala do personagem nem ampliação dos remos. A física, raio de colisão, movimento, câmera, temporização, entrada/saída, controles, missões e saves não foram modificados.

`boat_v4.pxo` tem cinco camadas independentes:
1. casco e interior;
2. remos internos/distantes preservados;
3. Senu v3 preservado;
4. costado próximo do casco;
5. trecho externo do remo próximo preservado.

Os 160 cels de Senu são copiados diretamente do PXO v3. Os remos usam o mesmo renderizador e o mesmo `boat_v3/oar_contacts.json` aprovado, sem modificar pegadas, apoio, pá ou ritmo. O canvas passou de 96×80 para 128×96 e o pivô de (48,54) para (64,64). Essa diferença é só margem transparente: corpo e remos recebem (+16,+10) na folha, que é cancelado pelo novo pivô, mantendo suas coordenadas no mundo exatamente iguais.

Contrato: 16 tags, repouso 0, remadas 1..8 e vazio 9. PNG/JSON/manifesto são exportados pelo Pixelorama. Abra o `.pxo` para editar e depois rode `tools/pixelorama/export_boat_hull_v4.ps1`; o exportador nunca reconstrói a fonte. O construtor recusa sobrescrever fonte existente sem `--replace-generated`. As fontes v1/v2/v3 foram preservadas.

QA: `qa/boat_hull/directions.png` e `barco_maior.gif`, importação, `tests/senu_boat_animation_test.gd` e `tests/boat_test.gd -- --qa`. As verificações de preservação de corpo/remos comparam coordenadas relativas aos pivôs, e não a posição na folha maior. O STATUS registra somente testes realmente executados nesta revisão.
