# Khopesh — seis poses e direções v8

O corte agora tem guarda, antecipação, aceleração, contato, continuação e retorno à guarda. Cinco vistas foram desenhadas com referência do corpo comum de Senu: sul, sudeste, leste, nordeste e norte. Oeste, noroeste e sudoeste usam os espelhos correspondentes. O perfil leste e as costas norte possuem seus próprios desenhos; não usam uma vista diagonal próxima como na versão anterior.

A primeira folha ainda fazia o impacto sul virar para sudeste. Uma edição específica corrigiu apenas a aceleração, o contato e a continuação da fileira sul: o tronco permanece frontal e a lâmina corta à frente, em direção ao observador. A guarda e a espada levantada originais foram mantidas. Os 42 cels das outras sete direções foram preservados byte por byte, verificados por hash na preparação.

O corpo é calibrado uma única vez por vista a partir de sua anatomia em repouso. Essa mesma escala é aplicada aos seis cels, preservando flexão de joelhos, rotação e extensão do braço. Nenhum quadro é aumentado/diminuído para parecer animado. O punho e a lâmina estão desenhados junto do braço; não há segunda lâmina modular durante o golpe.

O golpe leve da espada acerta em 0,12 s, permitindo ver a antecipação e a aceleração antes do contato. Mantém seu intervalo de 0,43 s e o dano original. O pesado acerta em 0,24 s, com antecipação maior. O poder continua acertando em 0,15 s. As adagas conservam os dois contatos em 0,075 e 0,17 s.

## Arquivos

- Projeto editável: `art/pixelorama/senu/senu_sword_v8.pxo`, 48 cels de 288×288, pivô dos pés (144,248).
- Atlas final: `assets/sprites/senu_sword_v8.png`, 2304×1728, exportado pelo Pixelorama 1.2.3 instalado. Cerca de 15 MiB descompactados; carregado uma vez ao primeiro golpe.
- Fonte e correção preservadas: `art/pixelorama/senu/sword_v8_sources/cuts_guided.png` e `cuts_front_corrected.png`.
- Guia de anatomia/direção: `sword_v8_sources/sword_pose_guide.png`; referência do modelo comum: `senu_five_views.png`.
- Prompts completos e modo de criação: `art/pixelorama/senu/SENU_SWORD_V8_PROMPT.md`. As imagens foram criadas com ImageGen integrado; a preparação montou os cels nativos e o Pixelorama executou a exportação final.
- Abrir e exportar: `ABRIR_COMBATE_PIXELORAMA.cmd` e `EXPORTAR_COMBATE.cmd`.
- Preparação reproduzível: `tools/pixelorama/build_sword_v8.py`.
- Prévia real: `qa/senu_sword_v8_all_directions.gif`.

O teste específico v8 verifica 118 condições, incluindo dano somente no contato real e seis poses distintas por direção. As 97 verificações da apresentação anterior foram adaptadas à duração e margem do quadro atuais. Combate e a cadência separada das adagas continuam validados.
