# Interiores e moradores v2

Abra `interiors_v2.pxo` no Pixelorama por **ABRIR_INTERIORES_PIXELORAMA.cmd**. Após editar e salvar, execute **EXPORTAR_INTERIORES.cmd** para exportar o PNG e reimportar no Godot.

45 quadros, células 128×144, oito colunas, paleta de 33 cores, alpha binário. Pivô dos pés: (64,112). Seis moradores, quatro poses completas cada. A reprodução usa uma sequência de 48 passos a 8 fps, com repouso predominante. Não altere a escala entre poses.

`sources/npcs_key.png` e `sources/furniture.png` são as bases ImageGen. `tools/pixelorama/build_interiors_v2.gd` monta o arquivo nativo, remove a chave magenta e normaliza a paleta. Reconstruir substitui o projeto; preserve edições manuais antes de executar esse construtor. A exportação comum não reconstrói o projeto.

O teste `tests/interiors_art_test.gd` compara os pixels exportados com o projeto nativo e verifica poses distintas, paleta, transparência e apoio dos pés.
