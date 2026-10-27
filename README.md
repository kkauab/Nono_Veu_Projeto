# O Nono Véu — Porto ampliado e Senu no Pixelorama

Protótipo jogável do **Porto dos Esquecidos**, em Godot 4.7.2 e GDScript. A versão de 27/10/2026 possui 27 setores, 4.350 pisos caminháveis, 38 inimigos e três puzzles de exploração que abrem o caminho até o chefe. A documentação original v1.1 permanece em [docs/O_NONO_VEU_GDD.md](docs/O_NONO_VEU_GDD.md).

## Jogar e editar

1. Abra **JOGAR.cmd** para jogar usando o Godot já baixado neste computador.
2. Abra **ABRIR_NO_GODOT.cmd** para editar. Outra opção é importar `project.godot` no Godot e pressionar **F5**.
3. No menu, escolha **Nova jornada** ou **Retomar jornada**. Toda nova jornada começa pela abertura encenada no cais: **Enter / E** revela e avança as falas; mantenha **Espaço por 3 segundos contínuos** para pular.

Se já testou a demo anterior, feche a janela antiga e abra novamente **JOGAR.cmd**. Para explorar a expansão desde o início, escolha **Nova jornada** no menu e confirme. O progresso anterior é arquivado antes do recomeço; **Retomar jornada** mantém suas coletas, armas, habilidades e chefe já derrotado.

Os atalhos procuram `Godot_v4.7.2-stable_win64.exe` em Downloads. Em outro computador, importe `project.godot` diretamente no Godot 4.7 ou ajuste o caminho dos atalhos. A primeira abertura importa as imagens automaticamente; a pasta do projeto precisa permitir gravação.

## O que já funciona

- Movimento em oito direções, câmera isométrica, colisões e ordenação por profundidade.
- Ataques leves e fortes, esquiva, parry e riposta; inimigos com ataques anunciados e chefe com dois padrões.
- Khopesh do Discípulo e Adagas do Reverso, com golpes e poderes diferentes. As adagas são encontradas no pátio.
- Vinte e sete setores conectados, incluindo arquivo, praça dos sinos, caravanas, farol, observatório, reservatório e cisterna. Três selos obrigatórios: sinos em ordem, distribuição da água e alinhamento das estrelas; pistas e estado parcial persistem.
- Dois atalhos físicos abertos pelo lado distante: retorno ao santuário e aqueduto entre jardim e mercado.
- Fragmentos de Nous, relicário opcional, registros e três melhorias. As Adagas ficam na alcova; cinco pontos de meditação permitem retomar a exploração.
- Mapa espacial que revela os setores visitados e acompanha a posição de Senu. Há pontos de meditação no hub, mercado e guarita.
- Senu usa o mesmo corpo nas duas armas, passos e corrida com poses distintas, rolagem e cortes reais da espada. Cenário, capa e retrato agora seguem uma direção em pixels: terreno 64×32, arquitetura em escala 1:1, água de oito quadros e sombras de contato. Objetos altos ficam transparentes quando encobrem o herói.
- Checkpoints, restauração de vida, morte/retorno e salvamento automático com backup.
- Derrotar o Porteiro Sem Nome abre a passagem para um pequeno limiar de teste das Catacumbas do Eco.

## Controles

| Ação | Controle |
|---|---|
| Mover | WASD ou setas |
| Ataque leve | J ou botão esquerdo do mouse |
| Ataque forte | F |
| Esquivar | Espaço |
| Parry | K ou botão direito do mouse |
| Poder da arma | Q |
| Interagir / recolher / meditar | E |
| Trocar arma encontrada | Tab |
| Árvore das Emanações | T |
| Mapa descoberto | M |
| Pausa e ajuda | Esc |

Pelo teclado, Senu ataca na última direção de movimento; ataques pelos botões do mouse miram o cursor. O poder do Khopesh é a Riposta Hermética, que ganha uma versão mais forte por um breve período após um parry bem-sucedido. O poder das Adagas é um avanço evasivo com impacto ao final. O jogo pausa ao abrir menus.

## Progresso salvo

O progresso é gravado na pasta de dados do usuário, em `%APPDATA%\nono_veu_demo\progress.json`, com backup `.bak`. Coletas, melhorias, armas, arma equipada, chefes derrotados, atalho e checkpoint persistem. Fragmentos não são perdidos ao morrer. Ao reabrir a demo, Senu retorna ao último santuário com vida restaurada; a posição exata de saída não é usada como ponto de respawn.

Os testes usam arquivos próprios em `user://qa/` e não alteram o progresso real.

Salvamentos da primeira demo continuam aceitos. As novas passagens e pistas começam sem desbloqueio. Ao selecionar **Nova jornada**, o estado anterior fica em `%APPDATA%\nono_veu_demo\archives\`.

## Editar Senu no Pixelorama

Abra **ABRIR_SENU_PIXELORAMA.cmd** para o corpo comum em `art/pixelorama/senu/senu_shared_v6.pxo` e use **EXPORTAR_SENU.cmd** após salvar. **ABRIR_COMBATE_PIXELORAMA.cmd** e **EXPORTAR_COMBATE.cmd** editam/exportam os cortes do Khopesh em `senu_sword_v8.pxo`. Ataques têm escala e apoio dos pés constantes; são seis fases em cinco vistas produzidas com guia anatômica e três vistas espelhadas, com contato leve em 0,12 s.

## Editar cenário, capa, retrato e abertura

- **ABRIR_MAPA_PIXELORAMA.cmd**: atlas `art/pixelorama/port_v7/port_pixel_v7.pxo`, 52 cels com 32 variantes de pisos, 12 objetos e oito cels da água.
- **ABRIR_CAPA_PIXELORAMA.cmd**: capa 640×360 em `port_title_v7.pxo`.
- **ABRIR_RETRATO_PIXELORAMA.cmd** / **EXPORTAR_RETRATO.cmd**: retrato animado em `art/pixelorama/menu_v8/senu_menu_idle_v8.pxo`, com 12 cels de olhos/faixa separados.
- **EXPORTAR_MAPA.cmd**: exporta os três projetos pelo Pixelorama instalado e importa no Godot. Feche a partida antiga e reabra **JOGAR.cmd** para recarregar.
- **ABRIR_ABERTURA_PIXELORAMA.cmd** / **EXPORTAR_ABERTURA.cmd**: atlas original do cais da abertura em `art/pixelorama/opening_rpg_v11/intro_atlas.pxo`.
- **ABRIR_PESCADOR_PIXELORAMA.cmd** e **ABRIR_BARCO_PIXELORAMA.cmd**: novos personagens e casco da chegada. **EXPORTAR_ABERTURA.cmd** exporta os três projetos da cena e importa no Godot.
- **ABRIR_INIMIGOS_PIXELORAMA.cmd** / **EXPORTAR_INIMIGOS.cmd**: sentinelas, com 64 poses em `art/pixelorama/enemies_v12/port_enemies_v12.pxo`; cada tipo tem oito passos e cinco fases de ataque.

As imagens de base foram criadas com a ferramenta integrada ImageGen; o terreno e a água foram preparados como cels em baixa resolução, e os PNGs finais foram exportados pelo Pixelorama 1.2.3. Os projetos nativos são editáveis. Não houve desenho manual pela interface do aplicativo. Fontes e prompts estão em `art/pixelorama/port_v7/`.

O mundo renderiza em 640×360 numa superfície independente; a interface usa 1280×720 e fontes rasterizadas no tamanho final da janela. O HUD é compacto, com textos nítidos, objetivos em até duas linhas e painéis de maior contraste. O mundo é dividido em blocos para que áreas distantes não sejam desenhadas a cada quadro. A correnteza e a espuma das margens animam sem reconstruir o cenário inteiro.

O design, os arquivos e as limitações estão em [docs/DESIGN_SENU.md](docs/DESIGN_SENU.md). A versão anterior permanece em `blender/personagens/senu_v2.blend`, com o script reproduzível `tools/blender/senu_character_v2.py`. A prova inicial de idle está documentada em [tools/blender/README.md](tools/blender/README.md).

Esta é uma demonstração inicial com arte provisória, incluindo os sprites fornecidos pelo usuário; não há trilha, controle por gamepad, arsenal completo, sistema de relíquias ou campanha inteira. A IA calcula caminhos pelo piso com AStar, evita buracos e respeita as fundações dos prédios; o desvio entre muitos atores ainda pode precisar de refinamento. Balanceamento, morte e regras dos checkpoints estão sujeitos a testes com jogadores. O executável independente depende dos modelos de exportação do Godot, que não foram instalados nesta etapa.

Consulte [docs/DECISOES.md](docs/DECISOES.md), [docs/PROGRESSO.md](docs/PROGRESSO.md) e [docs/TESTES.md](docs/TESTES.md). A origem dos documentos recuperados e as duas artes conceituais ainda ausentes estão registradas em [docs/IMPORTACAO.md](docs/IMPORTACAO.md).

Histórico de critérios e medições v7: [docs/VISUAL_E_DESEMPENHO_V7.md](docs/VISUAL_E_DESEMPENHO_V7.md). Prompts e fontes de arte: [art/pixelorama/port_v7/ART_PROMPTS.md](art/pixelorama/port_v7/ART_PROMPTS.md).

Revisão atual de legibilidade, menus animados, proporções, resistência, apoios e abertura de RPG: [docs/REFINAMENTO_V8.md](docs/REFINAMENTO_V8.md).
