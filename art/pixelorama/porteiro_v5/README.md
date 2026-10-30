# Porteiro v5 — nove golpes e caminhada no mapa

Estudo de arte para avaliação. A partida normal ainda usa o chefe anterior. Abra `VER_GOLPES_PORTEIRO.cmd` na raiz para testar a caminhada no mapa real e os nove clipes; 1–9 selecionam um golpe e Tab alterna a sequência automática. O Porteiro acompanha Senu com a navegação/colisões existentes. Essa prévia usa somente `user://qa/`, não causa dano e não concede vitória ou recompensas.

## Arte e arquivos

99 cels, quatro camadas editáveis, canvas 160×160, pivô (80,140), corpo de referência 57 px. São 18 cels anteriores preservados e nove sequências de nove poses. A vista produzida é apenas `down_right`; outras direções ainda exigem arte própria. Não espelhar o personagem para trocar a mão da chave-lança. A camada de rosto/cabelo é a v3 preferida pelo jogador, conferida nos 99 cels; o manto e o bronze mantêm a revisão v4.

- `porteiro_v5.pxo`: fonte Pixelorama com tags para cada ataque.
- `cels/`: quadros compostos para inspeção.
- `export_plan.json`: regiões, pivô, sequências, durações, contatos e metadados de corpo/mãos/pés.
- `resources/bosses/gatekeeper_attacks.json`: nomes, poses, antecipações, contato, recuperação, formas de aviso e eventos atrasados. Os valores de dano/parry/cooldown são preparação de combate, ainda não aplicados ao chefe da partida.
- `assets/sprites/porteiro_v5.png`, `.json` e `_manifest.json`: exportação real pelo Pixelorama, lida pelo renderizador Godot.

| Golpe | Atuação e contato |
|---|---|
| Investida da Guarita | Recolher a haste com duas mãos, carregar o tronco e avançar a perna na estocada. |
| Varredura Cerimonial | Abrir a arma lateralmente, transferir o peso e acompanhar o arco com braços e tecido; três contatos de arrasto. |
| Golpe do Registro | Elevar a chave-lança, sustentar a preparação e baixar o corpo no impacto vertical. |
| Sino do Esquecimento | Erguer e sustentar a haste/sinos; a onda percorre o chão após o toque. |
| Última Advertência | Guarda recolhida e sustentada, abertura rápida, corte pesado e recuperação longa. |
| Ecos da Investida | Carregamento nervoso, estocada e repetição residual discreta com atraso. |
| Nomes Esquecidos | Posição mais fechada, contato no chão e três inscrições com aviso e pulso atrasado. |
| Correntes do Limiar | Recolher de lado, projetar a haste e conduzir a corrente à frente. |
| Golpe do Último Nome | Preparação mais longa, passada ampla, queda do peso do corpo e maior recuperação. |

## Efeitos e produção

`gatekeeper_attack_player.gd` sincroniza o quadro de contato com os eventos do JSON. É apresentação reutilizável, sem IA, vida, saves ou recompensas. O ator de ensaio em `tests/` reaproveita `VeilEnemy` para navegar e avança a caminhada pela distância realmente percorrida. O golpe interrompe a caminhada e termina na guarda, sem deslizar durante a recuperação.

Impactos usam **CombatFx existente**: lascas de pedra com altura/gravidade/rebote e sombra no chão, poeira, anel curto, tremor e congelamento. Ressonância, riscos e marcas são temporários; não destroem o mapa. Sinos e correntes são placeholders originais sintetizados localmente e usam o mesmo pool de áudio do jogo. Não houve API paga, alterações em Senu ou redesenho dos inimigos comuns.

A fonte foi construída localmente com texturas do concept e poses articuladas; não foi desenhada manualmente na interface do Pixelorama. Os construtores v1–v4 são dependências e não devem ser apagados. `generated_hashes.json` e `exported_hashes.json` recusam sobrescrever edições manuais. Editar/exportar a fonte ou criar nova versão ao revisar a arte.

```powershell
python -B tools/pixelorama/build_gatekeeper_attacks_v5.py
& tools/pixelorama/export_gatekeeper_art_v1.ps1 -ArtVersion 5
python -B tools/pixelorama/validate_gatekeeper_attacks_v5.py
godot --path . --script tests/gatekeeper_rehearsal.gd -- --qa
godot --path . --script tests/gatekeeper_attacks_preview.gd -- --qa
python -B tools/pixelorama/package_gatekeeper_attack_review.py
```

`qa/porteiro_attacks_v5/` contém GIFs capturados no Godot (`*_arena.gif`), sequência dos nove, caminhada no mapa, imagens e logs. `*_sprites.gif` mostra apenas cels, sem efeitos. A captura determinística desliga o hitstop; a prévia interativa mantém o feedback em tempo real. Qualidade e naturalidade ainda dependem da avaliação do jogador. O encontro completo com oito direções, dano/parry, fases narrativas, HUD, derrota e persistência específica continua pendente.
