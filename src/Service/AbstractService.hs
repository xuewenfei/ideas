{-# OPTIONS -XExistentialQuantification #-}
-----------------------------------------------------------------------------
-- Copyright 2008, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-- (...add description...)
--
-----------------------------------------------------------------------------
module Service.AbstractService where

import Common.Utils (safeHead, Some(..))
import Common.Context
import Common.Exercise (Exercise(..))
import Common.Transformation (name, Rule)
import Domain.Logic.FeedbackText (feedbackSyntaxError, ruleText) -- FIXME
import Service.ExerciseList
import Common.Parsing (SyntaxError(..))
import qualified Service.TypedAbstractService as TAS
import Data.Char
import Data.Maybe
import Common.Strategy  (makePrefix)

type ExerciseID = String
type RuleID     = String

type State      = (ExerciseID, Prefix, Expression, SimpleContext)
type Prefix     = String
type Expression = String -- concrete syntax (although this could also be abstract)
type SimpleContext = String

data Result = SyntaxError SyntaxError
            | Buggy [RuleID]   
            | NotEquivalent      
            | Ok [RuleID] State      -- equivalent
            | Detour [RuleID] State  -- equivalent
            | Unknown State          -- equivalent
   deriving Show
          
generate :: ExerciseID -> Int -> IO State
generate exID level = 
   case getExercise exID of
      Some ex -> do
         s <- TAS.generate ex level
         return (toState s)

derivation :: State -> [(RuleID, Location, Expression)]
derivation s = 
   case fromState s of
      Some ts -> 
         let f (r, ca) = (fromMaybe ("rule " ++ name r) (ruleText r), location ca, prettyPrinter (TAS.exercise ts) (fromContext ca))
         in map f (TAS.derivation ts)

allfirsts :: State -> [(RuleID, Location, State)]
allfirsts s = 
   case fromState s of
      Some ts -> 
         let f (r, loc, s) = (name r, loc, toState s)
         in map f (TAS.allfirsts ts)

onefirst :: State -> (RuleID, Location, State)
onefirst = fromMaybe (error "onefirst") . safeHead . allfirsts

onefirsttext :: State -> (Bool, String, State)
onefirsttext s = 
   case fromState s of
      Some ts -> 
         let (b, txt, s) = TAS.onefirsttext ts 
         in (b, txt, toState s)

applicable :: Location -> State -> [RuleID]
applicable loc s = 
   case fromState s of
      Some ts -> map name (TAS.applicable loc ts)

apply :: RuleID -> Location -> State -> State
apply ruleID loc s = 
   case fromState s of
      Some ts -> toState (TAS.apply (getRule ruleID (TAS.exercise ts)) loc ts)

ready :: State -> Bool
ready s = 
   case fromState s of
      Some ts -> TAS.ready ts

stepsremaining :: State -> Int
stepsremaining s = 
   case fromState s of
      Some ts -> TAS.stepsremaining ts

submittext :: State -> Expression -> (Bool, String, State)
submittext s input = 
   case fromState s of
      Some ts -> 
         case parser (TAS.exercise ts) input of
            Left err -> (False, feedbackSyntaxError err, s)
            Right a  ->
               let (b, txt, s) = TAS.submittext ts a
               in (b, txt, toState s)

submit :: State -> Expression -> Result
submit s input = fst $ submitExtra s input

submitExtra :: State -> Expression -> (Result, Int)
submitExtra s input = 
   case fromState s of
      Some ts -> 
         case parser (TAS.exercise ts) input of
            Left err -> (SyntaxError err, 0)
            Right a  ->
               case TAS.submitExtra ts a of
                  (TAS.NotEquivalent, c) -> (NotEquivalent, c)
                  (TAS.Buggy   rs   , c) -> (Buggy   (map name rs), c)
                  (TAS.Ok      rs ns, c) -> (Ok      (map name rs) (toState ns), c)
                  (TAS.Detour  rs ns, c) -> (Detour  (map name rs) (toState ns), c)
                  (TAS.Unknown    ns, c) -> (Unknown               (toState ns), c)

-------------------------

getExercise :: ExerciseID -> Some Exercise
getExercise exID = fromMaybe (error "invalid exercise ID") $ safeHead $ filter p exerciseList
 where p (Some ex) = description ex == exID -- TODO: use exercise code instead

fromState :: State -> Some TAS.State
fromState (exID, p, ce, ctx) =
   case getExercise exID of
      Some ex -> 
         case (parser ex ce, parseContext ctx) of 
            (Right a, Just unit) -> Some TAS.State 
               { TAS.exercise = ex
               , TAS.prefix   = fmap (`makePrefix` strategy ex) (readPrefix p) 
               , TAS.context  = fmap (\_ -> a) unit
               }
            _ -> error "fromState"
      
toState :: TAS.State a -> State
toState state = ( description (TAS.exercise state)
                , maybe "NoPrefix" show (TAS.prefix state)
                , prettyPrinter (TAS.exercise state) (TAS.term state)
                , showContext (TAS.context state)
                ) -- TODO: use exercise code instead

readPrefix :: String -> Maybe [Int]
readPrefix input =
   case reads input of
      [(is, rest)] | all isSpace rest -> return is
      _ -> Nothing

getRule :: RuleID -> Exercise a -> Rule (Context a)
getRule ruleID ex = fromMaybe (error "invalid rule ID") $ safeHead $ 
   filter ((==ruleID) . name) (ruleset ex)
   
getResultState :: Result -> Maybe State
getResultState result =
   case result of
      Ok _ st     -> return st
      Detour _ st -> return st
      Unknown st  -> return st
      _           -> Nothing