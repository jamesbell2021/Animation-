extends Node

signal structure_damaged(s: Node)
signal structure_destroyed(s: Node)
signal enemy_killed(e: Node)
signal lamp_state_changed(state: int)
signal message(text: String)
## A page of the internees' notes picked up: its words, for the HUD to show.
signal lore(text: String)
signal run_ended(reason: String, night: int)
