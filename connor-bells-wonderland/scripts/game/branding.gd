class_name Branding
extends RefCounted
## Everything that names the game. Change these to re-theme the whole project.

const HERO_NAME := "Connor"
const GAME_TITLE := "Connor Bell's Wonderland"
const SUBTITLE := "Tower of Frustration at the Travelling Fair"
const BIG_TOP_SIGN := "CONNOR BELL'S WONDERLAND"
const CROWN_SIGN := "CONNOR'S CROWN"
const WELCOME_MESSAGE := "Welcome to Connor Bell's Wonderland!"
const RESULTS_TITLE := "WONDERLAND RESULTS"
const WIN_MESSAGE := "Champion of the Wonderland!"


static func title_upper() -> String:
	return GAME_TITLE.to_upper()
