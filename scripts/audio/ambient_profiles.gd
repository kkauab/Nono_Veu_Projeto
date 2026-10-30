extends RefCounted

## A ambientação de cada lugar (docs/MUNDO_PROPOSTA_2026-10-30.md), lida pelo
## VeilAmbient (ambient_audio.gd): o leito sonoro do lugar, o volume do vento, se o
## zumbido dos santuários pode soar ali e a luz que tinge o mundo.
## Os leitos são gerados por tools/audio/build_ambient_places.py.

const BEDS := {
	"surf": "res://assets/audio/ambient/place_surf_loop.wav",
	"crowd": "res://assets/audio/ambient/place_crowd_loop.wav",
	"forge": "res://assets/audio/ambient/place_forge_loop.wav",
	"crypt": "res://assets/audio/ambient/place_crypt_loop.wav",
	"water": "res://assets/audio/ambient/place_water_loop.wav",
	"night": "res://assets/audio/ambient/place_night_loop.wav",
	"chimes": "res://assets/audio/ambient/place_chimes_loop.wav",
}

## bed: leito ("" = só o vento); bed_db e wind_db: volumes; sacred: o zumbido dos
## santuários pode soar; light: multiplica as cores do mundo (CanvasModulate).
const PROFILES := {
	"sanctuary": {"bed": "night", "bed_db": -30.0, "wind_db": -21.0, "sacred": true, "light": Color(1.0, .97, .9)},
	"cloister": {"bed": "night", "bed_db": -22.0, "wind_db": -23.0, "sacred": true, "light": Color(.97, 1.0, .92)},
	"harbor": {"bed": "surf", "bed_db": -19.0, "wind_db": -18.0, "sacred": false, "light": Color(1.0, 1.0, 1.0)},
	"market": {"bed": "crowd", "bed_db": -20.0, "wind_db": -21.0, "sacred": false, "light": Color(1.0, .95, .88)},
	"warehouse": {"bed": "crowd", "bed_db": -27.0, "wind_db": -20.0, "sacred": false, "light": Color(.97, .95, .92)},
	"plaza": {"bed": "", "bed_db": -60.0, "wind_db": -17.0, "sacred": false, "light": Color(1.0, 1.0, .98)},
	"garden": {"bed": "night", "bed_db": -20.0, "wind_db": -22.0, "sacred": false, "light": Color(.95, 1.0, .93)},
	"water": {"bed": "water", "bed_db": -21.0, "wind_db": -21.0, "sacred": false, "light": Color(.91, .98, 1.0)},
	"crypt": {"bed": "crypt", "bed_db": -18.0, "wind_db": -30.0, "sacred": true, "light": Color(.8, .84, .95)},
	"forge": {"bed": "forge", "bed_db": -19.0, "wind_db": -23.0, "sacred": false, "light": Color(1.0, .89, .78)},
	"bells": {"bed": "chimes", "bed_db": -21.0, "wind_db": -19.0, "sacred": true, "light": Color(1.0, .98, .92)},
	"observatory": {"bed": "chimes", "bed_db": -30.0, "wind_db": -17.0, "sacred": true, "light": Color(.86, .88, 1.0)},
	"beacon": {"bed": "surf", "bed_db": -23.0, "wind_db": -15.0, "sacred": false, "light": Color(1.0, .98, .93)},
	"arena": {"bed": "crypt", "bed_db": -27.0, "wind_db": -21.0, "sacred": false, "light": Color(.95, .85, .83)},
	"isle": {"bed": "night", "bed_db": -21.0, "wind_db": -19.0, "sacred": true, "light": Color(.98, 1.0, .91)},
	"ibis": {"bed": "surf", "bed_db": -22.0, "wind_db": -18.0, "sacred": true, "light": Color(.87, .9, 1.0)},
	"wreck": {"bed": "surf", "bed_db": -17.0, "wind_db": -16.0, "sacred": false, "light": Color(.93, .95, .98)},
	"sea": {"bed": "surf", "bed_db": -25.0, "wind_db": -16.0, "sacred": false, "light": Color(.94, .97, 1.0)},
	"open_sea": {"bed": "surf", "bed_db": -22.0, "wind_db": -13.0, "sacred": false, "light": Color(.9, .94, 1.0)},
	"house": {"bed": "", "bed_db": -60.0, "wind_db": -32.0, "sacred": false, "light": Color(1.0, .95, .88)},
}

## O perfil de cada sala de port_layout.gd. Sala sem entrada usa "plaza".
const ROOM_PROFILE := {
	"hub": "sanctuary", "cloister": "cloister", "p1": "harbor", "market": "market", "p2": "warehouse",
	"bridge": "harbor", "p3": "plaza", "secret": "crypt", "lower_dock": "harbor", "garden": "garden",
	"p4": "plaza", "b1": "arena", "a02": "crypt", "aqueduct": "water", "pilgrim": "plaza",
	"bellcourt": "bells", "archive": "crypt", "scriptorium": "plaza", "caravan": "market", "kilns": "forge",
	"salt_road": "plaza", "beacon": "beacon", "oracle": "observatory", "reservoir": "water", "copper_dock": "harbor",
	"cistern": "water", "sluice": "water", "buried": "crypt", "echo_descent": "crypt", "echo_gallery": "crypt",
	"isle": "isle", "ibis": "ibis", "wreck": "wreck",
}


static func for_room(room_id: String) -> String:
	return str(ROOM_PROFILE.get(room_id, "plaza"))


static func profile(name: String) -> Dictionary:
	return PROFILES.get(name, PROFILES["plaza"])
