# guard — animação v12

Modo: ferramenta integrada de geração de imagens. Referência: guard_reference.png, extraída da fonte original dos inimigos v9.

Use case: identity-preserve
Asset type: animation sprite sheet for a low-resolution Egyptian fantasy RPG.
Input image1 is exact character identity and existing pixel-art material reference. Preserve this specific enemy's costume, silhouette, equipment, palette and human proportions.
Subject: Masked Egyptian sentinel with bronze shoulder armor, ivory headband, rust-red neck scarf, ragged dark linen coat and one curved SHORT SWORD. One sword only. The reference is exact character identity.
Create ONE production sprite sheet of this character with exactly16 separate full-body poses in a strict4-column by4-row grid, square1024x1024 canvas, each cell256x256. TRUE TRANSPARENT BACKGROUND. No shadow, no ground, no scenery, no labels, no text, no gridlines. Every pose faces the same three-quarter DOWN-RIGHT direction, slight top-down game camera. Complete head, weapons and feet in every cell. Large empty gutters prevent overlap; each character body approximately165px high, consistent size in all16 cells. Fixed ground baseline within cells, torso width and head size absolutely fixed. Weapons can extend but must stay inside their cell.
Style: crisp low-resolution hand-placed pixel clusters and selective dark outline, limited flat warm bronze/ivory/charcoal/teal ramps. No realistic painted surface, no blur, no smooth gradients, no chibi. Match reference's design but simplify noisy texture so it reads when reduced to44pixels body height.
Pose order LEFT TO RIGHT, TOP TO BOTTOM:
0 combat idle.
1 WALK cycle left heel forward contacting ground, right toe far behind.
2 WALK left foot accepts weight, right heel lifts.
3 WALK passing: right knee bent as it passes left planted leg, legs clearly overlap.
4 WALK right knee forward and raised, left toe pushes off.
5 WALK opposite contact: right heel forward, left toe behind.
6 WALK right accepts weight, left heel lifts.
7 WALK opposite passing: left knee bent as it passes planted right leg.
8 WALK left knee forward and raised, right toe pushes off.
9 ATTACK anticipation.
10 ATTACK acceleration.
11 ATTACK contact.
12 ATTACK follow-through.
13 ATTACK recovery.
14 HIT REACTION one small backward shoulder recoil, same scale, feet planted.
15 alternative IDLE with weapon relaxed.
Attack poses9–13 specifically a single diagonal sword slash: windup blade back, accelerate, extended cut down-right, follow-through, return to guard.
Critical animation rules: walking requires EIGHT anatomically different poses with alternating leg support and counter-swinging arms, raised heels, bent knees, planted feet. Same head and torso proportions across frames. Do not duplicate idle and translate, scale, squash or rotate it to fake animation. Cloth trails subtly with gait. Exactly two arms and legs; no duplicated weapons or limbs. Keep same viewing direction all16 poses. Bodies never flip to other direction. Maintain readable separation between feet. Fully transparent alpha outside characters, no colored backdrop or baked shadows.
