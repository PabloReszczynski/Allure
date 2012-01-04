module Game.LambdaHack.Start ( start ) where

import qualified System.Random as R
import Control.Monad
import qualified Control.Monad.State as MState
import qualified Data.Array.Unboxed as A

import Game.LambdaHack.Action
import Game.LambdaHack.State
import Game.LambdaHack.DungeonState
import qualified Game.LambdaHack.Display as Display
import qualified Game.LambdaHack.Save as Save
import Game.LambdaHack.Turn
import qualified Game.LambdaHack.Config as Config
import Game.LambdaHack.ActorAdd
import Game.LambdaHack.Item
import qualified Game.LambdaHack.Feature as F
import Game.LambdaHack.Content.TileKind
import Game.LambdaHack.Content.RuleKind
import Game.LambdaHack.Tile
import Game.LambdaHack.Command
import qualified Game.LambdaHack.Keybindings as KB
import qualified Game.LambdaHack.Kind as Kind

speedup :: Kind.Ops TileKind -> [Kind.Id TileKind -> Bool]
speedup Kind.Ops{ofoldrWithKey, obounds} =
  let createTab :: (TileKind -> Bool) -> A.UArray (Kind.Id TileKind) Bool
      createTab p =
        let f _ k acc = p k : acc
            clearAssocs = ofoldrWithKey f []
        in A.listArray obounds clearAssocs
      tabulate :: (TileKind -> Bool) -> Kind.Id TileKind -> Bool
      tabulate p = (createTab p A.!)
      isClearTab = tabulate $ kindHasFeature F.Clear
      isLitTab   = tabulate $ kindHasFeature F.Lit
  in [isClearTab, isLitTab]

speedupCops :: Kind.COps -> Kind.COps
speedupCops scops@Kind.COps{cotile=sct} =
  let ospeedup = speedup sct
      cotile = sct {Kind.ospeedup}
  in scops {Kind.cotile}

-- TODO: move somewhere sane, probably Config.hs
-- Warning: this function changes the config file!
getGen :: Config.CP -> String -> IO (R.StdGen, Config.CP)
getGen config option =
  case Config.getOption config "engine" option of
    Just sg -> return (read sg, config)
    Nothing -> do
      -- Pick the randomly chosen dungeon generator from the IO monad
      -- and record it in the config for debugging (can be 'D'umped).
      g <- R.newStdGen
      let gs = show g
          c = Config.set config "engine" option gs
      return (g, c)

-- | Either restore a saved game, or setup a new game.
start :: Kind.COps
      -> String
      -> (Cmd -> Action ())
      -> (Cmd -> Maybe String)
      -> Display.FrontendSession
      -> IO ()
start scops configDefault cmdS cmdD frontendSession = do
  let cops@Kind.COps{corule=Kind.Ops{okind, ouniqName}} = speedupCops scops
      title = rtitle $ okind $ ouniqName "standard game ruleset"
      pathsDataFile = rpathsDataFile $ okind $ ouniqName "standard game ruleset"
  config <- Config.mkConfig configDefault
  let section = Config.getItems config "macros"
      !macros = KB.macroKey section
      !keyb = stdKeybindings config macros cmdS cmdD
      sess = (frontendSession, cops, keyb)
  restored <- Save.restoreGame pathsDataFile config title
  case restored of
    Right (msg, diary) -> do  -- Starting a new game.
      (dg, configD) <- getGen config "dungeonRandomGenerator"
      (sg, sconfig) <- getGen configD "startingRandomGenerator"
      let ((ploc, lid, dng), ag) =
            MState.runState (generate cops configD) dg
          sflavour = MState.evalState (dungeonFlavourMap (Kind.coitem cops)) ag
          state = defaultState sconfig sflavour dng lid ploc sg
          hstate = initialHeroes cops ploc state
      handlerToIO sess hstate diary{smsg = msg} handle
    Left (state, diary) ->  -- Running a restored a game.
      handlerToIO sess state
        diary{smsg = "Welcome back to " ++ title ++ "."}  -- TODO: save old msg?
        handle