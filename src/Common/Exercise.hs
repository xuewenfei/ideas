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
-- This module defines the concept of an exercise
--
-----------------------------------------------------------------------------
module Common.Exercise 
   ( -- * Exercises
     Exercise(..), makeExercise, stepsRemaining
     -- * QuickCheck utilities
   , checkExercise, checkParserPretty
   ) where

import Common.Apply
import Common.Context
import Common.Parsing (Range)
import Common.Transformation
import Common.Strategy hiding (not)
import Common.Utils
import Control.Monad
import Test.QuickCheck hiding (label, arguments)

data Exercise a = Exercise
   { shortTitle    :: String
   , parser        :: String -> Either String a
   , subTerm       :: String -> Range -> Maybe Location
   , prettyPrinter :: a -> String
   , equivalence   :: a -> a -> Bool
   , equality      :: a -> a -> Bool -- syntactic equality
   , finalProperty :: a -> Bool
   , ruleset       :: [Rule (Context a)]
   , strategy      :: LabeledStrategy (Context a)
   , generator     :: Gen a
   , suitableTerm  :: a -> Bool
   }

instance Apply Exercise where
   applyAll e a = map fromContext $ applyAll (strategy e) (inContext a)

-- default values for all fields
makeExercise :: (Arbitrary a, Eq a, Show a) => Exercise a
makeExercise = Exercise
   { shortTitle    = "no short title"
   , parser        = const $ Left "no parser"
   , subTerm       = \_ _ -> Nothing
   , prettyPrinter = show
   , equivalence   = (==)
   , equality      = (==)
   , finalProperty = const True
   , ruleset       = []
   , strategy      = label "Succeed" succeed
   , generator     = arbitrary
   , suitableTerm  = const True
   }
  
-- Temporarily. To do: replace this function by a Typed Abstract Service  
stepsRemaining :: Prefix a -> a -> Int
stepsRemaining p0 a = 
   case safeHead (runPrefixLocation [] p0 a) of -- run until the end
      Nothing -> 0
      Just (_, prefix) ->
         length [ () | Step _ r <- drop (length $ prefixToSteps p0) (prefixToSteps prefix), isMajorRule r ] 
         
---------------------------------------------------------------
-- Checks for an exercise

-- | An instance of the Arbitrary type class is required because the random
-- | term generator that is part of an Exercise is not used for the checks:
-- | the terms produced by this generator will typically be biased.

checkExercise :: (Arbitrary a, Show a) => Exercise a -> IO ()
checkExercise = checkExerciseWith g 
 where
   g eq = checkRuleSmart $ \x y -> fromContext x `eq` fromContext y

checkExerciseWith :: (Arbitrary a, Show a) => ((a -> a -> Bool) -> Rule (Context a) -> IO b) -> Exercise a -> IO ()
checkExerciseWith f a = do
   putStrLn ("Checking exercise: " ++ shortTitle a)
   let check txt p = putStr ("- " ++ txt ++ "\n    ") >> quickCheck p
   check "parser/pretty printer" $ 
      checkParserPretty (equivalence a) (parser a) (prettyPrinter a)
   check "equality relation" $ 
      checkEquivalence (ruleset a) (equality a) 
   check "equivalence relation" $ 
      checkEquivalence (ruleset a) (equivalence a)
   check "equality/equivalence" $ \x -> 
      forAll (similar (ruleset a) x) $ \y ->
      equality a x y ==> equivalence a x y
   putStrLn "- Soundness non-buggy rules" 
   flip mapM_ (filter (not . isBuggyRule) $ ruleset a) $ \r -> 
      putStr "    " >> f (equivalence a) r
   check "non-trivial terms" $ 
      forAll (sized $ \_ -> generator a) $ \x -> 
      let trivial  = finalProperty a x
          rejected = not (suitableTerm a x) && not trivial
          suitable = suitableTerm a x && not trivial in
      classify trivial  "trivial"  $
      classify rejected "rejected" $
      classify suitable "suitable" $ property True
   check "soundness strategy/generator" $ 
      forAll (generator a) $ \x -> 
      finalProperty a (fromContext $ applyD (strategy a) (inContext x))
      

-- check combination of parser and pretty-printer
checkParserPretty :: (a -> a -> Bool) -> (String -> Either b a) -> (a -> String) -> a -> Bool
checkParserPretty eq parser pretty p = 
   either (const False) (eq p) (parser (pretty p))
   
checkEquivalence :: (Arbitrary a, Show a) => [Rule (Context a)] -> (a -> a -> Bool) -> a -> Property
checkEquivalence rs eq x =
   forAll (similar rs x) $ \y ->
   forAll (similar rs y) $ \z ->
      eq x x && (eq x y == eq y x) && (if eq x y && eq y z then eq x z else True) 
   
similar :: Arbitrary a => [Rule (Context a)] -> a -> Gen a
similar rs a =
   let new = a : [ fromContext cb | r <- rs, cb <- applyAll r (inContext a) ]
   in oneof [arbitrary, oneof $ map return new]