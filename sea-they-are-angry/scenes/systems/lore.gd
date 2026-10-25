class_name Lore
extends RefCounted
## The internees' notes: pages of diaries and letters left in the camp when it was
## closed, turning up a page at a time. Each is worth something at the research desk;
## together they tell what the camp saw. Written in the plain voice of people far from
## home, held behind wire on a rock in the North Sea, and of the guards beside them.

const PAGES := [
	"September 1940. They brought us over from the mainland at night, Germans and Italians and an Austrian who keeps saying he left Vienna to get away from all this. The guards say the lights on the towers are to watch us. The sea is so loud here.",
	"The fishermen on the boat said the North Sea keeps what it takes. Tonight something walked up out of it and stood at the wire. When the searchlight found it, it screamed, and the guard on the tower was as white as I was.",
	"Herr Brandt was an engineer in Hamburg. He has been looking at the lamps. He says the light burns them, really burns them, and a narrow beam is hotter than a wide one. The guards listen to him now.",
	"The cabbages do well behind the glass. Outside, last night's storm took half the beds. Giuseppe says at home they would have covered them with frames. We have no glass to spare, but we have old windows.",
	"Giuseppe strung a bell on the gate wire. It rang at three in the morning. The guard on the north tower swung his light round and there they were, coming up the shingle in a line. Everyone was awake after that.",
	"They come up the beaches when the tide is high. Wire slows them; it tears them, but they don't seem to feel it. Fire stops them. The sergeant has us filling sandbags now, guards and internees on the same spades.",
	"The diesel is nearly gone. The boat has not come for nine days. If the generator stops, the towers go dark. Brandt has been taking the governor apart to make it burn less. Nobody sleeps on the nights the lights flicker.",
	"May 1945. The war is over and they are letting us go home. The guards are leaving the lights and the stores. Whoever comes to this rock next: keep the lamp burning, and do not let the lights go out over the camp.",
]

## The page the next find turns up (later finds are loose scraps once the diary is read).
static func page(i: int) -> String:
	if i < PAGES.size():
		return PAGES[i]
	return "A loose page of sums: diesel by the gallon, cabbages by the row, nights since the boat last came."
