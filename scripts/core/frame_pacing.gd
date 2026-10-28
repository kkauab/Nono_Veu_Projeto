extends RefCounted

## Ritmo dos quadros (docs/MUNDO_BARCO_ILHA.md, "Fluidez"). Com o limite de 60
## quadros num monitor de 120, 144 ou 165 Hz, cada quadro do jogo fica 2 ou 3
## atualizações na tela, alternando, e tudo que anda dá trancos. Sem o limite, o
## jogo segue o monitor (vsync) e a física roda na mesma taxa: Senu, o barco e
## os inimigos mudam de lugar a cada quadro desenhado, sem degraus.

const BASE_TICKS := 60
const MAX_TICKS := 240

## Passos de física por segundo para um monitor de `refresh` Hz.
static func ticks_for(refresh: float, limit_60: bool) -> int:
	if limit_60 or refresh < BASE_TICKS - 1:
		return BASE_TICKS
	return clampi(roundi(refresh), BASE_TICKS, MAX_TICKS)

static func apply(limit_60: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Engine.max_fps = BASE_TICKS if limit_60 else 0
	Engine.physics_ticks_per_second = ticks_for(DisplayServer.screen_get_refresh_rate(), limit_60)
