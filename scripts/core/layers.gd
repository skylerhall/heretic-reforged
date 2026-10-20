class_name Layers
## Physics layer bits shared by every script.

const WORLD := 1
const PLAYER := 2
const MONSTER := 4
const MONSTER_BLOCK := 8   # lines flagged "block monsters"
const PICKUP := 16

## Doom map units to meters (a 56-unit tall player is 1.75 m).
const S := 1.0 / 32.0
