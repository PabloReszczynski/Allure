-- Copyright (c) 2008--2011 Andres Loeh
-- Copyright (c) 2010--2018 Mikolaj Konarski and others (see git history)
-- This file is a part of the computer game Allure of the Stars
-- and is released under the terms of the GNU Affero General Public License.
-- For license and copyright information, see the file LICENSE.
--
-- | Blast definitions.
module Content.ItemKindBlast
  ( blasts
  ) where

import Prelude ()

import Game.LambdaHack.Common.Prelude

import Game.LambdaHack.Common.Color
import Game.LambdaHack.Common.Dice
import Game.LambdaHack.Common.Flavour
import Game.LambdaHack.Common.Misc
import Game.LambdaHack.Content.ItemKind

blasts :: [ItemKind]
blasts =
  [burningOil2, burningOil3, burningOil4, firecracker1, firecracker2, firecracker3, firecracker4, firecracker5, violentChemical, fragrance, pheromone, mistCalming, odorDistressing, mistHealing, mistHealing2, mistWounding, distortion, glassPiece, smoke, boilingWater, glue, singleSpark, spark, denseShower, sparseShower, protectingBalmMelee, protectingBalmRanged, vulnerabilityBalm, resolutionDust, hasteSpray, slownessMist, eyeDrop, ironFiling, smellyDroplet, eyeShine, whiskeySpray, waste, youthSprinkle, poisonCloud, mistAntiSlow, mistAntidote]
  -- Allure-specific
  ++ [cruiseAdHologram, outerAdHologram, victoriaClassHologram, allureIntroHologram]

burningOil2,    burningOil3, burningOil4, firecracker1, firecracker2, firecracker3, firecracker4, firecracker5, violentChemical, fragrance, pheromone, mistCalming, odorDistressing, mistHealing, mistHealing2, mistWounding, distortion, glassPiece, smoke, boilingWater, glue, singleSpark, spark, denseShower, sparseShower, protectingBalmMelee, protectingBalmRanged, vulnerabilityBalm, resolutionDust, hasteSpray, slownessMist, eyeDrop, ironFiling, smellyDroplet, eyeShine, whiskeySpray, waste, youthSprinkle, poisonCloud, mistAntiSlow, mistAntidote :: ItemKind
-- Allure-specific
cruiseAdHologram,       outerAdHologram, victoriaClassHologram, allureIntroHologram :: ItemKind

-- We take care (e.g., in burningOil below) that blasts are not faster
-- than 100% fastest natural speed, or some frames would be skipped,
-- which is a waste of prefectly good frames.

-- * Parameterized immediate effect blasts

burningOil :: Int -> ItemKind
burningOil n = ItemKind
  { isymbol  = '*'
  , iname    = "burning oil"
  , ifreq    = [(toGroupName $ "burning oil" <+> tshow n, 1)]
  , iflavour = zipFancy [BrYellow]
  , icount   = intToDice (n * 8)
  , irarity  = [(1, 1)]
  , iverbHit = "sear"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = [AddShine 2]
  , ieffects = [Burn 1, Paralyze 2]  -- tripping on oil
  , ifeature = [ toVelocity (min 100 $ n `div` 2 * 10)
               , Fragile, Identified, Blast ]
  , idesc    = "Sticky oil, burning brightly."
  , ikit     = []
  }
burningOil2 = burningOil 2  -- 2 steps, 2 turns
burningOil3 = burningOil 3  -- 3 steps, 2 turns
burningOil4 = burningOil 4  -- 4 steps, 2 turns
firecracker :: Int -> ItemKind
firecracker n = ItemKind
  { isymbol  = '*'
  , iname    = "firecracker"
  , ifreq    = [(toGroupName $ if n == 5
                               then "firecracker"
                               else "firecracker" <+> tshow n, 1)]
  , iflavour = zipPlain [brightCol !! ((n + 2) `mod` length brightCol)]
  , icount   = if n <= 3 then 1 `d` min 2 n else 2 + 1 `d` 2
  , irarity  = [(1, 1)]
  , iverbHit = "crack"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = [AddShine $ intToDice $ 1 + n `div` 2]
  , ieffects = [RefillCalm 2]
               ++ [DropBestWeapon | n >= 4]
               ++ [ OnSmash $ Explode
                    $ toGroupName $ "firecracker" <+> tshow (n - 1)
                  | n >= 2 ]
  , ifeature = [toVelocity 5, Fragile, Identified, Blast]
  , idesc    = "Scraps of burnt paper, covering little pockets of black powder, buffeted by colorful explosions."
  , ikit     = []
  }
firecracker5 = firecracker 5
firecracker4 = firecracker 4
firecracker3 = firecracker 3
firecracker2 = firecracker 2
firecracker1 = firecracker 1

-- * Assorted immediate effect blasts

violentChemical = ItemKind
  { isymbol  = '*'
  , iname    = "detonation blast"
  , ifreq    = [("violent chemical", 1)]
  , iflavour = zipPlain [BrBlack]
  , icount   = 16  -- strong and wide, but few, so not always hits target
  , irarity  = [(1, 1)]
  , iverbHit = "tear apart"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = [AddShine 10]
  , ieffects = [ RefillHP (-5)  -- deadly
               , PushActor (ThrowMod 200 50)
               , DropItem 1 maxBound COrgan "temporary condition"
               , DropItem 1 maxBound COrgan "impressed" ]  -- shocking
  , ifeature = [toLinger 20, Fragile, Identified, Blast]  -- 4 steps, 1 turn
  , idesc    = ""
  , ikit     = []
  }
fragrance = ItemKind
  { isymbol  = '`'
  , iname    = "fragrance"  -- instant, fast fragrance
  , ifreq    = [("fragrance", 1)]
  , iflavour = zipFancy [Magenta]
  , icount   = 12
  , irarity  = [(1, 1)]
  , iverbHit = "engulf"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [Impress]
  -- Linger 10, because sometimes it takes 2 turns due to starting just
  -- before actor turn's end (e.g., via a necklace).
  , ifeature = [toLinger 10, Fragile, Identified, Blast]  -- 2 steps, 1 turn
  , idesc    = "A pleasant scent."
  , ikit     = []
  }
pheromone = ItemKind
  { isymbol  = '`'
  , iname    = "musky whiff"  -- a kind of mist rather than fragrance
  , ifreq    = [("pheromone", 1)]
  , iflavour = zipFancy [BrMagenta]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "tempt"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [Impress, RefillCalm (-10)]
  , ifeature = [toVelocity 10, Fragile, Identified, Blast]  -- 2 steps, 2 turns
  , idesc    = "A sharp, strong scent."
  , ikit     = []
  }
mistCalming = ItemKind  -- unused
  { isymbol  = '`'
  , iname    = "mist"
  , ifreq    = [("calming mist", 1)]
  , iflavour = zipFancy [BrGreen]
  , icount   = 8
  , irarity  = [(1, 1)]
  , iverbHit = "sooth"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [RefillCalm 2]
  , ifeature = [toVelocity 5, Fragile, Identified, Blast]  -- 1 step, 1 turn
  , idesc    = "A soothing, gentle cloud."
  , ikit     = []
  }
odorDistressing = ItemKind
  { isymbol  = '`'
  , iname    = "distressing whiff"
  , ifreq    = [("distressing odor", 1)]
  , iflavour = zipFancy [BrRed]
  , icount   = 8
  , irarity  = [(1, 1)]
  , iverbHit = "distress"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [RefillCalm (-20)]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]  -- 2 steps, 1 turn
  , idesc    = "It turns the stomach."
  , ikit     = []
  }
mistHealing = ItemKind
  { isymbol  = '`'
  , iname    = "mist"  -- powerful, so slow and narrow
  , ifreq    = [("healing mist", 1)]
  , iflavour = zipFancy [BrGreen]
  , icount   = 8
  , irarity  = [(1, 1)]
  , iverbHit = "revitalize"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = [AddShine 1]
  , ieffects = [RefillHP 2]
  , ifeature = [toVelocity 5, Fragile, Identified, Blast]  -- 1 step, 1 turn
  , idesc    = "It fills the air with light and life."
  , ikit     = []
  }
mistHealing2 = ItemKind
  { isymbol  = '`'
  , iname    = "mist"
  , ifreq    = [("healing mist 2", 1)]
  , iflavour = zipFancy [BrGreen]
  , icount   = 8
  , irarity  = [(1, 1)]
  , iverbHit = "revitalize"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = [AddShine 2]
  , ieffects = [RefillHP 4]
  , ifeature = [toVelocity 5, Fragile, Identified, Blast]  -- 1 step, 1 turn
  , idesc    = "At its touch, wounds close and bruises fade."
  , ikit     = []
  }
mistWounding = ItemKind
  { isymbol  = '`'
  , iname    = "mist"
  , ifreq    = [("wounding mist", 1)]
  , iflavour = zipFancy [BrRed]
  , icount   = 8
  , irarity  = [(1, 1)]
  , iverbHit = "devitalize"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [RefillHP (-2)]
  , ifeature = [toVelocity 5, Fragile, Identified, Blast]  -- 1 step, 1 turn
  , idesc    = "The air itself stings and itches."
  , ikit     = []
  }
distortion = ItemKind
  { isymbol  = 'v'
  , iname    = "vortex"
  , ifreq    = [("distortion", 1)]
  , iflavour = zipFancy [White]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "engulf"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [Teleport $ 15 + 1 `d` 10]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]  -- 2 steps, 1 turn
  , idesc    = "The air shifts oddly, as though light is being warped."
  , ikit     = []
  }
glassPiece = ItemKind  -- when blowing up windows
  { isymbol  = '*'
  , iname    = "glass piece"
  , ifreq    = [("glass piece", 1)]
  , iflavour = zipPlain [BrBlue]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "cut"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [RefillHP (-1)]  -- high velocity, so can't do idamage
  , ifeature = [toLinger 20, Fragile, Identified, Blast]  -- 4 steps, 1 turn
  , idesc    = "Swift, sharp edges."
  , ikit     = []
  }
smoke = ItemKind  -- when stuff burns out  -- unused
  { isymbol  = '`'
  , iname    = "smoke"
  , ifreq    = [("smoke", 1)]
  , iflavour = zipPlain [BrBlack]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "choke"  -- or obscure
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = []
  , ifeature = [toVelocity 20, Fragile, Identified, Blast]  -- 4 steps, 2 turns
  , idesc    = "Twirling clouds of grey smoke."
  , ikit     = []
  }
boilingWater = ItemKind
  { isymbol  = '*'
  , iname    = "boiling water"
  , ifreq    = [("boiling water", 1)]
  , iflavour = zipPlain [White]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "boil"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [Burn 1]
  , ifeature = [toVelocity 30, Fragile, Identified, Blast]  -- 6 steps, 2 turns
  , idesc    = "It bubbles and hisses."
  , ikit     = []
  }
glue = ItemKind
  { isymbol  = '*'
  , iname    = "hoof glue"
  , ifreq    = [("glue", 1)]
  , iflavour = zipPlain [Cyan]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "glue"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [Paralyze 10]
  , ifeature = [toVelocity 20, Fragile, Identified, Blast]  -- 4 steps, 2 turns
  , idesc    = "Thick and clinging."
  , ikit     = []
  }
singleSpark = ItemKind
  { isymbol  = '`'
  , iname    = "single spark"
  , ifreq    = [("single spark", 1)]
  , iflavour = zipPlain [BrWhite]
  , icount   = 1
  , irarity  = [(1, 1)]
  , iverbHit = "spark"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = [AddShine 4]
  , ieffects = []
  , ifeature = [toLinger 5, Fragile, Identified, Blast]  -- 1 step, 1 turn
  , idesc    = "A glowing ember."
  , ikit     = []
  }
spark = ItemKind
  { isymbol  = '`'
  , iname    = "spark"
  , ifreq    = [("spark", 1)]
  , iflavour = zipPlain [BrWhite]
  , icount   = 12
  , irarity  = [(1, 1)]
  , iverbHit = "scorch"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = [AddShine 4]
  , ieffects = [Burn 1]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]  -- 2 steps, 1 turn
  , idesc    = "A flash of fire."
  , ikit     = []
  }

-- * Temporary condition blasts strictly matching the aspects

-- Almost all have @toLinger 10@, that travels 2 steps in 1 turn.
-- These are very fast projectiles, not getting into the way of big
-- actors and not burdening the engine for long.

denseShower = ItemKind
  { isymbol  = '`'
  , iname    = "dense shower"
  , ifreq    = [("dense shower", 1)]
  , iflavour = zipFancy [Green]
  , icount   = 12
  , irarity  = [(1, 1)]
  , iverbHit = "strengthen"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganActorTurn "strengthened" (3 + 1 `d` 3)]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = "A thick rain of droplets."
  , ikit     = []
  }
sparseShower = ItemKind
  { isymbol  = '`'
  , iname    = "sparse shower"
  , ifreq    = [("sparse shower", 1)]
  , iflavour = zipFancy [Red]
  , icount   = 8
  , irarity  = [(1, 1)]
  , iverbHit = "weaken"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganGameTurn "weakened" (3 + 1 `d` 3)]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = "Light droplets that cling to clothing."
  , ikit     = []
  }
protectingBalmMelee = ItemKind
  { isymbol  = '`'
  , iname    = "balm droplet"
  , ifreq    = [("melee protective balm", 1)]
  , iflavour = zipPlain [Brown]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "balm"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganActorTurn "protected from melee" (3 + 1 `d` 3)]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = "A thick ointment that hardens the skin."
  , ikit     = []
  }
protectingBalmRanged = ItemKind
  { isymbol  = '`'
  , iname    = "balm droplet"
  , ifreq    = [("ranged protective balm", 1)]
  , iflavour = zipPlain [BrYellow]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "balm"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganActorTurn "protected from ranged" (3 + 1 `d` 3)]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = "Grease that protects from flying death."
  , ikit     = []
  }
vulnerabilityBalm = ItemKind
  { isymbol  = '`'
  , iname    = "red paint"
  , ifreq    = [("red paint", 1)]
  , iflavour = zipPlain [BrRed]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "paint"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganGameTurn "painted red" (3 + 1 `d` 3)]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = ""
  , ikit     = []
  }
resolutionDust = ItemKind
  { isymbol  = '`'
  , iname    = "resolution dust"
  , ifreq    = [("resolution dust", 1)]
  , iflavour = zipPlain [Brown]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "calm"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganActorTurn "resolute" (3 + 1 `d` 3)]
                 -- short enough duration that @calmEnough@ not a big problem
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = "A handful of honest earth, to strengthen the soul."
  , ikit     = []
  }
hasteSpray = ItemKind
  { isymbol  = '`'
  , iname    = "haste spray"
  , ifreq    = [("haste spray", 1)]
  , iflavour = zipPlain [BrYellow]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "haste"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganActorTurn "hasted" (3 + 1 `d` 3)]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = "A quick spurt."
  , ikit     = []
  }
slownessMist = ItemKind
  { isymbol  = '`'
  , iname    = "slowness mist"
  , ifreq    = [("slowness mist", 1)]
  , iflavour = zipPlain [BrBlue]
  , icount   = 8
  , irarity  = [(1, 1)]
  , iverbHit = "slow"
  , iweight  = 0
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganGameTurn "slowed" (3 + 1 `d` 3)]
  , ifeature = [toVelocity 5, Fragile, Identified, Blast]
                 -- 1 step, 1 turn, mist
  , idesc    = "Clammy fog, making each movement an effort."
  , ikit     = []
  }
eyeDrop = ItemKind
  { isymbol  = '`'
  , iname    = "eye drop"
  , ifreq    = [("eye drop", 1)]
  , iflavour = zipPlain [BrCyan]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "cleanse"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganActorTurn "far-sighted" (3 + 1 `d` 3)]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = "Not to be taken orally."
  , ikit     = []
  }
ironFiling = ItemKind
  { isymbol  = '`'
  , iname    = "iron filing"
  , ifreq    = [("iron filing", 1)]
  , iflavour = zipPlain [Brown]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "blind"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganActorTurn "blind" (10 + 1 `d` 10)]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = "A shaving of bright metal."
  , ikit     = []
  }
smellyDroplet = ItemKind
  { isymbol  = '`'
  , iname    = "smelly droplet"
  , ifreq    = [("smelly droplet", 1)]
  , iflavour = zipPlain [Blue]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "sensitize"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganActorTurn "keen-smelling" (3 + 1 `d` 3)]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = "A viscous lump that stains the skin."
  , ikit     = []
  }
eyeShine = ItemKind
  { isymbol  = '`'
  , iname    = "eye shine"
  , ifreq    = [("eye shine", 1)]
  , iflavour = zipPlain [Cyan]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "smear"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganActorTurn "shiny-eyed" (3 + 1 `d` 3)]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = "They almost glow in the dark."
  , ikit     = []
  }

-- * Assorted temporary condition blasts or related (also, matching flasks)

whiskeySpray = ItemKind
  { isymbol  = '`'
  , iname    = "whiskey spray"
  , ifreq    = [("whiskey spray", 1)]
  , iflavour = zipPlain [Brown]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "inebriate"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganActorTurn "drunk" (3 + 1 `d` 3)]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = "It burns in the best way."
  , ikit     = []
  }
waste = ItemKind
  { isymbol  = '*'
  , iname    = "waste"
  , ifreq    = [("waste", 1)]
  , iflavour = zipPlain [Brown]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "splosh"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [Burn 1]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = "Sodden and foul-smelling."
  , ikit     = []
  }
youthSprinkle = ItemKind
  { isymbol  = '`'
  , iname    = "youth sprinkle"
  , ifreq    = [("youth sprinkle", 1)]
  , iflavour = zipPlain [BrGreen]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "sprinkle"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganNone "regenerating"]
  , ifeature = [toLinger 10, Fragile, Identified, Blast]
  , idesc    = "Bright and smelling of the Spring."
  , ikit     = []
  }
poisonCloud = ItemKind
  { isymbol  = '`'
  , iname    = "poison cloud"
  , ifreq    = [("poison cloud", 1)]
  , iflavour = zipPlain [BrMagenta]
  , icount   = 16
  , irarity  = [(1, 1)]
  , iverbHit = "poison"
  , iweight  = 0
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganNone "poisoned"]
  , ifeature = [toVelocity 10, Fragile, Identified, Blast]  -- 2 steps, 2 turns
  , idesc    = "Choking gas that stings the eyes."
  , ikit     = []
  }
mistAntiSlow = ItemKind
  { isymbol  = '`'
  , iname    = "mist"
  , ifreq    = [("anti-slow mist", 1)]
  , iflavour = zipPlain [BrYellow]
  , icount   = 8
  , irarity  = [(1, 1)]
  , iverbHit = "propel"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [DropItem 1 1 COrgan "slowed"]
  , ifeature = [toVelocity 5, Fragile, Identified, Blast]  -- 1 step, 1 turn
  , idesc    = "A cleansing rain."
  , ikit     = []
  }
mistAntidote = ItemKind
  { isymbol  = '`'
  , iname    = "mist"
  , ifreq    = [("antidote mist", 1)]
  , iflavour = zipPlain [BrBlue]
  , icount   = 8
  , irarity  = [(1, 1)]
  , iverbHit = "cure"
  , iweight  = 1
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [DropItem 1 maxBound COrgan "poisoned"]
  , ifeature = [toVelocity 5, Fragile, Identified, Blast]  -- 1 step, 1 turn
  , idesc    = "Washes away death's dew."
  , ikit     = []
  }

-- * Allure-specific

-- ** Lore basts

-- They exist for a short time only, but the lore can be read
-- from the lore menu. Only optional story bits should go there,
-- becuase some players may not even notice them (at first, at least).
-- This is designed not to spam gameplay with story. Gameplay first.
-- Generally, 3 to 5 blasts of each kind should suffice for variety.
-- More would induce long repetition to see all (they are shown at random).
-- With mild exceptions, they should have no effects.

cruiseAdHologram = ItemKind
  { isymbol  = '`'
  , iname    = "cruise ad hologram"
  , ifreq    = [("cruise ad hologram", 1), ("advertisement", 20)]
  , iflavour = zipFancy [BrMagenta]
  , icount   = 8
  , irarity  = [(1, 1)]
  , iverbHit = "excite"
  , iweight  = 0  -- delay of 1 turn at the start, to easily read the text
  , idamage  = toDmg 0
  , iaspects = []
  , ieffects = [toOrganActorTurn "resolute" (5 + 1 `d` 2), DropBestWeapon]
  , ifeature = [toVelocity 5, Fragile, Identified, Blast]  -- 1 step, 1 turn
  , idesc    = "The fitful holographic clip shows a couple that laughs, watches in silence Saturn's rings through a huge window, throws treats to a little rhino frolicking in reduced gravity, runs through corridors wearing alien masks in a mock chase. An exited female voice proclaims: \"...safety and security, comfort, imagination...for each of your senses...robot servants...personalized life support zones...\""
  , ikit     = []
  }
outerAdHologram = cruiseAdHologram
  {  iname    = "cruise ad hologram"
  , ifreq    = [("advertisement", 10)]
  , icount   = 4
  , ieffects = []  -- weak, 4 particles, no effect
  , idesc    = "A composed young man in a hat looks straight into your eyes with unwavering stare and extols the opportunities, freedom and excitement of the outer Solar System frontier life with unshakable conviction. Names of Neptune-area realtors scroll at the bottom in small font with oversize serifs."
  }
victoriaClassHologram = outerAdHologram
  { iname    = "space fleet hologram"
  , ifreq    = [("story-telling", 20)]
  , iflavour = zipFancy [BrBlue]
  , icount   = 1
  , iverbHit = "bore"
  , idesc    = "A series of huge spaceships zoom in and out of view in a solemn procession. Male voice drones over crackling static: Victoria-class cruise liners are the largest passenger ships ever serially manufactured and the third largest in general, including transport vessel series. Bigger ships are sometimes cobbled ad-hoc, by wiring together cheap modules and primitive cargo hulls welded in space, but they are rarely certified for public commercial operation. Victoria-class passenger cruisers are produced for over three decades now, in slowly evolving configurations, one per two years on average. The design is as conservative, as possible. A disc large enough for comfortable artificial gravity through constant spinning. Fusion reactor in the middle of the axle powering engines protruding far back from the rear plane. Meteor shield at the front. Numerous redundant rechargeable power sources and autonomous life support areas, eliminating the \"all locked in a single can, breathing the same air\" space travel grievance. Actually, everything is redundant twice over, due to strict regulations. To sum it up, these are the most boring spaceships in the galaxy."
  }
allureIntroHologram = victoriaClassHologram
  { iname    = "spaceship hologram"
  , ifreq    = [("story-telling", 10)]
  , idesc    = "A wavy 3D wireframe of a spaceship rotates ponderously. Male voice drones: Allure of the Stars belongs to a long line of luxurious orbit-to-orbit cruise liners, the Victoria-class. It was named after the largest passenger sea vessel of the early 21st century and it shares the grandeur and the extravagance. This particular Victoria-class specimen was designed for long cruises to gas giants, their moons and the moon cities (and their notorious saloons). It has a meteor shield in the form of a flat, multi-layer. unpressurized cargo bay covering the front plane. Such extra cargo capacity enables long space journeys with no limits on resource usage. On shorter legs of the journeys it also enables opportunistic mass cargo transport (in accordance to strictest regulations and completely isolated from the airflow on passenger decks), which is always in demand at the profusely productive, but scarcely populated Solar System frontier. It also makes the unit much thicker than usual: the length from the tip of the cargo bay to the end of the engines is almost two thirds of the diameter of the disk. All in all, it is a particularly sturdy and self-sufficient member of a class famed for exceptional resilience and safety."
  }
