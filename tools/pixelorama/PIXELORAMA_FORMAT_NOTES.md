# Pixelorama 1.2.3 — contrato de projeto e exportação

Pesquisa de integração de 25/10/2026. Foram consultados somente o manual e o repositório oficiais. Os arquivos de referência estão em `qa/pixelorama_reference/` e não são dependências do jogo.

O responsável pelo ambiente confirmou o aplicativo instalado como **v1.2.3-stable**, ProductVersion1.2.3.0, executando Godot4.7.2. O código da tag oficial **v1.2.3** usa **Pxo_Version7**. A branch `master` já usa formato8 e não deve orientar a criação deste projeto. A interface gráfica não foi controlada nesta pesquisa.

## Arquivo nativo PXO7

O `.pxo` é um ZIP. A leitura oficial começa em `data.json`; os pixels de cada cel são bytes RGBA8 brutos do canvas completo, sem cabeçalho de PNG. A numeração dos caminhos de frames e camadas começa em1. Para larguraW e alturaH, cada cel de corRGBA8 precisa de **W×H×4 bytes**.

```text
senu.pxo
  mimetype                          application/x-pixelorama
  data.json                         UTF-8
  preview.png                       miniatura opcional para abertura
  image_data/frames/1/layer_1        RGBA8 do primeiro quadro/camada
  image_data/frames/2/layer_1        RGBA8 do segundo quadro/camada
  ...
```

No formato7, todos os cels usam o tamanho global do projeto. Não usar o `image_size`/`offset` por cel introduzido no formato8. Para RGBA8, `color_mode` vale5. Os arquivos `indices_layer_*` só são necessários no modo indexado e podem ser omitidos aqui.

Referências: [configuração da versão1.2.3](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/project.godot), [OpenSave](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/src/Autoload/OpenSave.gd), [Project](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/src/Classes/Project.gd).

## Dados mínimos

Exemplo de estrutura para um quadro128×192, uma camada e uma tag. Replicar os elementos de `frames` e os respectivos arquivos binários para a animação completa. O exemplo é documentação; não foi criado um projeto a partir dele nesta pesquisa.

```json
{
  "pixelorama_version": "v1.2.3-stable",
  "pxo_version": 7,
  "size_x": 128,
  "size_y": 192,
  "color_mode": 5,
  "layers": [{
    "name": "Senu",
    "type": 0,
    "new_cels_linked": false,
    "visible": true,
    "locked": false,
    "blend_mode": 0,
    "opacity": 1.0,
    "parent": -1,
    "effects": []
  }],
  "frames": [{"cels": [{"opacity": 1.0, "z_index": 0}], "duration": 1.0}],
  "tags": [{"name": "idle_s", "color": "6db0a4ff", "from": 1, "to": 1}],
  "current_frame": 0,
  "current_layer": 0,
  "fps": 12.0,
  "export_profile": {
    "orientation": "1",
    "lines_count": "8",
    "current_tab": "1",
    "crop_mode": "0",
    "resize": "100",
    "interpolation": "0"
  }
}
```

`new_cels_linked` e a opacidade de cada cel são lidos diretamente, portanto devem ser incluídos. `duration` é um multiplicador de1/fps; em12fps, duration1 significa1/12segundo. Tags usam `from`/`to` inclusivos e iniciados em1; `current_frame` e `current_layer` usam índices iniciados em0.

Os valores de **export_profile são strings de expressão Godot**, convertidas por `str_to_var`, diferentemente dos demais números/booleanosJSON. `orientation="1"` é ROWS; `lines_count="8"` fornece oito colunas, com frames consecutivos da esquerda para a direita. Não confundir o nome `lines_count` com o número final de linhas nesse modo.

Referências: [Frame](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/src/Classes/Frame.gd), [BaseCel](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/src/Classes/Cels/BaseCel.gd), [PixelLayer](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/src/Classes/Layers/PixelLayer.gd), [AnimationTag](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/src/Classes/AnimationTag.gd), [ExportProfile em Export.gd](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/src/Autoload/Export.gd).

## Edição não destrutiva por efeito nativo

`LayerEffect` aceita um `shader_path` do próprio aplicativo. Existe o recurso nativo `res://src/Shaders/ColorReplace.gdshader`. O shader substitui cores próximas de `old_color` por `new_color`, comparando cada componenteRGBA dentro de `tolerance`. Usa `ShaderImageEffect`/`DrawableTexture2D`, portanto precisa de renderizaçãoGPU; o rendererDummy não comprova esse caminho.

Exemplo de um elemento do array `layers[0].effects`, visando somente o vermelho praticamente puro e opaco:

```json
{
  "name": "Limpeza de halo vermelho",
  "shader_path": "res://src/Shaders/ColorReplace.gdshader",
  "enabled": true,
  "params": {
    "old_color": "Color(1, 0, 0, 1)",
    "new_color": "Color(0, 0, 0, 0)",
    "tolerance": "0.02",
    "has_pattern": "false",
    "size": "Vector2(128, 192)"
  },
  "animated_params": "{}"
}
```

`params` pode ser um dicionárioJSON com valores em strings de expressão, conforme `AnimatableObject.deserialize`. Ajustar `size` ao canvas. Efeitos separados podem selecionar verde ou amarelo puros, mantendo tolerância pequena para não apagar linho/bronze. Os pixels originais do cel permanecem no PXO e os efeitos podem ser desativados no editor.

**Exige prova de um quadro antes da exportação completa.** O ColorReplace também consulta um sampler `selection`; a configuração acima deixa o recurso no valor padrão do motor. Confirmar no aplicativo que os pixels-alvo mudaram e os demais foram preservados. Não declarar sucesso somente pelo código de saída. HSV preserva a opacidade original, portanto não serve para apagar o halo.

**Não incluir `image_data/final_images/*` no PXO usado para essa prova.** A exportação pode ler esses quadros pré-mesclados diretamente e pular os efeitos, pois o projeto recém-aberto não está marcado como alterado.

Referências: [LayerEffect](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/src/Classes/LayerEffect.gd), [AnimatableObject](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/src/Classes/AnimatableObject.gd), [ColorReplace](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/src/Shaders/ColorReplace.gdshader), [BaseLayer.display_effects](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/src/Classes/Layers/BaseLayer.gd), [ShaderImageEffect](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/src/Classes/ShaderImageEffect.gd).

## Exportação real pelo aplicativo

O manual oficial documenta `--export`, `--spritesheet`, `--output`, `--json`, intervalos de frames e escala. Usar caminhos absolutos evita a resolução relativa à pasta do executável. Exemplo de parâmetros para o processo Pixelorama:

```text
--rendering-method gl_compatibility --log-file D:/Nono_Veu/qa/pixelorama_senu_export.log --quit-after 1800 --max-fps 60 -- --export --spritesheet --json --output D:/Nono_Veu/assets/sprites/senu_v3.png D:/Nono_Veu/art/pixelorama/senu/senu_v3.pxo
```

Para efeitosGPU, retirar `--headless` e executar o aplicativo com rendererCompatibility e janela oculta, sem automação de sua interface. O responsável pela execução deve validar esse modo na instalação real. `--quit` pode encerrar antes da inicialização assíncrona; por isso o exemplo usa um limite de quadros. O prazo deve permitir terminar a exportação.

A confirmação mínima é: log identifica a versão, PXO abre com tamanho e framecount esperados, PNG/JSON realmente aparecem e os pixels exportados mantêm transparência, alinhamento e efeitos desejados. Na produção de 25/10/2026, esse fluxo foi executado com Pixelorama 1.2.3 e OpenGL na GTX 1060. A prova de cor passou: vermelho/verde/amarelo de diagnóstico ficaram transparentes; verde-petróleo e bronze permaneceram inalterados. O atlas final contém 124 quadros, em 3072 × 6144 pixels, e foi importado no Godot. Não houve edição manual pela interface.

Fontes: [manual oficialCLI](https://pixelorama.org/user_manual/cli/), [salvar/exportar](https://pixelorama.org/user_manual/save_and_export/), [parserCLI1.2.3](https://github.com/Orama-Interactive/Pixelorama/blob/v1.2.3/src/Main.gd).

## Por que evitar um builder com `--main-pack --script`

O construtor de `Project` adiciona abas e guias por `Global.tabs`/`Global.canvas`. Um script externo que substitua a cena principal não dispõe desses nós. Executar classes internas sem inicializar a cena do editor não é o fluxoCLI documentado e não foi validado nesta pesquisa. Gerar o ZIP conforme o contrato, depois abri-lo e exportá-lo pelo CLI nativo mantém o fluxo verificável sem instalar extensões ou modificar o aplicativo.
