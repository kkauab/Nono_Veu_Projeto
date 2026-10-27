# Khopesh — novas poses guiadas v8

## Correção frontal

Use case: precise-object-edit.
Edit target: the first input image, an existing 6-column by 5-row Senu attack sheet.
Supporting input2: the exact front-facing adult Senu appearance and the other directional model references.
Change ONLY the TOP ROW of six poses. The top row is the SOUTH attack TOWARDS THE VIEWER. Keep the other four rows completely unchanged.
Problem to fix: in the top row, the middle/impact poses turn sideways and aim the sword horizontally right. They must perform a downward cutting action toward the viewer while the torso and head keep facing the viewer.
In ALL SIX TOP-ROW cels, show BOTH EYES, the face front-on, the chest front-on, both shoulder edges, hips front-on. Keep the same adult head/body ratio, height, teal cape, ivory tunic, headband, bronze shoulder plate, brown skin, boots and palette. Do not move the planted feet, change the body height or shrink any cel.
Top row phases:
1 front guard, curved khopesh held low in his right hand (on viewer's LEFT).
2 right arm on viewer's LEFT lifts the sword overhead, front view.
3 sword arm starts chopping down in front of the face/chest, front view, blade foreshortened toward camera.
4 CONTACT: wrist and blade in front of the body, right arm drives down toward camera. The blade points downward/forward in the image, toward the knees; NO horizontal sword pointing right/left. Curved blade visible between waist and upper shin, with the tip just ABOVE the boot baseline.
5 FOLLOW-THROUGH: right arm crosses in front of abdomen to viewer's right, blade tip low, still BOTH EYES and chest front-facing.
6 settles into front-facing guard again.
The cut is a readable overhead cleave, not a punch or thrust. Sword, hand and arm remain connected. Single khopesh only, no second sword or effects.
Keep the exact 6-by-5 grid, full transparency, no text, no borders, no shadows. Preserve the original lower four rows pixel-for-pixel as far as possible. No realistic painting, no new costume, no chibi proportions.

Só os quadros 2/3/4 da vista frontal usam esta edição; as outras sete direções e a guarda/antecipação/retorno foram preservadas do primeiro resultado.

Modo: ImageGen integrado. Fontes preservadas em sword_v8_sources/. Guia anatômica e referência das cinco vistas reais do corpo comum. Preparação de cels e exportação final pelo Pixelorama instalado.

Use case: identity-preserve.
Asset type: production pixel-art character attack animation sheet for Godot / Pixelorama.
Input image1 is the EXACT Senu model in five directional views, a costume/anatomy reference. Input image2 is an anatomical pose-and-direction guide, NOT the final style. Replace all guide skeletons with the SAME Senu in image1. Never copy labels, cell outlines or colored bones.
Primary request: draw THIRTY distinct sequential sword-cut poses, arranged EXACTLY six columns by five rows. Same regular cells, character feet anchored at the same root within each cell. Same body height, head size, shoulder width and garment lengths across the sheet. Small adult head, agile adult anatomy, not chibi.
ROW DIRECTIONS top to bottom:
1 SOUTH/front: looks down toward viewer; face visible, chest visible.
2 SOUTHEAST: front-right three-quarter, gaze aims bottom-right.
3 EAST: true right profile, gaze aims right edge; nose points right, one eye.
4 NORTHEAST: back-right three-quarter, head aims top-right; cape/back dominant.
5 NORTH: straight back facing away; NO face, NO eyes; back of head, knot and cape visible.
All six poses within a row must preserve that SAME facing. Torso can twist during a strike but must never switch front to back within the sequence.
SIX PHASES left to right: 1 ready guard holding curved khopesh lowered beside right thigh; 2 torso coils and sword arm raises diagonally backward above shoulder; 3 elbow opens and sword begins descending forward; 4 clear impact pose, right arm drives blade toward that row's facing target; 5 follow-through across the body, sword tip low on opposite side, cape trails the motion; 6 return to guard, knees uncoil and sword lowers.
Weapon: ONE short slim bronze-edged curved khopesh, held in right hand. The wrist, arm and blade are anatomically connected in every cel. No disconnected or duplicate swords. No magic arcs or smear effects: the six clearly different poses themselves must carry the action.
Character: same brown-skinned young male Senu from reference; dark tousled hair, ivory tied headband, ONE bronze shoulder plate, ivory linen knee-length tunic, dark teal torn cape/scarf, leather belt and brown boots. Keep the same realistic sprite proportions and colors as reference, without adding armor or changing the costume.
Style: crisp hand-drawn low-resolution RPG pixel sprite, visible tiny pixel clusters, restrained dark-teal / ivory / bronze palette. Do not make a realistic painting, 3D render or smooth vector illustration.
Layout: ample transparent gutters, complete blade in every cell, no character touches a neighboring cell. Preserve head/feet size; a raised weapon must not make the body shrink.
Background: genuinely transparent. No ground, no shadow, no text or borders.
