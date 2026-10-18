class_name Wells
## Lines from H. G. Wells, "The War of the Worlds" (1898), which is in the public domain.

const Q := {
	"opening": "No one would have believed in the last years of the nineteenth century that this world was being watched keenly and closely by intelligences greater than man's and yet as mortal as his own.",
	"plans": "Intellects vast and cool and unsympathetic, regarded this earth with envious eyes, and slowly and surely drew their plans against us.",
	"odds": "The chances against anything manlike on Mars are a million to one.",
	"tripod": "A monstrous tripod, higher than many houses, striding over the young pine trees, and smashing them aside in its career; a walking engine of glittering metal.",
	"sword": "It was sweeping round swiftly and steadily, this flaming death, this invisible, inevitable sword of heat.",
	"fire": "It was as if each man were suddenly and momentarily turned to fire.",
	"flame": "Forthwith flashes of actual flame, a bright glare leaping from one to another, sprang from the scattered group of men.",
	"bows": "\"It's bows and arrows against the lightning, anyhow,\" said the artilleryman.",
	"ants": "\"This isn't a war,\" said the artilleryman. \"It never was a war, any more than there's war between man and ants.\"",
	"beat": "\"Cities, nations, civilisation, progress - it's all over. That game's up. We're beat.\"",
	"ulla": "\"Ulla, ulla, ulla, ulla,\" wailed that superhuman note - great waves of sound sweeping down the broad, sunlit roadway.",
	"rout": "It was the beginning of the rout of civilisation, of the massacre of mankind.",
	"indiscriminate": "Never before in the history of warfare had destruction been so indiscriminate and so universal.",
	"birthright": "By the toll of a billion deaths man has bought his birthright of the earth, and it is his against all comers.",
	"humblest": "Slain, after all man's devices had failed, by the humblest things that God, in his wisdom, has put upon this earth.",
	"dead": "The Martians - dead!",
	"judge": "Before we judge of them too harshly we must remember what ruthless and utter destruction our own species has wrought.",
	"panic": "The fear I felt was no rational fear, but a panic terror not only of the Martians, but of the dusk and stillness all about me.",
	"thunderchild": "It was the torpedo ram, Thunder Child, steaming headlong, coming to the rescue of the threatened shipping.",
	"droning": "Then slowly the hissing passed into a humming, into a long, loud, droning noise.",
	"came_fear": "Suddenly, like a thing falling upon me from without, came - fear.",
	"seed": "Dim and wonderful is the vision I have conjured up in my mind of life spreading slowly from this little seed bed of the solar system throughout the inanimate vastness of sidereal space.",
	"unearthly": "They were, I now saw, the most unearthly creatures it is possible to conceive.",
	"ropes": "Articulate ropes of steel dangling from it, and the clattering tumult of its passage mingling with the riot of the thunder."
}
const SECTOR_INTRO := ["opening", "plans", "tripod", "sword", "ants", "ropes", "indiscriminate", "panic", "bows", "birthright"]
const SECTOR_CLEARED := ["bows", "thunderchild", "birthright", "judge", "ants", "dead", "odds", "thunderchild", "birthright", "humblest"]
const BATTLE := ["tripod", "sword", "fire", "flame", "ulla", "droning", "ropes", "unearthly", "came_fear", "panic"]


static func opening() -> String:
	return Q["opening"]


static func sector_intro(i: int) -> String:
	return Q[SECTOR_INTRO[i % SECTOR_INTRO.size()]]


static func sector_cleared(i: int) -> String:
	return Q[SECTOR_CLEARED[i % SECTOR_CLEARED.size()]]


static func battle() -> String:
	return Q[BATTLE[randi() % BATTLE.size()]]


static func game_over() -> String:
	return Q["rout"]


static func victory() -> String:
	return Q["humblest"]


static func victory2() -> String:
	return Q["dead"]
