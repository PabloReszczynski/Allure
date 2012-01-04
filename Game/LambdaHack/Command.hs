module Game.LambdaHack.Command where

import Control.Monad
import Control.Monad.State hiding (State, state)
import qualified Data.List as L
import qualified Data.Map as M
import qualified Data.Char as Char

import Game.LambdaHack.Utils.Assert
import Game.LambdaHack.Action
import Game.LambdaHack.Actions
import Game.LambdaHack.ItemAction
import Game.LambdaHack.Grammar
import qualified Game.LambdaHack.Config as Config
import Game.LambdaHack.EffectAction
import Game.LambdaHack.Keybindings
import qualified Game.LambdaHack.Keys as K
import Game.LambdaHack.Level
import Game.LambdaHack.Actor
import Game.LambdaHack.State
import Game.LambdaHack.Dir
import qualified Game.LambdaHack.Feature as F

data Cmd =
    Apply       { verb :: Verb, object :: Object, syms :: [Char] }
  | Project     { verb :: Verb, object :: Object, syms :: [Char] }
  | TriggerDir  { verb :: Verb, object :: Object, feature :: F.Feature }
  | TriggerTile { verb :: Verb, object :: Object, feature :: F.Feature }
  | Pickup
  | Drop
  | Inventory
  | TgtFloor
  | TgtEnemy
  | TgtAscend Int
  | GameSave
  | GameQuit
  | Cancel
  | Accept
  | History
  | CfgDump
  | HeroCycle
  | Version
  | Help
  | Wait
  deriving (Show, Read)

moveDirCommand, runDirCommand :: Described (Dir -> Action ())
moveDirCommand   = Described "move in direction" move
runDirCommand    = Described "run in direction"  (\ dir -> run (dir, 0))

majorCmd :: Cmd -> Bool
majorCmd cmd = case cmd of
  Apply{}       -> True
  Project{}     -> True
  TriggerDir{}  -> True
  TriggerTile{} -> True
  Pickup        -> True
  Drop          -> True
  Inventory     -> True
  GameSave      -> True
  GameQuit      -> True
  Help          -> True
  _             -> False

heroSelection :: [(K.Key, Described (Action ()))]
heroSelection =
  let heroSelect k = (K.Char (Char.intToDigit k),
                      Undescribed $
                      selectPlayer (AHero k) >> return ())
  in fmap heroSelect [0..9]

cmdSemantics :: Cmd -> Action ()
cmdSemantics cmd = case cmd of
  Apply   verb obj syms -> checkCursor $ playerApplyGroupItem verb obj syms
  Project verb obj syms -> checkCursor $ playerProjectGroupItem verb obj syms
  TriggerDir  _verb _obj feat -> checkCursor $ playerTriggerDir feat
  TriggerTile _verb _obj feat -> checkCursor $ playerTriggerTile feat
  Pickup ->    checkCursor pickupItem
  Drop ->      checkCursor dropItem
  Inventory -> inventory
  TgtFloor ->  checkCursor $ targetFloor   TgtPlayer
  TgtEnemy ->  checkCursor $ targetMonster TgtPlayer
  TgtAscend k -> tgtAscend k
  GameSave ->  saveGame
  GameQuit ->  quitGame
  Cancel ->    cancelCurrent
  Accept ->    acceptCurrent displayHelp
  History ->   displayHistory
  CfgDump ->   dumpConfig
  HeroCycle -> cycleHero
  Version ->   gameVersion
  Help ->      displayHelp
  Wait ->      playerAdvanceTime

cmdDescription :: Cmd -> Maybe String
cmdDescription cmd = case cmd of
  Apply   verb obj _syms -> Just $ verb ++ " " ++ addIndefinite obj
  Project verb obj _syms -> Just $ verb ++ " " ++ addIndefinite obj
  TriggerDir  verb obj _feat -> Just $ verb ++ " " ++ addIndefinite obj
  TriggerTile verb obj _feat -> Just $ verb ++ " " ++ addIndefinite obj
  Pickup ->    Just "get an object"
  Drop ->      Just "drop an object"
  Inventory -> Just "display inventory"
  TgtFloor ->  Just "target location"
  TgtEnemy ->  Just "target monster"
  TgtAscend k | k == 1  -> Just $ "target next shallower level"
  TgtAscend k | k >= 2  -> Just $ "target " ++ show k    ++ " levels shallower"
  TgtAscend k | k == -1 -> Just $ "target next deeper level"
  TgtAscend k | k <= -2 -> Just $ "target " ++ show (-k) ++ " levels deeper"
  TgtAscend _ -> error $ "void level change in targeting mode in config file"
  GameSave ->  Just "save and exit the game"
  GameQuit ->  Just "quit without saving"
  Cancel ->    Just "cancel action"
  Accept ->    Just "accept choice"
  History ->   Just "display previous messages"
  CfgDump ->   Just "dump current configuration"
  HeroCycle -> Just "cycle among heroes on level"
  Version ->   Just "display game version"
  Help ->      Just "display help"
  Wait ->      Nothing

configCommands :: Config.CP -> [(K.Key, Cmd)]
configCommands config =
  let section = Config.getItems config "commands"
      mkKey s =
        case K.keyTranslate s of
          K.Unknown _ -> assert `failure` ("unknown command key " ++ s)
          key -> key
      mkCmd s = read s :: Cmd
      mkCommand (key, def) = (mkKey key, mkCmd def)
  in L.map mkCommand section

semanticsCommands :: [(K.Key, Cmd)]
                  -> (Cmd -> Action ())
                  -> (Cmd -> Maybe String)
                  -> [(K.Key, Described (Action ()))]
semanticsCommands cmdList cmdS cmdD =
  let mkDescribed cmd =
        case cmdD cmd of
          Nothing -> Undescribed $ cmdS cmd
          Just d  -> Described d $ cmdS cmd
      mkCommand (key, def) = (key, mkDescribed def)
  in L.map mkCommand cmdList

stdKeybindings :: Config.CP
               -> M.Map K.Key K.Key
               -> (Cmd -> Action ())
               -> (Cmd -> Maybe String)
               -> Keybindings (Action ())
stdKeybindings config kmacro cmdS cmdD =
  let cmdList = configCommands config
      semList = semanticsCommands cmdList cmdS cmdD
  in Keybindings
  { kdir   = moveDirCommand
  , kudir  = runDirCommand
  , kother = M.fromList $
             heroSelection ++
             semList ++
             [ -- debug commands, TODO: access them from a common menu or prefix
               (K.Char 'R', Undescribed $ modify toggleVision),
               (K.Char 'O', Undescribed $ modify toggleOmniscient),
               (K.Char 'I', Undescribed $ gets (lmeta . slevel) >>= abortWith)
             ]
  , kmacro
  , kmajor = L.map fst $ L.filter (majorCmd . snd) cmdList
  }