# Sentinelas — animações v12

Fonte editável: `port_enemies_v12.pxo`, com 64 quadros de 128×128, pivô dos pés (64,112) e grupos de animação por arquétipo. O PNG final é exportado pelo Pixelorama instalado e importado no Godot.

## Arte e referências

Foram criadas quatro folhas novas pela ferramenta integrada de geração de imagens. As referências em `sources/*_reference.png` isolam a identidade dos quatro inimigos da folha original v9. As folhas completas estão em `sources/*_generated.png`.

A revisão dos passos 5–8 foi feita pela ferramenta integrada de edição de imagens, com `sources/gait_guide.png` como guia dos quadris, joelhos e tornozelos. Somente esses quatro quadros são importados de `sources/*_opposite.png`; as demais poses usam a primeira folha. Os prompts completos de cada criação e correção estão em `sources/*_PROMPT.md` e `sources/*_OPPOSITE_PROMPT.md`.

O guia é um diagrama de anatomia, produzido por `tools/pixelorama/build_enemy_gait_guide_v12.py`; suas cores e rótulos não aparecem nos sprites finais.

## Contrato do atlas

PNG: `assets/sprites/port_enemies_v12.png`, 2048×512, 16 colunas e 4 linhas. Manifesto: `assets/sprites/port_enemies_v12_manifest.json`.

Linhas: guarda, corredor, lanceiro e guardião. Alturas de corpo de referência: 44, 40, 46 e 46 pixels. Senu continua com cerca de 38 pixels; o chefe mantém a escala anterior 1,35 do guardião.

| Cel | Movimento |
|---|---|
|0|Guarda parada|
|1–8|Contato, apoio, passagem e elevação de cada perna|
|9|Antecipação do ataque|
|10|Aceleração|
|11|Contato|
|12|Continuação do golpe|
|13|Recuperação|
|14|Reação ao dano|
|15|Guarda relaxada|

Há um único fator de amostragem por arquétipo, registrado no manifesto, aplicado igualmente a todos os seus quadros. O alinhamento dos pés traduz o desenho; não normaliza a altura de cada pose. As armas não definem o centro do corpo. Os joelhos realmente dobram, os calcanhares levantam e os mantos acompanham o passo.

Foi feito um retoque na resolução nativa dos passos 6 e 8 do guarda: o tronco foi registrado 1 pixel abaixo no 6 e 2 pixels acima no 8, com a pequena junção da coxa redesenhada. As botas e seus apoios foram preservados. Esse ajuste reduz a oscilação da cabeça de 5 para 2 pixels no ciclo, mantendo a flexão dos joelhos e o mesmo fator de escala. Os outros 62 quadros permanecem iguais ao primeiro export v12.

O jogo escolhe os oito quadros pela distância efetivamente percorrida. A animação para quando o inimigo é bloqueado. Antecipação, contato e recuperação seguem o tempo real do ataque. Não há escala pulsante nem rotação da figura inteira para simular caminhada.

## Preparação e exportação

`tools/pixelorama/build_enemy_pixel_v12.py` prepara os 64 quadros na resolução final, aplica a paleta comum sem difusão e grava o projeto editável. As imagens geradas são preservadas como fontes.

`ABRIR_INIMIGOS_PIXELORAMA.cmd` abre a fonte atual; `EXPORTAR_INIMIGOS.cmd` executa `tools/pixelorama/export_enemy_pixel_v12.ps1`. O exportador verifica saída 0 do Pixelorama, atualização do PNG e importação no Godot. Ele não altera vida, tamanho, navegação ou tempos de combate.

## Verificação

Os 64 quadros exportados foram comparados com o projeto: alpha e pixels visíveis coincidem exatamente. A transparência final é binária (0/255), e os oito desenhos de caminhada são distintos em cada arquétipo. Prévia na cadência do jogo: `qa/enemy_motion_v12_preview.gif`.
