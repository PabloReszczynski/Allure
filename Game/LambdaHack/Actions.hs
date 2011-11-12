module Game.LambdaHack.Actions where

import Control.Monad
import Control.Monad.State hiding (State, state)
import qualified Data.List as L
import qualified Data.IntMap as IM
import Data.Maybe
import qualified Data.Set as S

import Game.LambdaHack.Utils.Assert
import Game.LambdaHack.Action
import Game.LambdaHack.Display hiding (display)
import Game.LambdaHack.Loc
import Game.LambdaHack.Dir
import Game.LambdaHack.Grammar
import qualified Game.LambdaHack.HighScores as H
import Game.LambdaHack.Item
import qualified Game.LambdaHack.Keys as K
import Game.LambdaHack.Level
import Game.LambdaHack.LevelState
import Game.LambdaHack.Actor
import Game.LambdaHack.ActorState
import Game.LambdaHack.Content.ActorKind
import Game.LambdaHack.ActorAdd
import Game.LambdaHack.Perception
import Game.LambdaHack.State
import qualified Game.LambdaHack.Config as Config
import qualified Game.LambdaHack.Save as Save
import Game.LambdaHack.EffectAction
import Game.LambdaHack.WorldLoc
import qualified Game.LambdaHack.Tile as Tile
import qualified Game.LambdaHack.Kind as Kind
import qualified Game.LambdaHack.Feature as F
import Game.LambdaHack.DungeonState

-- The Action stuff that is independent from ItemAction.hs.
-- (Both depend on EffectAction.hs).

displayHistory :: Action ()
displayHistory =
  do
    hst <- gets shistory
    messageOverlayConfirm "" (unlines hst)
    abort

dumpConfig :: Action ()
dumpConfig =
  do
    config <- gets sconfig
    let fn = "config.dump"
    liftIO $ Config.dump fn config
    abortWith $ "Current configuration dumped to file " ++ fn ++ "."

saveGame :: Action ()
saveGame =
  do
    b <- messageYesNo "Really save?"
    if b
      then do
        -- Save the game state
        state <- get
        liftIO $ Save.saveGame state
        ln <- gets slid
        let total = calculateTotal state
            status = H.Camping ln
        go <- handleScores False status total
        when go $ messageMore "See you soon, stronger and braver!"
        end
      else abortWith "Game resumed."

quitGame :: Action ()
quitGame =
  do
    b <- messageYesNo "Really quit?"
    if b
      then end -- no highscore display for quitters
      else abortWith "Game resumed."

-- | End targeting mode, accepting the current location or not.
endTargeting :: Bool -> Action ()
endTargeting accept = do
  returnLn <- gets (creturnLn . scursor)
  target   <- gets (btarget . getPlayerBody)
  cloc     <- gets (clocation . scursor)
  -- return to the original level of the player
  modify (\ state -> state{slid = returnLn})
  modify (updateCursor (\ c -> c { ctargeting = False }))
  let isEnemy = case target of TEnemy _ _ -> True ; _ -> False
  unless isEnemy $
    if accept
       then updatePlayerBody (\ p -> p { btarget = TLoc cloc })
       else updatePlayerBody (\ p -> p { btarget = TCursor })
  endTargetingMsg

endTargetingMsg :: Action ()
endTargetingMsg = do
  pbody  <- gets getPlayerBody
  state  <- get
  lxsize <- gets (lxsize . slevel)
  let verb = "target"
      targetMsg = case btarget pbody of
                    TEnemy a _ll ->
                      if memActor a state
                      then objectActor $ getActor a state
                      else "a fear of the past"
                    TLoc loc -> "location " ++ show (fromLoc lxsize loc)
                    TCursor  -> "current cursor position continuously"
  messageAdd $ subjectActorVerb pbody verb ++ " " ++ targetMsg ++ "."

-- | Cancel something, e.g., targeting mode, resetting the cursor
-- to the position of the player. Chosen target is not invalidated.
cancelCurrent :: Action ()
cancelCurrent = do
  targeting <- gets (ctargeting . scursor)
  if targeting
    then endTargeting False
    else abortWith "Press Q to quit."

-- | Accept something, e.g., targeting mode, keeping cursor where it was.
-- Or perform the default action, if nothing needs accepting.
acceptCurrent :: Action () -> Action ()
acceptCurrent h = do
  targeting <- gets (ctargeting . scursor)
  if targeting
    then endTargeting True
    else h  -- nothing to accept right now

moveCursor :: Dir -> Int -> Action ()
moveCursor dir n = do
  lxsize <- gets (lxsize . slevel)
  lysize <- gets (lysize . slevel)
  let upd cursor =
        let boundedShift loc =
              let (sx, sy) = fromLoc lxsize (loc `shift` dir)
                  (bx, by) = (max 1 $ min sx (lxsize - 2),
                              max 1 $ min sy (lysize - 2))
              in toLoc lxsize (bx, by)
            cloc = iterate boundedShift (clocation cursor) !! n
        in cursor{ clocation = cloc }
  modify (updateCursor upd)
  doLook

-- TODO: Think about doing the mode dispatch elsewhere, especially if over
-- time more and more commands need to do the dispatch inside their code
-- (currently only a couple do).
move :: Dir -> Action ()
move dir = do
  pl <- gets splayer
  targeting <- gets (ctargeting . scursor)
  if targeting then moveCursor dir 1 else moveOrAttack True True pl dir

run :: Dir -> Action ()
run dir = do
  pl <- gets splayer
  targeting <- gets (ctargeting . scursor)
  if targeting
    then moveCursor dir 10
    else do
      updatePlayerBody (\ p -> p { bdir = Just dir })
      -- attacks and opening doors disallowed while running
      moveOrAttack False False pl dir

-- | This function implements the actual "logic" of running. It checks if we
-- have to stop running because something interested happened, and it checks
-- if we have to adjust the direction because we're in the corner of a corridor.
continueRun :: Dir -> Action ()
continueRun dir =
  do
    loc <- gets (bloc . getPlayerBody)
    per <- currentPerception
    msg <- currentMessage
    ms  <- gets (lmonsters . slevel)
    hs  <- gets (lheroes . slevel)
    lxsize <- gets (lxsize . slevel)
    lvl <- gets slevel
    pl  <- gets splayer
    let dms = case pl of
                AMonster n -> IM.delete n ms  -- don't be afraid of yourself
                AHero _ -> ms
        mslocs = S.fromList (L.map bloc (IM.elems dms))
        monstersVisible = not (S.null (mslocs `S.intersection` ptvisible per))
        newsReported    = not (L.null msg)
        tile      = lvl `rememberAt` loc  -- tile at current location
        itemsHere = not (L.null (lvl `irememberAt` loc))
        heroThere = (loc `shift` dir) `elem` L.map bloc (IM.elems hs)
        dirOK     = accessible lvl loc (loc `shift` dir)
        isTExit   = Tile.isExit tile
        isWalkableDark = Tile.isWalkable tile && not (Tile.isLit tile)
    -- What happens next is mostly depending on the terrain we're currently on.
    let hop | (monstersVisible || heroThere || newsReported ||
               itemsHere || isTExit) = abort
            | isWalkableDark =
          -- in corridors, explore all corners and stop at all crossings
          -- TODO: even in corridors, stop if you run past an exit (rare)
          let ns = L.filter (\ x -> dirDistSq lxsize (neg dir) x > 1
                                    && (accessible lvl loc (loc `shift` x))
                                        || openable lvl (Tile.SecretStrength 1) (loc `shift` x))
                            (moves lxsize)
              allCloseTo main = L.all (\ d -> dirDistSq lxsize main d <= 1) ns
          in  case ns of
                [onlyDir] -> run onlyDir  -- can be diagonal
                _         ->
                  -- prefer orthogonal to diagonal dirs, for hero's safety
                  case L.filter (not . diagonal lxsize) ns of
                    [ortoDir]
                      | allCloseTo ortoDir -> run ortoDir
                    _ -> abort
            | not dirOK =
          abort -- outside corridors never change direction
            | otherwise =
          let ns = L.filter (\ x -> x /= dir && dirDistSq lxsize (neg dir) x > 1) (moves lxsize)
              ls = L.map (loc `shift`) ns
              as = L.filter (\ x -> accessible lvl loc x
                                    || openable lvl (Tile.SecretStrength 1) x) ls
              ts = L.map (lvl `rememberAt`) as
          in if L.any Tile.isExit ts then abort else run dir
    hop

ifRunning :: (Dir -> Action a) -> Action a -> Action a
ifRunning t e =
  do
    ad <- gets (bdir . getPlayerBody)
    maybe e t ad

-- | Update player memory.
remember :: Action ()
remember =
  do
    per <- currentPerception
    lvl <- gets slevel
    let vis = S.toList (ptvisible per)
    let rememberTile = [(loc, lvl `at` loc) | loc <- vis]
    modify (updateLevel (updateLRMap (Kind.// rememberTile)))
    let alt Nothing      = Nothing
        alt (Just ([], _)) = Nothing
        alt (Just (t, _))  = Just (t, t)
        rememberItem = IM.alter alt
    modify (updateLevel (updateIMap (\ m -> L.foldr rememberItem m vis)))

-- | Ask for a direction and close the door, if any
closeDoor :: Action ()
closeDoor = do
  messageReset "direction?"
  display
  e <- session nextCommand
  lxsize <- gets (lxsize . slevel)
  K.handleDirection lxsize e playerCloseDoor (neverMind True)

-- | Player closes a door. AI never does.
playerCloseDoor :: Dir -> Action ()
playerCloseDoor dir = do
  state <- get
  lvl   <- gets slevel
  pl    <- gets splayer
  body  <- gets (getActor pl)
  let hms = levelHeroList state ++ levelMonsterList state
      dloc = shift (bloc body) dir  -- the location we act upon
      t = lvl `at` dloc
  if Tile.hasFeature F.Closable t
    then
      case lvl `iat` dloc of
        [] ->
          if unoccupied hms dloc
          then let adj = (Kind.// [(dloc, Tile.doorClosedId)])
               in modify (updateLevel (updateLMap adj))
          else abortWith "blocked"  -- by monsters or heroes
        _:_ -> abortWith "jammed"  -- by items
    else if Tile.hasFeature F.Openable t
         then abortWith "already closed"
         else neverMind True  -- no visible doors (can be secret)
  advanceTime pl

-- | An actor closes a door. Player (hero or monster) or enemy.
actorOpenDoor :: ActorId -> Dir -> Action ()
actorOpenDoor actor dir = do
  lvl  <- gets slevel
  pl   <- gets splayer
  body <- gets (getActor actor)
  let dloc = shift (bloc body) dir  -- the location we act upon
      t = lvl `at` dloc
      isPlayer = actor == pl
      isVerbose = isPlayer  -- don't report enemy failures, if it's not player
      iq = aiq $ Kind.getKind $ bkind body
      openPower = Tile.SecretStrength $
        if isPlayer
        then 1  -- player can't open secret doors
        else case strongestItem (bitems body) "ring" of  -- TODO: hack
               Just i  -> iq + jpower i
               Nothing -> iq
  unless (openable lvl openPower dloc) $ neverMind isVerbose
  if Tile.hasFeature F.Closable t
    then abortIfWith isVerbose "already open"
    else if not (Tile.hasFeature F.Closable t ||
                 Tile.hasFeature F.Openable t ||
                 Tile.hasFeature F.Hidden t)
         then neverMind isVerbose  -- not doors at all
         else
           let adj = (Kind.// [(dloc, Tile.doorOpenId)])
           in  modify (updateLevel (updateLMap adj))
  advanceTime actor

-- | Attempt a level switch to k levels shallower.
-- TODO: perhaps set up some level name arithmetics in Level.hs
-- and hide there the fact levels are now essentially Ints.
lvlAscend :: Int -> Action ()
lvlAscend k =
  do
    slid   <- gets slid
    config <- gets sconfig
    let n = levelNumber slid
        nln = n - k
        depth = Config.get config "dungeon" "depth"
    when (nln < 1 || nln > depth) $
      abortWith "no more levels in this direction"
    modify (\ state -> state{slid = (LambdaCave nln)})

-- | Attempt a level change via up level and down level keys.
-- Will quit the game if the player leaves the dungeon.
lvlGoUp :: Bool -> Action ()
lvlGoUp isUp =
  do
    cursor    <- gets scursor
    targeting <- gets (ctargeting . scursor)
    pbody     <- gets getPlayerBody
    pl        <- gets splayer
    slid      <- gets slid
    lvl       <- gets slevel
    st        <- get
    let loc = if targeting then clocation cursor else bloc pbody
        tile = lvl `at` loc
        vdir = if isUp then 1 else -1
        sdir | Tile.hasFeature F.Climbable tile = Just 1
             | Tile.hasFeature F.Descendable tile = Just (-1)
             | otherwise = Nothing
    case sdir of
      Just vdir'
        | vdir == vdir' -> -- stairs are in the right direction
          case whereTo st loc of
            Nothing ->
              -- we are at the "end" of the dungeon
              if targeting
              then abortWith "cannot escape dungeon in targeting mode"
              else do
                b <- messageYesNo "Really escape the dungeon?"
                if b
                  then fleeDungeon
                  else abortWith "Game resumed."
            Just (nln, nloc) ->
              if targeting
                then do
                  assert (nln /= slid `blame` (nln, "stairs looped")) $
                    modify (\ state -> state{slid = nln})
                  -- do not freely reveal the other end of the stairs
                  lvl2 <- gets slevel
                  let upd cur =
                        let clocation =
                              if Tile.isUnknown (lvl2 `rememberAt` nloc)
                              then loc
                              else nloc
                        in  cur { clocation, clocLn = nln }
                  modify (updateCursor upd)
                  doLook
                else tryWith (abortWith "somebody blocks the staircase") $ do
                  -- Remove the player from the old level.
                  modify (deleteActor pl)
                  hs <- gets levelHeroList
                  -- Monsters hear that players not on the level. Cancel smell.
                  -- Reduces memory load and savefile size.
                  when (L.null hs) $
                    modify (updateLevel (updateSmell (const IM.empty)))
                  -- At this place the invariant that the player exists fails.
                  -- Change to the new level (invariant not needed).
                  assert (nln /= slid `blame` (nln, "stairs looped")) $
                    modify (\ state -> state{slid = nln})
                  -- Add the player to the new level.
                  modify (insertActor pl pbody)
                  -- At this place the invariant is restored again.
                  -- Land the player at the other end of the stairs.
                  updatePlayerBody (\ p -> p { bloc = nloc })
                  -- Change the level of the player recorded in cursor.
                  modify (updateCursor (\ c -> c { creturnLn = nln }))
                  -- Bail out if anybody blocks the staircase.
                  inhabitants <- gets (locToActors nloc)
                  when (length inhabitants > 1) abort
                  -- The invariant "at most one actor on a tile" restored.
                  -- Create a backup of the savegame.
                  state <- get
                  liftIO $ do
                    Save.saveGame state
                    Save.mvBkp (sconfig state)
                  playerAdvanceTime
      _ -> -- no stairs in the right direction
        if targeting
        then do
          lvlAscend vdir
          let upd cur = cur {clocLn = slid}
          modify (updateCursor upd)
          doLook
        else
          let txt = if isUp then "up" else "down"
          in  abortWith ("no stairs " ++ txt)

-- | Hero has left the dungeon.
fleeDungeon :: Action ()
fleeDungeon =
  do
    state <- get
    let total = calculateTotal state
        items = L.concatMap bitems (levelHeroList state)
    if total == 0
      then do
             go <- messageClear >> messageMoreConfirm ColorFull "Coward!"
             when go $
               messageMore "Next time try to grab some loot before escape!"
             end
      else do
             let winMsg = "Congratulations, you won! Your loot, worth " ++
                          show total ++ " gold, is:"
             displayItems winMsg True items
             go <- session getConfirm
             when go $ do
               go2 <- handleScores True H.Victor total
               when go2 $ messageMore "Can it be done better, though?"
             end

-- | Switches current hero to the next hero on the level, if any, wrapping.
cycleHero :: Action ()
cycleHero =
  do
    pl <- gets splayer
    hs <- gets (lheroes . slevel)
    let i        = case pl of AHero n -> n ; _ -> -1
        (lt, gt) = IM.split i hs
    case IM.keys gt ++ IM.keys lt of
      [] -> abortWith "Cannot select another hero on this level."
      ni : _ -> selectPlayer (AHero ni)
                  >>= assert `trueM` (pl, ni, "hero duplicated")

-- | Search for secret doors
search :: Action ()
search =
  do
    lm     <- gets (lmap . slevel)
    le     <- gets (lsecret . slevel)
    lxsize <- gets (lxsize . slevel)
    ploc   <- gets (bloc . getPlayerBody)
    pitems <- gets (bitems . getPlayerBody)
    let delta = case strongestItem pitems "ring" of
                  Just i  -> 1 + jpower i
                  Nothing -> 1
        searchTile loc (slm, sle) =
          let t = lm Kind.! loc
              k = Tile.secretStrength (le IM.! loc) - delta
          in if Tile.hasFeature F.Hidden t
             then if k > 0
                  then (slm,
                        IM.insert loc (Tile.SecretStrength k) sle)
                  else ((loc, Tile.doorClosedId) : slm,
                        IM.delete loc sle)
             else (slm, sle)
        f (slm, sle) m = searchTile (shift ploc m) (slm, sle)
        (lmDiff, lemap) = L.foldl' f ([], le) (moves lxsize)
        lmNew = if L.null lmDiff then lm else lm Kind.// lmDiff
    modify (updateLevel (\ l -> l{lmap = lmNew, lsecret = lemap}))
    playerAdvanceTime

-- | Start the floor targeting mode or reset the cursor location to the player.
targetFloor :: Action ()
targetFloor = do
  ploc      <- gets (bloc . getPlayerBody)
  target    <- gets (btarget . getPlayerBody)
  targeting <- gets (ctargeting . scursor)
  let tgt = case target of
              _ | targeting -> TLoc ploc  -- double key press: reset cursor
              TEnemy _ _ -> TCursor  -- forget enemy target, keep the cursor
              t -> t  -- keep the target from previous targeting session
  updatePlayerBody (\ p -> p { btarget = tgt })
  setCursor

-- | Start the monster targeting mode. Cycle between monster targets.
-- TODO: also target a monster by moving the cursor, if in target monster mode.
-- TODO: sort monsters by distance to the player.
targetMonster :: Action ()
targetMonster = do
  pl        <- gets splayer
  ms        <- gets (lmonsters . slevel)
  per       <- currentPerception
  target    <- gets (btarget . getPlayerBody)
  targeting <- gets (ctargeting . scursor)
  let i = case target of
            TEnemy (AMonster n) _ | targeting -> n  -- try next monster
            TEnemy (AMonster n) _ -> n - 1  -- try to retarget old monster
            _ -> -1  -- try to target first monster (e.g., number 0)
      dms = case pl of
              AMonster n -> IM.delete n ms  -- don't target yourself
              AHero _ -> ms
      (lt, gt) = IM.split i dms
      gtlt     = IM.assocs gt ++ IM.assocs lt
      lf = L.filter (\ (_, m) -> actorSeesLoc pl (bloc m) per (Just pl)) gtlt
      tgt = case lf of
              [] -> target  -- no monsters in sight, stick to last target
              (na, nm) : _ -> TEnemy (AMonster na) (bloc nm)  -- pick the next
  updatePlayerBody (\ p -> p { btarget = tgt })
  setCursor

-- | Set, activate and display cursor information.
setCursor :: Action ()
setCursor = do
  state <- get
  per   <- currentPerception
  ploc  <- gets (bloc . getPlayerBody)
  clocLn <- gets slid
  let upd cursor =
        let clocation = fromMaybe ploc (targetToLoc (ptvisible per) state)
        in cursor { ctargeting = True, clocation, clocLn }
  modify (updateCursor upd)
  doLook

-- | Perform look around in the current location of the cursor.
-- TODO: depending on tgt, show extra info about tile or monster or both
doLook :: Action ()
doLook =
  do
    loc    <- gets (clocation . scursor)
    state  <- get
    lvl    <- gets slevel
    per    <- currentPerception
    target <- gets (btarget . getPlayerBody)
    let canSee = S.member loc (ptvisible per)
        monsterMsg =
          if canSee
          then case L.find (\ m -> bloc m == loc) (levelMonsterList state) of
                 Just m  -> subjectActor m ++ " is here. "
                 Nothing -> ""
          else ""
        mode = case target of
                 TEnemy _ _ -> "[targeting monster] "
                 TLoc _     -> "[targeting location] "
                 TCursor    -> "[targeting current] "
        -- general info about current loc
        lookMsg = mode ++ lookAt True canSee state lvl loc monsterMsg
        -- check if there's something lying around at current loc
        is = lvl `irememberAt` loc
    if length is <= 2
      then do
             messageAdd lookMsg
      else do
             displayItems lookMsg False is
             session getConfirm
             messageAdd ""

-- | This function performs a move (or attack) by any actor,
-- i.e., it can handle monsters, heroes and both.
moveOrAttack :: Bool ->        -- allow attacks?
                Bool ->        -- auto-open doors on move
                ActorId ->     -- who's moving?
                Dir ->
                Action ()
moveOrAttack allowAttacks autoOpen actor dir = do
      -- We start by looking at the target position.
      state <- get
      pl    <- gets splayer
      lvl   <- gets slevel
      sm    <- gets (getActor actor)
      let sloc = bloc sm           -- source location
          tloc = sloc `shift` dir  -- target location
      tgt <- gets (locToActor tloc)
      case tgt of
        Just target
          | allowAttacks ->
              -- Attacking does not require full access, adjacency is enough.
              actorAttackActor actor target
          | accessible lvl sloc tloc -> do
              -- Switching positions requires full access.
              actorRunActor actor target
              when (actor == pl) $
                messageAdd $ lookAt False True state lvl tloc ""
          | otherwise -> abortWith ""
        Nothing
          | accessible lvl sloc tloc -> do
              -- perform the move
              updateAnyActor actor $ \ body -> body {bloc = tloc}
              when (actor == pl) $
                messageAdd $ lookAt False True state lvl tloc ""
              advanceTime actor
          | allowAttacks && actor == pl
            && Tile.canBeSecretDoor (lvl `rememberAt` tloc)
            -> do
              messageAdd "You search your surroundings."  -- TODO: proper msg
              search
          | autoOpen -> actorOpenDoor actor dir  -- try to open a door
          | otherwise -> abortWith ""

-- | Resolves the result of an actor moving into another. Usually this
-- involves melee attack, but with two heroes it just changes focus.
-- Actors on blocked locations can be attacked without any restrictions.
-- For instance, an actor capable of moving through walls
-- can be attacked from an adjacent position.
-- This function is analogous to zapGroupItem, but for melee
-- and not using up the weapon.
actorAttackActor :: ActorId -> ActorId -> Action ()
actorAttackActor source@(AHero _) target@(AHero _) =
  -- Select adjacent hero by bumping into him. Takes no time.
  selectPlayer target
    >>= assert `trueM` (source, target, "player bumps into himself")
actorAttackActor source target = do
  state <- get
  sm    <- gets (getActor source)
  tm    <- gets (getActor target)
  per   <- currentPerception
  let groupName = "sword"
      verb = attackToVerb groupName
      sloc = bloc sm
      -- The hand-to-hand "weapon", equivalent to +0 sword.
      h2h = Item fistKindId 0 Nothing 1
      str = strongestItem (bitems sm) groupName
      stack  = fromMaybe h2h str
      single = stack { jcount = 1 }
      -- The message describes the source part of the action.
      -- TODO: right now it also describes the victim and weapon;
      -- perhaps, when a weapon is equipped, just say "you hit" or "you miss"
      -- and then "nose dies" or "nose yells in pain".
      msg = subjectVerbMObject sm verb tm $
              if isJust str then " with " ++ objectItem state single else ""
  when (sloc `S.member` ptvisible per) $ messageAdd msg
  -- Messages inside itemEffectAction describe the target part.
  itemEffectAction 0 source target single
  advanceTime source

attackToVerb :: String -> String
attackToVerb "sword" = "hit"  -- TODO: "slash"? "pierce"? "swing"?
attackToVerb "mace" = "bludgeon"
attackToVerb _ = "hit"

-- | Resolves the result of an actor running into another.
-- This involves switching positions of the two actors.
actorRunActor :: ActorId -> ActorId -> Action ()
actorRunActor source target = do
  pl   <- gets splayer
  sloc <- gets (bloc . getActor source)  -- source location
  tloc <- gets (bloc . getActor target)  -- target location
  updateAnyActor source $ \ m -> m { bloc = tloc }
  updateAnyActor target $ \ m -> m { bloc = sloc }
  if source == pl
    then stopRunning  -- do not switch positions repeatedly
    else when (isAMonster source) $ focusIfAHero target
  advanceTime source

-- | Generate a monster, possibly.
generateMonster :: Action ()
generateMonster = do
  state  <- get
  nstate <- rndToAction $ rollMonster state
  srandom <- gets srandom
  put $ nstate{srandom}

-- | Possibly regenerate HP for all actors on the current level.
regenerateLevelHP :: Action ()
regenerateLevelHP =
  do
    time <- gets stime
    let upd m =
          let ak = Kind.getKind $ bkind m
              regen = aregen ak `div`
                      case strongestItem (bitems m) "amulet" of
                        Just i  -> jpower i
                        Nothing -> 1
          in if time `mod` regen /= 0
             then m
             else addHp 1 m
    -- We really want hero selection to be a purely UI distinction,
    -- so all heroes need to regenerate, not just the player.
    -- Only the heroes on the current level regenerate (others are frozen
    -- in time together with their level). This prevents cheating
    -- via sending one hero to a safe level and waiting there.
    modify (updateLevel (updateHeroes   (IM.map upd)))
    modify (updateLevel (updateMonsters (IM.map upd)))