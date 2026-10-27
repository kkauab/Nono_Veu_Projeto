# Prova de Blender: Senu

`senu_blockout.py` é um script original para criar um modelo provisório de Senu e experimentar a exportação ortográfica em sprites. Não usa addons nem assets externos. O resultado é uma prova de escala e silhueta, sem rig, caminhada ou animações de combate; não representa arte final.

Blender encontrado em `D:\blender.exe`. A execução real de `--version` confirmou **Blender 5.2.3 LTS**, build `e13b728c6880`, de 22/10/2026.

Para verificar o acesso ao Blender sem criar assets, execute no PowerShell:

```powershell
& 'D:\blender.exe' --background --factory-startup --python 'D:\Nono_Veu\tools\blender\senu_blockout.py' -- --check
```

Para gerar a prova, depois de validar a mecânica da demo:

```powershell
& 'D:\blender.exe' --background --factory-startup --python 'D:\Nono_Veu\tools\blender\senu_blockout.py'
```

O script resolve a raiz pelo próprio caminho e escreve somente:

- `blender/personagens/senu_blockout.blend`
- `assets/sprites/senu_blockout.png`
- `assets/sprites/senu_blockout.json`

O atlas tem **512 × 80 pixels**, oito células de **64 × 80**, uma direção por célula. O pivô comum dos pés é **(32, 66)** em coordenadas de imagem a partir do canto superior esquerdo. Ordem: baixo, baixo-direita, direita, cima-direita, cima, cima-esquerda, esquerda e baixo-esquerda. Sugestão de escala no Godot: `0.5`, com filtragem `Nearest`.

O render usa câmera ortográfica, transparência, Cycles em CPU e cores próprias em verde petróleo, cobre e bronze. A borda alfa é recortada para a prova de leitura em pixels. O modelo e a lâmina são gerados pelo mesmo script e mantêm sua posição relativa.

## Verificações executadas

- `--check`: `SENU_BLENDER_CHECK_OK`.
- `--check-scene`: 30 objetos e pivô projetado `(32.00005, 65.999999)`, sem render/salvamento.
- Render completo: os oito quadros foram gerados pelo Blender; `.blend`, PNG e JSON foram salvos. O atlas de 512 × 80 foi inspecionado visualmente.
- `--check-atlas`: oito quadros não vazios e sem cortes nas bordas; menor margem superior de 3 pixels. `SENU_ATLAS_CHECK_OK`.

Os comandos foram executados usando a pasta de preparação antes da cópia para `D:\Nono_Veu`. O Blender emitiu apenas avisos de depreciação de `use_nodes` para uma versão futura.

## Cena de prova no Godot

`scenes/art/senu_preview.tscn` apresenta as oito direções em tamanho nativo e um personagem na escala sugerida de gameplay. Use as setas esquerda/direita para girar a amostra. Ela é uma cena separada: o personagem jogável permanece com o placeholder que cobre as ações de combate.

```powershell
& 'C:\Users\Kauã\Downloads\Godot_v4.7.2-stable_win64.exe' --path 'D:\Nono_Veu' 'res://scenes/art/senu_preview.tscn'
```

Estado de integração: atlas importado e cena de prova executada no Godot 4.7.2 sem erros. O atlas contém somente idle direcional e não substitui o personagem jogável. A animação de ataque e o alinhamento animado da arma continuam para uma próxima iteração.
