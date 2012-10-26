-- Copyright (c) 2008--2011 Andres Loeh, 2010--2012 Mikolaj Konarski
-- This file is a part of the computer game Allure of the Stars
-- and is released under the terms of the GNU Affero General Public License.
-- For license and copyright information, see the file LICENSE.
--
-- | Rooms, halls and passages for Allure of the Stars.
module Content.PlaceKind ( cdefs ) where

import qualified Game.LambdaHack.Content as Content
import Game.LambdaHack.Content.PlaceKind

cdefs :: Content.CDefs PlaceKind
cdefs = Content.CDefs
  { getSymbol = psymbol
  , getName = pname
  , getFreq = pfreq
  , validate = pvalidate
  , content =
      [rect, oval, ovalFloor, ovalSquare, colonnade, colonnadeWide, maze,  maze2, maze3, mazeBig, mazeBig2, mazeBig3, cells]
  }
rect,        oval, ovalFloor, ovalSquare, colonnade, colonnadeWide, maze,  maze2, maze3, mazeBig, mazeBig2, mazeBig3, cells :: PlaceKind

rect = PlaceKind  -- Valid for any nonempty area, hence low frequency.
  { psymbol  = 'r'
  , pname    = "room"
  , pfreq    = [("rogue", 100)]
  , pcover   = CStretch
  , pfence   = FWall
  , ptopLeft = ["."]
  }
oval = PlaceKind
  { psymbol  = 'o'
  , pname    = "oval room"
  , pfreq    = [("rogue", 1000)]
  , pcover   = CStretch
  , pfence   = FWall
  , ptopLeft = [ "####.."
               , "##...."
               , "#....."
               , "#....."
               , "......"
               , "......"
               ]
  }
ovalFloor = oval  -- Without outer solid fence, visible from outside.
  { pfreq    = [("rogue", 10000)]
  , pfence   = FFloor
  , ptopLeft = [ "XXXX+#"
               , "XX###."
               , "X##..."
               , "X#...."
               , "+#...."
               , "#....."
               ]
  }
ovalSquare = ovalFloor
  { ptopLeft = [ "X###+"
               , "##..."
               , "#...."
               , "#...."
               , "+...."
               ]
  }
colonnade = PlaceKind
  { psymbol  = 'c'
  , pname    = "colonnade"
  , pfreq    = [("rogue", 1000)]
  , pcover   = CAlternate
  , pfence   = FFloor
  , ptopLeft = [ ".#"
               , "#."
               ]
  }
colonnadeWide = colonnade
  { pfreq    = [("rogue", 50)]
  , pfence   = FWall
  , ptopLeft = [ ".."
               , ".#"
               ]
  }
maze = PlaceKind
  { psymbol  = 'm'
  , pname    = "maze"
  , pfreq    = [("rogue", 20)]
  , pcover   = CStretch
  , pfence   = FNone
  , ptopLeft = [ "#.#.##"
               , "##.#.."
               , "#.##.#"
               , "#.#.#."
               ]
  }
maze2 = maze
  { ptopLeft = [ "###.##"
               , ".###.."
               , "..#..#"
               , ".#..#."
               ]
  }
maze3 = maze
  { ptopLeft = [ "###.##"
               , ".##.#."
               , "..##.#"
               , ".#..#."
               ]
  }
mazeBig = maze
  { pfreq    = [("rogue", 1000)]
  , ptopLeft = [ "#.#.##"
               , ".#.#.."
               , "#.#.##"
               , ".#.#.."
               , "#.#..#"
               , "#.#.#."
               ]
  }
mazeBig2 = mazeBig
  { ptopLeft = [ "##..##"
               , "#.##.."
               , ".#.###"
               , ".##.#."
               , "#.##.#"
               , "#.#.#."
               ]
  }
mazeBig3 = mazeBig
  { ptopLeft = [ "##..##"
               , "#.###."
               , ".#...#"
               , ".#.##."
               , "##.#.#"
               , "#.#.#."
               ]
  }
cells = PlaceKind
  { psymbol  = '#'
  , pname    = "cells"
  , pfreq    = [("rogue", 30)]
  , pcover   = CReflect
  , pfence   = FWall
  , ptopLeft = [ "..#"
               , "..#"
               , "##."
               ]
  }
-- TODO: obtain all the reet as places nested within places.
-- 3 places are enough, with 1 or 2 tiles between places,
-- on all sides, only vertical, only horizontal,