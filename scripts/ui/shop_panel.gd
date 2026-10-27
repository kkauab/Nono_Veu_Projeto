extends RefCounted

## Painel de loja do HUD v6 (overlay "shop"). Monta e desenha com os ajudantes do
## próprio HUD (_label, _button, _frame, _text); as regras ficam em shop_catalog.gd.

const Shop = preload("res://scripts/economy/shop_catalog.gd")
const Economy = preload("res://scripts/economy/economy.gd")
const FIRST_ROW := 182.0
const ROW_STEP := 88.0
const ROW_HEIGHT := 80.0
const WARN := Color("d9ad8a")

static func build(hud: Control, game: Node) -> void:
	var data: Dictionary = game.store.data
	hud._label(hud.shop_greeting, Rect2(86, 130, 560, 48), 15, hud.MUTED)
	var items: Array = Shop.SHOPS.get(hud.shop_id, [])
	for index in range(items.size()):
		var id: String = items[index]
		var item: Dictionary = Shop.ITEMS[id]
		var top := FIRST_ROW + index * ROW_STEP
		hud._label(item["description"], Rect2(106, top + 32, 520, 44), 14, hud.MUTED)
		var blocker := Shop.blocker(data, id)
		var caption := "Esgotado" if blocker == "Esgotado" else "Comprar · %d" % int(item["price"])
		var button: Button = hud._button(caption, Rect2(650, top + 16, 204, 40), func():
			game.buy_item(id)
			hud._build_controls(), "diamond", "", true)
		button.disabled = blocker != ""
		if blocker != "" and blocker != "Esgotado":
			hud._label(blocker, Rect2(650, top + 58, 220, 20), 13, WARN)

static func draw(hud: Control, game: Node) -> void:
	var data: Dictionary = game.store.data
	hud.draw_circle(Vector2(714, 146), 6, hud.LOOT_COIN.darkened(.35))
	hud.draw_circle(Vector2(714, 146), 4, hud.LOOT_COIN)
	hud._text("%d %s" % [Economy.coins(data), Economy.CURRENCY], Vector2(728, 152), 17, hud.LOOT_COIN)
	var items: Array = Shop.SHOPS.get(hud.shop_id, [])
	for index in range(items.size()):
		var id: String = items[index]
		var item: Dictionary = Shop.ITEMS[id]
		var top := FIRST_ROW + index * ROW_STEP
		hud._frame(Rect2(86, top, 788, ROW_HEIGHT), true, .65)
		hud._fit_text(item["name"], Vector2(106, top + 26), 420, 20, hud.IVORY, true)
		hud._text("%d/%d" % [Shop.owned(data, id), int(item["limit"])], Vector2(580, top + 26), 14, hud.GOLD)
