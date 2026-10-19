class_name Branding
extends RefCounted
## Everything that names the game. Change these to re-theme the whole project.

const HERO_NAME := "Connor"
const GAME_TITLE := "Connor's Carnival Chaos"
const SUBTITLE := "Tower of Frustration at the Travelling Fair"
const BIG_TOP_SIGN := "CONNOR'S CARNIVAL CHAOS"
const CROWN_SIGN := "CONNOR'S CROWN"
const WELCOME_MESSAGE := "Welcome to Connor's Carnival Chaos!"
const RESULTS_TITLE := "CARNIVAL CHAOS RESULTS"
const WIN_MESSAGE := "Champion of the Carnival!"


static func title_upper() -> String:
	return GAME_TITLE.to_upper()
