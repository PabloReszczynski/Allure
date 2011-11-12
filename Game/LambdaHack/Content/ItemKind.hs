module Game.LambdaHack.Content.ItemKind
  ( ItemKind(..)
  ) where

import Game.LambdaHack.Color
import qualified Game.LambdaHack.Content.Content as Content
import Game.LambdaHack.Effect
import Game.LambdaHack.Flavour
import Game.LambdaHack.Random

-- TODO: jpower is out of place here. It doesn't make sense for all items,
-- and will mean different things for different items. Perhaps it should
-- be part of the Effect, but then we have to be careful to distinguish
-- parts of the Effect that are rolled on item creation and those rolled
-- at each use (e.g., sword magical +damage vs. sword damage dice).
-- Another thing to keep in minds is that jpower will heavily determine
-- the value of the item for shops, treasure chests, artifact set rebalancing,
-- etc., so if we make jpower complex, the value computation gets complex too.
data ItemKind = ItemKind
  { isymbol  :: !Char       -- ^ map symbol
  , iflavour :: ![Flavour]  -- ^ possible flavours
  , iname    :: !String     -- ^ group name
  , ieffect  :: !Effect     -- ^ the effect when activated
  , icount   :: !RollQuad   -- ^ created in that quantify
  , ifreq    :: !Int        -- ^ created that often
  , ipower   :: !RollQuad   -- ^ created with that power
  }
  deriving (Show, Eq, Ord)

instance Content.Content ItemKind where
  getFreq = ifreq
  content =
    [amulet, dart, gem1, gem2, gem3, gem4, gold, potion1, potion2, potion3, ring, scroll1, scroll2, sword, fist, wand]

amulet,      dart, gem1, gem2, gem3, gem4, gold, potion1, potion2, potion3, ring, scroll1, scroll2, sword, fist, wand :: ItemKind

gem, potion, scroll :: ItemKind  -- generic templates

-- rollQuad (a, b, x, y) = a * roll b + (lvl * x * roll y) / 10

amulet = ItemKind
  { isymbol  = '"'
  , iflavour = [(BrGreen, True)]
  , iname    = "amulet"
  , ieffect  = Regneration
  , icount   = intToQuad 1
  , ifreq    = 10
  , ipower   = (2, 1, 2, 2)
  }
dart = ItemKind
  { isymbol  = ')'
  , iflavour = [(Yellow, False)]
  , iname    = "dart"
  , ieffect  = Wound (1, 1)
  , icount   = (3, 3, 0, 0)
  , ifreq    = 30
  , ipower   = intToQuad 0
  }
gem = ItemKind
  { isymbol  = '*'
  , iflavour = zipPlain brightCol  -- natural, so not fancy
  , iname    = "gem"
  , ieffect  = NoEffect
  , icount   = intToQuad 0
  , ifreq    = 20  -- x4, but rare on shallow levels
  , ipower   = intToQuad 0
  }
gem1 = gem
  { icount   = (1, 1, 0, 0)  -- appears on lvl 1
  }
gem2 = gem
  { icount   = (0, 0, 2, 1)  -- appears on lvl 5, doubled on lvl 10
  }
gem3 = gem
  { icount   = (0, 0, 1, 1)  -- appears on lvl 10
  }
gem4 = gem
  { icount   = (0, 0, 1, 1)  -- appears on lvl 10
  }
gold = ItemKind
  { isymbol  = '$'
  , iflavour = [(BrYellow, False)]
  , iname    = "gold piece"
  , ieffect  = NoEffect
  , icount   = (0, 0, 10, 10)
  , ifreq    = 80
  , ipower   = intToQuad 0
  }
potion = ItemKind
  { isymbol  = '!'
  , iflavour = zipFancy stdCol
  , iname    = "potion"
  , ieffect  = NoEffect
  , icount   = intToQuad 1
  , ifreq    = 10
  , ipower   = intToQuad 0
  }
potion1 = potion
  { ieffect  = ApplyPerfume
  }
potion2 = potion
  { ieffect  = Heal
  , ipower   = (10, 1, 0, 0)
  }
potion3 = potion
  { ieffect  = Wound (0, 0)
  , ipower   = (10, 1, 0, 0)
  }
ring = ItemKind
  { isymbol  = '='
  , iflavour = [(White, False)]
  , iname    = "ring"
  , ieffect  = Searching
  , icount   = intToQuad 1
  , ifreq    = 10
  , ipower   = (1, 1, 2, 2)
  }
scroll = ItemKind
  { isymbol  = '?'
  , iflavour = zipFancy darkCol  -- arcane and old
  , iname    = "scroll"
  , ieffect  = NoEffect
  , icount   = intToQuad 1
  , ifreq    = 10
  , ipower   = intToQuad 0
  }
scroll1 = scroll
  { ieffect  = SummonFriend
  , ifreq    = 20
  }
scroll2 = scroll
  { ieffect  = SummonEnemy
  }
sword = ItemKind
  { isymbol  = ')'
  , iflavour = [(BrCyan, False)]
  , iname    = "sword"
  , ieffect  = Wound (3, 1)
  , icount   = intToQuad 1
  , ifreq    = 60
  , ipower   = (1, 2, 4, 2)
  }
fist = sword
  { iname    = "fist"
  , ifreq    = 0  -- Does not appear randomly in the dungeon.
  }
wand = ItemKind
  { isymbol  = '/'
  , iflavour = [(BrRed, True)]
  , iname    = "wand"
  , ieffect  = Dominate
  , icount   = intToQuad 1
  , ifreq    = 10
  , ipower   = intToQuad 0
  }