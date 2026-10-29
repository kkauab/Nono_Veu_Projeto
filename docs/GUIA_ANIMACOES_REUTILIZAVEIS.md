# Referência de animações — morte e recompensas

Padrão aprovado pelo Kauã em 27/10/2026 para reutilizar em outras animações de O Nono Véu. Manter esta referência ao criar efeitos, coletas, NPCs e interações. A animação mistura poses pixeladas desenhadas com efeitos procedurais curtos; não é uma gravação de vídeo.

## Sequência de morte atual

1. `VeilEnemy.receive_hit()` reduz a vida, aplica recuo e impede processar outro golpe se `dead` já estiver ativo.
2. Na morte, muda para `DEAD`, zera as colisões e emite `defeated(enemy_id, is_boss)` uma única vez. O corpo usa a pose de recuo 14 do atlas; sua opacidade cai durante **0,45 s**, antes de `queue_free()`.
3. `SenuPlayer._damage_nearby()` ou o projétil identifica o golpe fatal e chama `CombatFx.enemy_hit(..., killed=true)`.
4. O impacto combina congelamento curto (**0,10 s**, ou **0,26 s** no chefe), clarão (**0,09 s**), tremor, som, 12 faíscas, 16 fragmentos do Véu (26 no chefe), poeira e um anel de **0,32 s**. Efeitos e desenho não concedem recompensas.

Arquivos: `scripts/actors/enemy.gd`, `enemy_pixel_view.gd`, `player.gd`, `combat_fx.gd` e `mercury_projectile.gd`. O atlas atual fica em `assets/sprites/port_enemies_v12.png`.

## Salto, giro e atração das moedas

`PortLoot` separa posição no chão de altura visual. A posição mantém a perspectiva e a ordenação por profundidade; o desenho sobe por `-roundf(_height)`, com a sombra permanecendo no chão.

| Parâmetro atual | Valor |
|---|---:|
| Gravidade visual | 340 px/s² |
| Impulso horizontal das moedas | 26–48 px/s; eixo Y achatado em 0,5 |
| Impulso vertical das moedas | 70–105 px/s |
| Altura inicial | 6 px |
| Amortecimento no chão | Rebote de 30%; pequenos rebotes param |
| Giro | 9 rad/s; largura `abs(cos(_spin))`, arredondada a pixels |
| Raio de atração das moedas | 56 px, depois que assentam |
| Raio de coleta | 8 px |
| Aceleração em direção ao jogador | 380 px/s² moedas; 520 XP |
| Velocidade máxima de atração | 300 px/s |
| XP começa a seguir | Depois de 0,45 s |
| Crédito garantido do XP não alcançado | Após 4 s; moedas não usam esse prazo |

A atração move o item em direção a Senu e eleva a altura visual até 14 px. O giro usa três faces de cor, e o som muda de tom segundo o valor da moeda. `_collected` evita crédito duplicado. O `collector` concede a recompensa e o nó é removido.

## Como reutilizar

- Para itens que saltam e são recolhidos: usar o mesmo modelo posição-no-chão + altura + velocidade vertical + atração. Trocar desenho e feedback, não a garantia de coleta única.
- Para abrir um baú, concluir uma missão ou restaurar um objeto: combinar clarão, anel e faíscas por um evento explícito. O efeito visual nunca deve repetir a recompensa nem alterar o estado da missão.
- Para NPCs: poses próprias com pés no mesmo pivô, escala fixa e sequência temporal de descanso, respiração, piscada e gesto. Não simular passos ou piscadas encolhendo o sprite ou apagando partes do rosto.
- Para fogo, água e oficinas: usar quadros ou efeitos de pequena amplitude, com desenho restrito à região animada. Móveis, bases sólidas e pés ficam estáveis.
- Usar `delta` para movimento e vida dos efeitos. O fim de hitstop e a restauração da câmera/material usam tempo real, inclusive durante pausa.
- Arredondar posições de desenho, manter filtro nearest e a mesma densidade de pixels do mundo. Guardar poses em `.pxo`, com tags e pivô documentados.
- Criar drops com `call_deferred()` durante os eventos de física. Manter a ordem de sinais `_drop_loot` antes de `_on_enemy_defeated`, pois o segundo registra a derrota.
- A guarda de `defeated` vale por ciclo de descanso: o mesmo inimigo pode pagar outra vez depois de renascer, mas itens únicos e recompensas de missão permanecem únicos.

## Verificação antes de reutilizar

Conferir contato visual, sombra no chão, duração, pausas, cancelamento, colisões e liberação dos nós. O valor total das moedas e orbes deve ser exatamente a recompensa prevista. Testes existentes: `tests/combat_fx_test.gd`, `tests/loot_economy_test.gd` e `tests/enemy_respawn_test.gd`.
