# O Nono Véu — instruções essenciais

## Contexto mínimo
- Leia `docs/STATUS.md` ao iniciar; abra outros documentos somente conforme a tarefa.
- A versão usada pelo jogador é `D:\Nono_Veu`. Confira o checkout e suas alterações antes de editar; não confunda uma worktree com a entrega principal nem sobrescreva a pasta inteira.
- Preserve mudanças de Kauã/Gustavo. Para integração Git ou arquivos compartilhados, consulte `docs/COLABORACAO.md`; não faça commit, push ou merge sem pedido.

## Arquitetura
- Godot 4.7 + GDScript, 2D isométrico, GL Compatibility. Entrada: `scenes/boot/main.tscn` → `scripts/world/port_demo.gd`.
- `scripts/actors/`: atores/combate; `scripts/world/`: mapa, puzzles, missões, interiores e barco/ilha. Mantenha lógica específica nos módulos, com ganchos pequenos no coordenador.
- `scripts/ui/game_hud_v6.gd`: HUD ativo; `scripts/ui/pause_notebook.gd` e páginas: pausa. `scripts/progression/`, `scripts/economy/`, `scripts/save/`: habilidades, economia e persistência; `resources/`: definições.
- `art/pixelorama/`: fontes `.pxo`; `assets/`: exports; `tools/`: produção/importação; `tests/`: verificações. Não regenere fontes artísticas apagando edições manuais.

## Regras
- Use os sprites reais do jogo, pixels nítidos e identidade egípcia/hermética. Preserve pivôs nos pés, bases, colisões e profundidade; não substitua Senu por uma ilustração incompatível.
- Só torres gravam a jornada; sair/fechar não salva. Preserve IDs e compatibilidade dos saves.
- Testes que carregam o mundo usam `-- --qa` e arquivos próprios em `user://qa/`; nunca o progresso real. Rode verificações pertinentes à alteração e relate limites sem declarar testes não executados.
- Ao encerrar, atualize o estado em `docs/STATUS.md` (máximo 40 linhas); registre em `docs/DECISIONS.md` apenas decisões duradouras, sem diário de execução.

## Referências sob demanda
- Decisões vigentes: `docs/DECISIONS.md`. `docs/DECISOES.md`, `docs/PROGRESSO.md` e trechos antigos do README são históricos; confira divergências no código atual.
- Design/narrativa: `docs/O_NONO_VEU_GDD.md`, integral e preservado. Consulte só seções pertinentes; não leia nem injete o GDD inteiro automaticamente, apesar da orientação antiga no próprio documento.
- Pausa/HUD: `docs/CADERNO_PAUSA_V8.md`, `docs/HUD_MINIMAL_E_CADERNO.md`; persistência: `docs/SALVAR_NAS_TORRES.md`.
- NPCs/missões: `docs/NPCS_INTERIORES_MISSOES_V2.md`; apoio dos móveis: `art/pixelorama/interiors_v4/README.md`; barco/ilha: `docs/MUNDO_BARCO_ILHA.md`.
- Animações reutilizáveis: `docs/GUIA_ANIMACOES_REUTILIZAVEIS.md`; testes e comandos: `docs/TESTES.md` (resultados históricos não substituem nova execução).
