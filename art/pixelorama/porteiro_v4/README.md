# Porteiro — revisão de presença v4

**Estudo de arte para avaliação. Ainda não ligado ao chefe da partida.** Mesma altura de referência da v3 (57 px), canvas 160×160, pivô (80,140) e vista-piloto `down_right`. A orientação do jogador é melhorar a presença e a qualidade dos sprites no mapa.

## Revisão atual

- Rosto original da **v3 restaurado**, por preferência explícita do jogador. A camada do rosto/cabelo é idêntica à v3 nos 18 cels; não redesenhar olhos, boca ou expressão automaticamente.
- Manto com silhueta mais ampla e tecido posterior ligado a ombros/quadril. A humanidade, o corpo magro e a roupa gasta permanecem.
- Chave-lança com volume de bronze, dentes de chave, bordas gastas, correntes curtas e sinos; placas com nomes presas à cintura e bronze incompleto em um ombro.
- Guarda, caminhada de oito fases e estocada de nove fases mantêm a atuação da v3: duas mãos na haste, recolher, carregar o corpo, antecipar, estocar e recuperar.

A proposta anterior de rosto iluminado/extraído do painel de expressões foi rejeitada. Não é a versão atual. Os refinamentos de manto e arma foram conservados durante a restauração do rosto.

## Fontes e produção

`porteiro_v4.pxo` tem quatro camadas editáveis (manto, corpo, rosto e arma/mãos), 18 cels e tags. PNG/JSON/manifest são exportados pelo Pixelorama 1.2.3 para `assets/sprites/porteiro_v4*` e importados pelo Godot 4.7.2. A fonte é derivada dos concepts do jogador com trabalho local de textura, articulação e pixels; não foi desenhada manualmente na interface do Pixelorama. Nenhuma API paga utilizada.

Com Python/Pillow, Pixelorama e Godot disponíveis:

```powershell
python -B tools/pixelorama/build_gatekeeper_art_v4.py
& tools/pixelorama/export_gatekeeper_art_v1.ps1 -ArtVersion 4
python -B tools/pixelorama/validate_gatekeeper_art_v3.py --version 4
godot --path . --script res://tests/gatekeeper_art_preview.gd -- --qa --world
```

Os construtores v1/v2/v3 são dependências de utilidades, texturas e atuação; preservá-los. `generated_hashes.json` protege edições manuais contra regeneração. Depois de editar o `.pxo`, exportar a fonte editada; uma reconstrução incompatível exige uma versão nova. O exportador também protege edições manuais dos arquivos de destino.

## Avaliação e limites

`qa/porteiro_art_v4/`: GIFs de caminhada e estocada, pranchas, provas na arena, logs e relatório de validação. O validador compara pixels exportados com as quatro camadas, alfa/paleta, margens, mãos/haste, apoio e rosto; também compara a camada de rosto de cada cel com a v3. A leitura artística e a naturalidade dependem da avaliação do jogador.

Não expandir esse estudo como se todas as direções/clipes estivessem aprovados. Outras vistas, ataques, hitboxes, fases, narrativa, recompensas e persistência do novo chefe continuam pendentes; Senu e os inimigos comuns estão preservados.
