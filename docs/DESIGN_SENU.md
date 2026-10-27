# Senu — corpo comum e cortes v8

## Versão atual — 26/10/2026

O corpo utilizado no jogo é `art/pixelorama/senu/senu_shared_v6.pxo`: 232 cels, 35 tags, com caminhada, corrida e rolagem em poses distintas. As duas armas compartilham exatamente os mesmos pixels do corpo durante movimento/repouso. As lâminas são camadas presas aos punhos. A passada acompanha a distância percorrida, sem aumentar/diminuir a imagem. Velocidades: andar 80 e correr 136 unidades por segundo; deslocamento da esquiva 60 unidades.

O ataque atual do Khopesh é `art/pixelorama/senu/senu_sword_v8.pxo`, com 48 cels: seis fases em oito direções. Foram produzidas cinco vistas de corte a partir de uma guia anatômica e do corpo comum; as três vistas à esquerda usam espelhamento. Braço, punho e lâmina estão desenhados juntos, com guarda, antecipação, aceleração, contato, continuação e recuperação. A escala e o apoio dos pés são fixos. O contato leve da espada passou para 0,12 s para dar tempo à preparação; o pesado permanece em 0,24 s, e as adagas mantêm seus dois contatos em 0,075/0,17 s. Prompts em `art/pixelorama/senu/SENU_SWORD_V8_PROMPT.md`. A revisão anterior de cortes está preservada em [SENU_ESPADA_V7.md](SENU_ESPADA_V7.md).

`ABRIR_SENU_PIXELORAMA.cmd` / `EXPORTAR_SENU.cmd` editam e exportam o corpo; `ABRIR_COMBATE_PIXELORAMA.cmd` / `EXPORTAR_COMBATE.cmd`, os cortes. O Pixelorama instalado executa a exportação nativa. As versões antigas abaixo ficam registradas como histórico; seus atlas grandes não são carregados junto com o atual.

O mundo usa uma imagem de 640×360 independente da interface de 1280×720, permitindo texto nítido sobre o cenário em pixels. O retrato do menu usa 12 cels em `art/pixelorama/menu_v8/senu_menu_idle_v8.pxo`: seis para os olhos e seis para a faixa, com movimentos separados. A capa recebe movimento restrito ao mar, ao tecido e à faixa, mantendo o enquadramento estável.

## Histórico v4

## Fluidez e Adagas — 25/10/2026

O projeto atual é `art/pixelorama/senu/senu_v4.pxo`, aberto pelo atalho `ABRIR_SENU_PIXELORAMA.cmd`. Possui 603 quadros e 145 tags. A exportação usa `EXPORTAR_SENU.cmd` e gera `assets/sprites/senu_v4.png`, `senu_v4.json`, `senu_v4_manifest.json` e `resources/characters/senu_v4_frames.tres`. O canvas de 384 × 384, o pivô (192, 280) e a escala 0,26 foram mantidos para encaixar as duas armas na mesma colisão. O atlas usa 16 colunas e 38 linhas, em 6144 × 14592 pixels.

Khopesh e Adagas possuem conjuntos próprios de animação. Cada vista de caminhada tem 12 quadros, com passada alternada, movimento compensado de braços e atraso da capa. O repouso usa quatro quadros. Os intermediários foram preparados com deformação de partes e poses de referência no projeto nativo, sem dissolver imagens sobrepostas. Essa técnica preserva a arte, mas não equivale a desenhar cada quadro do zero.

As Adagas do Reverso têm duas lâminas curtas de metal escuro/prateado com reflexos violetas, guardas pequenas de bronze e cabos de couro. As folhas `sources/daggers_directions_v4.png` e `sources/daggers_combat_v4.png` foram geradas com ImageGen a partir da identidade visual fornecida. Prompts e dimensões reais estão em `art/pixelorama/senu/SENU_V4_PROMPTS.md`. A roupa mantém linho claro, capa verde-petróleo, bronze e couro. As orientações das imagens foram inspecionadas antes de mapear os recortes; vistas de ação ausentes usam aproximação ou espelhamento.

O golpe leve das Adagas tem oito quadros e dois contatos visuais, acompanhando os impactos de 0,075 s e 0,17 s da lógica já existente. A renovação visual do segundo impacto não reinicia o golpe. A recuperação usa a duração real da ação; dano, guarda e esquiva mostram seus quadros dentro da janela de cada estado. O ciclo da caminhada mantém a fase ao mudar de direção ou trocar arma. Dano, alcance, velocidade e colisões não foram alterados.

O Pixelorama executa os efeitos nativos de limpeza e a exportação final. Os projetos anteriores permanecem preservados. O registro v3 abaixo descreve a etapa anterior e suas limitações à época.

## Histórico — sprites fornecidos e projeto Pixelorama v3

Atualizado em 25/10/2026. A apresentação do Khopesh passa a usar as quatro folhas enviadas pelo usuário. O projeto editável é `art/pixelorama/senu/senu_v3.pxo`, no formato nativo do **Pixelorama 1.2.3**. O registro v2, preservado abaixo, descreve a versão Blender anterior.

## Produção v3

Os recortes foram organizados em uma linha do tempo com **124 quadros únicos e 75 tags**. As sequências reutilizam quadros quando duas vistas ou ações compartilham a mesma pose. Os estados disponíveis são: parado, caminhada, ataque leve, ataque forte, esquiva, parry, dano, morte e poder. Armas e efeitos isolados da quarta folha ficam em tags adicionais.

As quatro imagens originais permanecem intactas em `art/pixelorama/senu/sources/`; seus hashes estão no manifesto. A preparação mantém a arte enviada, isola os recortes para excluir fragmentos de desenhos vizinhos e os ajusta à mesma escala e ao mesmo ponto dos pés. Alguns detritos soltos dos efeitos também foram omitidos. Os efeitos de camada nativos do Pixelorama removem resíduos vermelhos, verdes e amarelos e o fundo preto quase transparente, preservando a possibilidade de ajustar ou desativar essa limpeza no editor.

A exportação foi executada pelo próprio Pixelorama, usando sua interface de linha de comando e o renderer Compatibility. O controle da janela do aplicativo não ficou disponível no ambiente; não houve edição manual pela interface. O script de preparação cria o projeto nativo e os recortes, enquanto o Pixelorama processa os efeitos e gera o PNG final.

## Arquivos v3 e uso

| Arquivo | Uso |
|---|---|
| `ABRIR_SENU_PIXELORAMA.cmd` | Abre o projeto de Senu no Pixelorama instalado. |
| `EXPORTAR_SENU.cmd` | Exporta o projeto salvo e atualiza os recursos do Godot. |
| `art/pixelorama/senu/senu_v3.pxo` | Fonte editável com linha do tempo, tags e efeitos de limpeza. |
| `art/pixelorama/senu/sources/` | Cópias preservadas das quatro folhas fornecidas. |
| `assets/sprites/senu_v3.png` | Atlas transparente exportado pelo Pixelorama. |
| `assets/sprites/senu_v3.json` | Metadados nativos exportados pelo Pixelorama. |
| `assets/sprites/senu_v3_manifest.json` | Regiões, sequências, escala e pivô consumidos pelo jogo. |
| `resources/characters/senu_v3_frames.tres` | Recurso SpriteFrames para abrir as animações no Godot. |
| `scripts/actors/senu_supplied_view.gd` | Seleção visual conforme o estado e a direção de Senu. |
| `tools/pixelorama/source_frames.json` | Seleção e ajustes dos recortes das folhas originais. |
| `tools/pixelorama/build_pixelorama_project.py` | Preparação do projeto nativo e finalização do manifesto. |

Para trabalhar no personagem, abra o primeiro atalho, salve as alterações e use o segundo. Depois reinicie a partida para recarregar os recursos. A tela de cada quadro tem **384 × 384 pixels**, o pivô dos pés fica em **(192, 280)** e a escala visual no jogo é **0,26**. O espaço transparente acomoda capas, armas e efeitos; não define o tamanho da colisão.

## Adaptações e limites v3

As folhas recebidas não são grades uniformes. A última linha de movimento tem pés cortados e foi descartada; a caminhada para cima-direita usa espelhamento da vista para cima-esquerda. Outras orientações ausentes usam a vista mais próxima ou espelhamento. A caminhada frontal tem apenas uma pose limpa, portanto ainda não forma um ciclo completo. Essas adaptações não representam novas poses desenhadas do zero.

A Khopesh está incorporada a muitos quadros. Quando esse atlas é usado, o jogo evita sobrepor a espada e os efeitos procedurais antigos. O poder combina a pose de guarda com os arcos dourados fornecidos na quarta folha. **As Adagas ainda usam a apresentação v2**, que possui corpo e equipamentos separados; falta produzir novos quadros sem Khopesh para unificar as duas armas. Os recortes de ação com lâminas e efeitos próximos exigem revisão visual ao criar novos quadros.

Os tempos de dano, movimento, colisões e regras das armas pertencem à lógica do jogo. A apresentação v3 acompanha esses estados, inclusive interrupção por dano e retenção do último quadro de morte. A validação desta integração deve ser consultada em `docs/TESTES.md`; os resultados v2 abaixo são históricos.

## Histórico — design v2 no Blender

Atualizado em 25/10/2026. Primeira versão do personagem desenhada para substituir o corpo geométrico da demonstração inicial. É um design original de trabalho, sujeito à avaliação em jogo.

## Identidade visual

Senu é um viajante e escriba capaz de lutar. A silhueta combina rosto aberto, faixa de linho na cabeça, túnica clara em camadas, lenço e capa assimétrica verde-petróleo, uma ombreira discreta de bronze, talismã geométrico, bolsa de escrita e pergaminho. Couro e tecidos gastos comunicam viagem e investigação. A direção segue a ambientação fantástica Egito–Axum do GDD, sem apresentar o figurino como reconstrução histórica.

A capa teal, o linho areia/marfim e o bronze separam as partes do corpo em vista isométrica. O Khopesh e as Adagas são equipamentos independentes do figurino; nenhuma arma está fundida ao atlas do corpo.

## Referência e arquivos de produção

- `docs/concept_art/senu_design_v2.png`: prancha de referência produzida pela ferramenta integrada ImageGen. Ela reúne figurino, vistas e estudos de equipamento.
- `docs/concept_art/senu_design_v2.prompt.md`: prompt integral da prancha e registro do modo de geração. Não foi utilizado o fallback CLI.
- `tools/blender/senu_character_v2.py`: construção e renderização reproduzíveis do personagem original no Blender.
- `blender/personagens/senu_v2.blend`: fonte do modelo de trabalho.
- `assets/sprites/senu_v2.png`: atlas transparente consumido pelo jogo.
- `assets/sprites/senu_v2.json`: dimensões, ordem das poses e pontos das mãos.
- `assets/sprites/senu_v2_preview.png`: prévia de um quadro.
- `scripts/actors/player.gd`: seleção de direção/pose e desenho das armas e dos efeitos sobre o corpo.

A prancha é uma referência artística separada. Os sprites jogáveis foram modelados e renderizados pelo script Blender; não foram recortados da prancha conceitual.

## Contrato do atlas

| Propriedade | Valor |
|---|---|
| Atlas | 768 × 896 pixels, RGBA |
| Célula | 96 × 112 pixels |
| Organização | 8 colunas de direção × 8 linhas de pose |
| Pivô dos pés | `(48, 94)` em cada célula |
| Escala no jogo | `0.43` |
| Direções | Baixo, baixo-direita, direita, cima-direita, cima, cima-esquerda, esquerda, baixo-esquerda |
| Linhas | Idle; caminhada 1–4; ataque 1–3 |
| Encaixes | Uma posição de mão esquerda e direita por quadro: 128 pontos no total |
| Filtragem | Nearest, sem mipmaps |

O corpo usa 64 quadros. As lâminas são desenhadas separadamente de acordo com a arma equipada e os pontos das mãos exportados pelo Blender. A camada da arma passa atrás ou à frente do corpo conforme a direção. Os arcos de ataque, o brilho de parry, os rastros de esquiva e a imunidade continuam independentes dos sprites e das hitboxes.

## Verificações realizadas

- Prancha, prévia e atlas inspecionados visualmente.
- Blender **5.2.3 LTS**, execução de `--check-atlas`: `SENU_V2_ATLAS_CHECK_OK frames=64 dimensions=768x896 no_clipped_frames`, saída 0.
- Execução de `--check-scene`: `SENU_V2_SCENE_OK 5.2.3 LTS 72 objects pivot (48, 94)`, saída 0.
- Metadados conferidos: oito direções, oito poses, 64 pares de mãos; os 128 pontos ficam dentro das respectivas células.
- Comparação das 18 funções de lógica de Senu com a cópia da primeira demonstração já testada: nenhuma função de movimento, combate, dano, troca ou respawn foi alterada. A mudança é de desenho e de auxiliares visuais.
- Godot **4.7.2**, teste isolado `tests/combat_test.gd` executado no projeto com o novo visual: `COMBAT CHECKS: 26 passed=26 failures=[]`, saída 0, sem erros. A abertura e a navegação do mapa ampliado são verificadas separadamente.

## Reproduzir

Na pasta do projeto, no PowerShell:

```powershell
& 'D:\blender.exe' --background --factory-startup --python '.\tools\blender\senu_character_v2.py' -- --check-atlas
& 'D:\blender.exe' --background --factory-startup --python '.\tools\blender\senu_character_v2.py' -- --check-scene
```

Para reconstruir o modelo e renderizar os 64 quadros:

```powershell
& 'D:\blender.exe' --background --factory-startup --python '.\tools\blender\senu_character_v2.py'
```

O script escreve os arquivos v2 do próprio personagem e mantém a prova anterior `senu_blockout` separada. A renderização utiliza Cycles em CPU; não exige addons.

## Limites atuais

A caminhada e o ataque possuem poses próprias em oito direções. Parry e esquiva ainda reutilizam poses com efeitos específicos; impacto usa mudança de cor e morte usa uma representação achatada. Animações exclusivas de parry, esquiva, dano e morte continuam para uma próxima iteração. O atlas pré-renderizado é uma primeira implementação visual, ainda sem acabamento manual de pixel art quadro a quadro. A prancha contém mais detalhes do que o pequeno sprite consegue preservar.
