-- TODO: Add an export list, with sections, after the file is rewritten
-- according to #17. Perhaps make some types abstract.
-- | Game action monad and basic building blocks
-- for player and monster actions.
{-# LANGUAGE MultiParamTypeClasses, RankNTypes #-}
module Game.LambdaHack.Action where

import Control.Monad
import Control.Monad.State hiding (State, state)
import qualified Data.IntMap as IM
import qualified Data.Map as M
import Data.Maybe
-- import System.IO (hPutStrLn, stderr) -- just for debugging

import Game.LambdaHack.Perception
import Game.LambdaHack.Display
import Game.LambdaHack.Msg
import Game.LambdaHack.State
import Game.LambdaHack.Level
import Game.LambdaHack.Actor
import Game.LambdaHack.ActorState
import Game.LambdaHack.Content.ActorKind
import qualified Game.LambdaHack.Save as Save
import qualified Game.LambdaHack.Kind as Kind
import Game.LambdaHack.Random
import qualified Game.LambdaHack.Key as K
import Game.LambdaHack.Binding

-- | The constant session information, not saved to the game save file.
data Session = Session
  { sfs   :: FrontendSession         -- ^ frontend session information
  , scops :: Kind.COps               -- ^ game content
  , skeyb :: Binding (Action ())     -- ^ binding of keys to commands
  }

-- | The type of the function inside any action.
-- (Separated from the @Action@ type to document each argument with haddock.)
type ActionFun r a =
   Session                           -- ^ session setup data
   -> (State -> Diary -> IO r)       -- ^ shutdown continuation
   -> Perception                     -- ^ cached perception
   -> (State -> Diary -> a -> IO r)  -- ^ continuation
   -> IO r                           -- ^ failure/reset continuation
   -> State                          -- ^ current state
   -> Diary                          -- ^ current diary
   -> IO r

-- | Actions of player-controlled characters and of any other actors.
newtype Action a = Action
  { runAction :: forall r . ActionFun r a
  }

instance Show (Action a) where
  show _ = "an action"

-- TODO: check if it's strict enough, if we don't keep old states for too long,
-- Perhaps make state type fields strict for that, too?
instance Monad Action where
  return = returnAction
  (>>=)  = bindAction

-- | Invokes the action continuation on the provided argument.
returnAction :: a -> Action a
returnAction x = Action (\ _s _e _p k _a st m -> k st m x)

-- | Distributes the session and shutdown continuation,
-- threads the state and diary.
bindAction :: Action a -> (a -> Action b) -> Action b
bindAction m f = Action (\ s e p k a st ms ->
                          let next nst nm x =
                                runAction (f x) s e p k a nst nm
                          in runAction m s e p next a st ms)

instance MonadIO Action where
  liftIO x = Action (\ _s _e _p k _a st ms -> x >>= k st ms)

instance MonadState State Action where
  get     = Action (\ _s _e _p k _a  st ms -> k st  ms st)
  put nst = Action (\ _s _e _p k _a _st ms -> k nst ms ())

-- | Run an action, with a given session, state and diary, in the @IO@ monad.
handlerToIO :: Session -> State -> Diary -> Action () -> IO ()
handlerToIO sess@Session{sfs, scops} state diary h =
  runAction h
    sess
    (\ ns ndiary -> Save.rmBkpSaveDiary ns ndiary
                 >> shutdown sfs)  -- get out of the game
    (perception scops state)  -- create and cache perception
    (\ _ _ x -> return x)    -- final continuation returns result
    (ioError $ userError "unhandled abort")
    state
    diary

-- | Invoke pseudo-random computation with the generator kept in the state.
rndToAction :: Rnd a -> Action a
rndToAction r = do
  g <- gets srandom
  let (a, ng) = runState r g
  modify (\ state -> state {srandom = ng})
  return a

-- | Invoke a session command.
session :: (Session -> Action a) -> Action a
session f = Action (\ sess e p k a st ms ->
                     runAction (f sess) sess e p k a st ms)

-- | Invoke a session @IO@ command.
sessionIO :: (Session -> IO a) -> Action a
sessionIO f = Action (\ sess _e _p k _a st ms -> f sess >>= k st ms)

-- | Display the current level with modified current msg.
displayGeneric :: ColorMode -> (Msg -> Msg) -> Action Bool
displayGeneric dm f =
  Action (\ Session{sfs, scops} _e p k _a st ms ->
           displayLevel dm sfs scops p st (f (smsg ms)) Nothing
           >>= k st ms)

-- | Display the current level, with the current msg and color.
displayAll :: Action Bool
displayAll = displayGeneric ColorFull id

-- | Display an overlay on top of the current screen.
overlay :: String -> Action Bool
overlay txt =
  Action (\ Session{sfs, scops} _e p k _a st ms ->
           displayLevel ColorFull sfs scops p st (smsg ms) (Just txt)
           >>= k st ms)

-- | Get the current diary.
currentDiary :: Action Diary
currentDiary = Action (\ _s _e _p k _a st diary -> k st diary diary)

-- | Wipe out and set a new value for the current diary.
diaryReset :: Diary -> Action ()
diaryReset ndiary = Action (\ _s _e _p k _a st _diary -> k st ndiary ())

-- | Get the current msg.
currentMsg :: Action Msg
currentMsg = Action (\ _s _e _p k _a st ms -> k st ms (smsg ms))

-- | Wipe out and set a new value for the current msg.
msgReset :: Msg -> Action ()
msgReset nm = Action (\ _s _e _p k _a st ms -> k st ms{smsg = nm} ())

-- | Add to the current msg.
msgAdd :: Msg -> Action ()
msgAdd nm = Action (\ _s _e _p k _a st ms ->
                     k st ms{smsg = addMsg (smsg ms) nm} ())

-- | Clear the current msg.
msgClear :: Action ()
msgClear = Action (\ _s _e _p k _a st ms -> k st ms{smsg = ""} ())

-- | Get the content operations.
contentOps :: Action Kind.COps
contentOps = Action (\ Session{scops} _e _p k _a st ms -> k st ms scops)

-- | Get the content operations modified by a function (usually a selector).
contentf :: (Kind.COps -> a) -> Action a
contentf f = Action (\ Session{scops} _e _p k _a st ms -> k st ms (f scops))

-- | End the game, i.e., invoke the shutdown continuation.
end :: Action ()
end = Action (\ _s e _p _k _a s diary -> e s diary)

-- | Reset the state and resume from the last backup point, i.e., invoke
-- the failure continuation.
abort :: Action a
abort = Action (\ _s _e _p _k a _st _ms -> a)

-- | Set the current exception handler. First argument is the handler,
-- second is the computation the handler scopes over.
tryWith :: Action () -> Action () -> Action ()
tryWith exc h = Action (\ s e p k a st ms ->
                         let runA = runAction exc s e p k a st ms
                         in runAction h s e p k runA st ms)

-- | Take a handler and a computation. If the computation fails, the
-- handler is invoked and then the computation is retried.
tryRepeatedlyWith :: Action () -> Action () -> Action ()
tryRepeatedlyWith exc h = tryWith (exc >> tryRepeatedlyWith exc h) h

-- | Try the given computation and silently catch failure.
try :: Action () -> Action ()
try = tryWith (return ())

-- | Try the given computation until it succeeds without failure.
tryRepeatedly :: Action () -> Action ()
tryRepeatedly = tryRepeatedlyWith (return ())

-- | Debugging.
debug :: String -> Action ()
debug _x = return () -- liftIO $ hPutStrLn stderr _x

-- | Print the given msg, then abort.
abortWith :: Msg -> Action a
abortWith msg = do
  msgReset msg
  displayAll
  abort

-- | Abort, and print the given msg if the condition is true.
abortIfWith :: Bool -> Msg -> Action a
abortIfWith True msg = abortWith msg
abortIfWith False _  = abortWith ""

-- | Abort conditionally, with a fixed message.
neverMind :: Bool -> Action a
neverMind b = abortIfWith b "never mind"

-- | Wait for a player keypress.
nextCommand :: Session -> Action K.Key
nextCommand Session{sfs, skeyb} = do
  nc <- liftIO $ nextEvent sfs
  return $ fromMaybe nc $ M.lookup nc $ kmacro skeyb

-- | A yes-no confirmation.
getYesNo :: Session -> Action Bool
getYesNo sess@Session{sfs} = do
  e <- liftIO $ nextEvent sfs
  case e of
    K.Char 'y' -> return True
    K.Char 'n' -> return False
    K.Esc      -> return False
    _          -> getYesNo sess

-- | Waits for a SPACE or ESC. Passes along any other key, including RET,
-- to an argument function.
getOptionalConfirm :: (Bool -> Action a)
                    -> (K.Key -> Action a)
                    -> Session
                    -> Action a
getOptionalConfirm h k Session{sfs} = do
  e <- liftIO $ nextEvent sfs
  case e of
    K.Char ' ' -> h True
    K.Esc      -> h False
    _          -> k e

-- | Ignore unexpected kestrokes until a SPACE or RET or ESC is pressed.
getConfirm :: Session -> Action Bool
getConfirm Session{sfs} = liftIO $ getConfirmD sfs

-- | Print msg, await confirmation. Return value indicates
-- if the player tried to abort/escape.
msgMoreConfirm :: ColorMode -> Msg -> Action Bool
msgMoreConfirm dm msg = do
  msgAdd (msg ++ more)
  displayGeneric dm id
  session getConfirm

-- | Print msg, await confirmation, ignore confirmation.
msgMore :: Msg -> Action ()
msgMore msg = msgClear >> msgMoreConfirm ColorFull msg >> return ()

-- | Print a yes/no question and return the player's answer.
msgYesNo :: Msg -> Action Bool
msgYesNo msg = do
  msgReset (msg ++ yesno)
  displayGeneric ColorBW id  -- turn player's attention to the choice
  session getYesNo

-- | Print a msg and several overlays, one per page, and await confirmation.
-- The return value indicates if the player tried to abort/escape.
msgOverlaysConfirm :: Msg -> [String] -> Action Bool
msgOverlaysConfirm _msg [] = do
  msgClear
  displayAll
  return True
msgOverlaysConfirm msg (x:xs) = do
  msgReset msg
  b0 <- overlay (x ++ more)
  if b0
    then do
      b <- session getConfirm
      if b
        then msgOverlaysConfirm msg xs
        else stop
    else stop
 where
  stop = do
    msgClear
    displayAll
    return False

-- | Update the cached perception for the given computation.
withPerception :: Action () -> Action ()
withPerception h = Action (\ sess@Session{scops} e _ k a st ms ->
                            runAction h sess e (perception scops st) k a st ms)

-- | Get the current perception.
currentPerception :: Action Perception
currentPerception = Action (\ _s _e p k _a st ms -> k st ms p)

-- | Update actor stats. Works for actors on other levels, too.
updateAnyActor :: ActorId -> (Actor -> Actor) -> Action ()
updateAnyActor actor f = modify (updateAnyActorBody actor f)

-- | Update player-controlled actor stats.
updatePlayerBody :: (Actor -> Actor) -> Action ()
updatePlayerBody f = do
  pl <- gets splayer
  updateAnyActor pl f

-- | Advance the move time for the given actor.
advanceTime :: ActorId -> Action ()
advanceTime actor = do
  Kind.Ops{okind} <- contentf Kind.coactor
  time <- gets stime
  let upd m = m { btime = time + aspeed (okind (bkind m)) }
  -- A hack to synchronize the whole party:
  pl <- gets splayer
  if actor == pl || isAHero actor
    then do
      modify (updateLevel (updateHeroes (IM.map upd)))
      unless (isAHero pl) $ updatePlayerBody upd
    else do
      s <- get
      -- If actor dead or not on current level, don't bother.
      when (memActor actor s) $ updateAnyActor actor upd

-- | Add a turn to the player time counter.
playerAdvanceTime :: Action ()
playerAdvanceTime = do
  pl <- gets splayer
  advanceTime pl

-- | Display command help.
displayHelp :: Action ()
displayHelp = do
  let disp Session{skeyb} = msgOverlaysConfirm "Basic keys:" $ keyHelp skeyb
  session disp
  abort