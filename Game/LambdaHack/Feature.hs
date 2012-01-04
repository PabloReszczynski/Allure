module Game.LambdaHack.Feature
  ( Feature(..)
  ) where

import Game.LambdaHack.Effect
import Game.LambdaHack.Random

data Feature =
    Walkable           -- ^ actors can walk through
  | Clear              -- ^ actors can see through
  | Exit               -- ^ is a non-secret door or a stair
  | Lit                -- ^ is lit with an ambient shine
  | Secret !RollDice   -- ^ tile is generated with this high secrecy value
  | Aura !Effect       -- ^ sustains the effect continuously, TODO
  | Cause !Effect      -- ^ causes the effect when triggered
  | ChangeTo !String   -- ^ transitions to any such tile when triggered
  | ChangeFrom !String -- ^ a possible target of transitions
  | Ascendable         -- ^ triggered by ascending
  | Descendable        -- ^ triggered by descending
  | Openable           -- ^ triggered by opening
  | Closable           -- ^ triggered by closing
  | Hidden             -- ^ triggered when the tile's secrecy becomes zero
  | Special            -- ^ a variation for special flavour
  | Boring             -- ^ items and stairs can be generated there
  deriving (Show, Read, Eq, Ord)