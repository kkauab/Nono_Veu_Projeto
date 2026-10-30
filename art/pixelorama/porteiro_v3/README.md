# Porteiro — estudo de atuação v3

Primeiro ciclo revisto após a rejeição do perfil e dos movimentos v1/v2. **Arte em avaliação, sem integração ao chefe jogável.** Uma vista-piloto de três quartos (`down_right`), corpo de referência 57 px, canvas 160×160 e pivô físico (80,140). Senu e os inimigos existentes não foram redesenhados.

Revisão posterior de presença em `../porteiro_v4/`, mantendo o rosto da v3 por preferência do jogador. Os arquivos desta pasta ficam preservados; a entrada de prévia atual acompanha a revisão v4.

## Conteúdo

- `porteiro_v3.pxo`: 18 cels em quatro camadas editáveis: manto, corpo articulado, rosto humano e chave-lança/mãos.
- Guarda: 1 cel. Caminhada: 8 fases com apoio alternado, joelho e tornozelo articulados, deslocamento de peso e tecido acompanhando o movimento.
- Estocada: 9 fases — guarda, empunhar, carregar o corpo, manter antecipação, acelerar, contato, continuação, recuperação e retorno à guarda.
- `export_plan.json`: sequências, durações, pivô, posições anatômicas e contato em 1,00 s. A distância de caminhada mantém o ciclo de 24 px; parado não seleciona quadros de caminhada.
- `texture_base.png` e `cels/`: materiais derivados do concept fornecido pelo jogador e os cels de trabalho. Não foram gerados por API nem desenhados manualmente na interface do Pixelorama.

## Método e limites

Atuação estudada nos quadros reais do lanceiro (`port_enemies_v12.png`), sem recolorir ou substituir esse inimigo. O Porteiro usa os tecidos/rosto dos concepts: texturas mapeadas em poses anatômicas por triangulação local, articulação de membros e peças rígidas para rosto/pés. As duas mãos acompanham a mesma haste. Nenhum rosto simplificado foi pintado por cima.

O estudo ainda requer avaliação do jogador quanto à naturalidade, rosto, peso e silhueta. Os testes de pixels não aprovam qualidade artística. As outras direções, os demais ataques, fases, cutscenes, hitboxes e integração do chefe permanecem pendentes.

## Produção local

Usar Python com Pillow (o runtime incluído no Codex desta máquina contém a biblioteca), Pixelorama 1.2.3 e Godot 4.7.2:

```powershell
python -B tools/pixelorama/build_gatekeeper_art_v3.py
& tools/pixelorama/export_gatekeeper_art_v1.ps1 -ArtVersion 3
python -B tools/pixelorama/validate_gatekeeper_art_v3.py
```

O construtor v3 reutiliza utilidades dos construtores v1/v2, que devem ser preservados. `generated_hashes.json` impede regeneração sobre alterações manuais. Depois de editar o `.pxo`, exportar essa fonte; para reconstruir a partir do gerador, criar outra versão em vez de apagar a edição. O exportador também protege alterações manuais nos PNG/JSON de destino e usa uma pasta nova de QA para evitar confirmação de sobrescrita no aplicativo.

Prévia atual:

```powershell
godot --path . --script res://tests/gatekeeper_art_v3_preview.gd -- --qa
godot --path . --script res://tests/gatekeeper_art_v3_preview.gd -- --qa --world
```

`qa/porteiro_art_v3/`: GIFs `caminhada.gif` e `estocada.gif`, pranchas, 13 capturas do estúdio com os renderizadores reais de Senu/lanceiro, duas da arena e logs. O estúdio renderiza 120 quadros animados; o mundo abre somente em slot de QA.

QA executado: pixels/fonte/anatomia 181/181; seleção de poses no Godot 16/16; lanceiro/inimigos existentes 28/28; Senu v6 58/58. Exportação Pixelorama, importação Godot, estúdio e arena com saída 0 nas execuções finais. Contato visual, mão/haste, margens, paleta, alfa binário, apoio e invariância do rosto conferidos; nenhuma alteração no combate ou no progresso real. A primeira captura de estúdio encontrou uma declaração de tipo faltante, corrigida antes da execução final; uma tentativa de exportar sobre destino existente foi substituída por exportação em caminho novo.
