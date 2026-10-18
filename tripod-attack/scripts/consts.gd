class_name C
## Screen layout shared by every script. The game is designed on a 1024 x 576 vector display.

const W := 1024.0
const H := 576.0
const GROUND := 468.0
const PLAYER_X := 150.0
const PS := 1.5                      # the artilleryman's scale
const SANDBAG_L := 92.0
const SANDBAG_R := 268.0
const SANDBAG_TOP := GROUND - 45.0
const SHELTER_X := 44.0
const STOP_X := 350.0                # where a machine reaches the sandbags
const GRAV := 520.0                  # rocket gravity (the rigid bodies use the project gravity)
const WAVES_PER_SECTOR := 3
const LAYER_GROUND := 1
const LAYER_TRIPOD := 2
