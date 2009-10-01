-----------------------------------------------------------------------------
-- Copyright 2009, Open Universiteit Nederland. This file is distributed 
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
     Exercise, Status(..), testableExercise, makeExercise, emptyExercise
   , description, exerciseCode, status, parser, prettyPrinter
   , equivalence, similarity, isReady, isSuitable, strategy, extraRules, differences
   , ordering, testGenerator, randomExercise, examples, getRule
   , simpleGenerator, useGenerator
   , randomTerm, randomTermWith, ruleset
     -- * Exercise codes
   , ExerciseCode, noCode, makeCode, readCode, domain, identifier
     -- * Miscellaneous
   , restrictGenerator
   , showDerivation, showDerivationWith, showDerivations, printDerivation, printDerivations
   , checkExercise, checkParserPretty
   , checksForList
   ) where

import Common.Apply
import Common.Context
import Common.Rewriting (TreeDiff(..))
import Common.Strategy hiding (not, fail, replicate)
import Common.Transformation
import Common.Utils
import Control.Monad.Error
import Data.Char
import Data.List
import System.Random
import Test.QuickCheck hiding (label, arguments)
import Text.Parsing (SyntaxError(..))

data Exercise a = Exercise
   { -- identification and meta-information
     description    :: String       -- short sentence describing the task
   , exerciseCode   :: ExerciseCode -- uniquely determines the exercise (in a given domain)
   , status         :: Status
     -- parsing and pretty-printing
   , parser         :: String -> Either SyntaxError a
   , prettyPrinter  :: a -> String
     -- syntactic and semantic checks
   , equivalence    :: a -> a -> Bool
   , similarity     :: a -> a -> Bool      -- possibly more liberal than syntactic equality
   , ordering       :: a -> a -> Ordering  -- syntactic comparison
   , isReady        :: a -> Bool
   , isSuitable     :: a -> Bool
     -- strategies and rules
   , strategy       :: LabeledStrategy (Context a)
   , extraRules     :: [Rule (Context a)]  -- Extra rules (possibly buggy) not appearing in strategy
   , differences    :: a -> a -> [([Int], TreeDiff)]
     -- testing and exercise generation
   , testGenerator  :: Maybe (Gen a)
   , randomExercise :: Maybe (StdGen -> a)
   , examples       :: [a]
   }
   
data Status = Stable | Provisional | Experimental deriving (Show, Eq)

instance Eq (Exercise a) where
   e1 == e2 = exerciseCode e1 == exerciseCode e2

instance Ord (Exercise a) where
   e1 `compare` e2 = exerciseCode e1 `compare` exerciseCode e2

instance Apply Exercise where
   applyAll e = map fromContext . applyAll (strategy e) . inContext

testableExercise :: (Arbitrary a, Show a, Ord a) => Exercise a
testableExercise = makeExercise
   { testGenerator = Just arbitrary
   }

makeExercise :: (Show a, Ord a) => Exercise a
makeExercise = emptyExercise
   { prettyPrinter = show
   , similarity    = (==)
   , ordering      = compare
   }
   
emptyExercise :: Exercise a
emptyExercise = Exercise 
   { -- identification and meta-information
     description    = "<<description>>" 
   , exerciseCode   = noCode
   , status         = Experimental
     -- parsing and pretty-printing
   , parser         = const $ Left $ ErrorMessage "<<no parser>>"
   , prettyPrinter  = const "<<no pretty-printer>>"
     -- syntactic and semantic checks
   , equivalence    = \_ _ -> True
   , similarity     = \_ _ -> True
   , ordering       = \_ _ -> EQ
   , isReady        = const True
   , isSuitable     = const True
     -- strategies and rules
   , strategy       = label "Succeed" succeed
   , extraRules     = [] 
   , differences    = \_ _ -> [([], Different)]
     -- testing and exercise generation
   , testGenerator  = Nothing
   , randomExercise = Nothing
   , examples       = []
   }

---------------------------------------------------------------
-- Exercise generators

-- returns a sorted list of rules (no duplicates)
ruleset :: Exercise a -> [Rule (Context a)]
ruleset ex = nub (sortBy cmp list)
 where 
   list = rulesInStrategy (strategy ex) ++ extraRules ex
   cmp a b = name a `compare` name b
 
simpleGenerator :: Gen a -> Maybe (StdGen -> a) 
simpleGenerator = useGenerator (const True)

useGenerator :: (a -> Bool) -> Gen a -> Maybe (StdGen -> a) 
useGenerator p g = Just f
 where
   f rng | p a       = a
         | otherwise = f (snd (next rng))
    where
      a = generate 100 rng g 

restrictGenerator :: (a -> Bool) -> Gen a -> Gen a
restrictGenerator p g = do
   a <- g 
   if p a then return a 
          else restrictGenerator p g

randomTerm :: Exercise a -> IO a
randomTerm ex = do
   rng <- newStdGen
   return (randomTermWith rng ex)

randomTermWith :: StdGen -> Exercise a -> a
randomTermWith rng ex = 
   case randomExercise ex of
      Just f  -> f rng
      Nothing
         | null xs   -> error "randomTermWith: no generator" 
         | otherwise -> 
              xs !! fst (randomR (0, length xs - 1) rng)
       where xs = examples ex

---------------------------------------------------------------
-- Exercise codes (unique identification)

data ExerciseCode = EC String String | NoCode
   deriving (Eq, Ord)

instance Show ExerciseCode where
   show (EC xs ys) = xs ++ "." ++ ys
   show NoCode     = "no code"

noCode :: ExerciseCode
noCode = NoCode

makeCode :: String -> String -> ExerciseCode
makeCode a b
   | null a || null b || any (not . isAlphaNum) (a++b) =
        error $ "Invalid exercise code: " ++ show (EC a b)
   | otherwise = 
        EC (map toLower a) (map toLower b)
   
readCode :: String -> Maybe ExerciseCode
readCode xs =
   case break (not . isAlphaNum) xs of
      (as, '.':bs) | all isAlphaNum bs -> 
         return $ makeCode as bs
      _ -> Nothing

domain :: ExerciseCode -> String
domain (EC s _) = s
domain _        = []

identifier :: ExerciseCode -> String
identifier (EC _ s) = s
identifier _        = []




            
getRule :: Monad m => Exercise a -> String -> m (Rule (Context a))
getRule ex s = 
   case filter ((==s) . name) (ruleset ex) of 
      [hd] -> return hd
      []   -> fail $ "Could not find ruleid " ++ s
      _    -> fail $ "Ambiguous ruleid " ++ s

showDerivations :: Exercise a -> [a] -> String
showDerivations ex xs = unlines (zipWith f [1..] xs)
 where
   f i x = unlines
      [ replicate 50 '-'
      , "-- Exercise " ++ show i ++ "\n"
      , showDerivation ex x
      ]

showDerivation :: Exercise a -> a -> String
showDerivation ex = showDerivationWith (prettyPrinter ex) (unlabel (strategy ex))

showDerivationWith :: (a -> String) -> Strategy (Context a) -> a -> String
showDerivationWith showf s start = unlines $ 
   case derivations s (inContext start) of 
      [] -> [f (inContext start), "    => no derivation"]
      (a, xs):_ -> f a : concatMap g xs
 where
   f a = "  " ++ showf (fromContext a)
   g (r, a)
      | isMinorRule r = []
      | otherwise =  ["    => " ++ show r, f a]
         
printDerivations :: Exercise a -> [a] -> IO ()
printDerivations ex = putStrLn . showDerivations ex

printDerivation :: Exercise a -> a -> IO ()
printDerivation ex = putStrLn . showDerivation ex
         
---------------------------------------------------------------
-- Checks for an exercise

-- | An instance of the Arbitrary type class is required because the random
-- | term generator that is part of an Exercise is not used for the checks:
-- | the terms produced by this generator will typically be biased.

checkExercise :: (Arbitrary a, Show a) => Exercise a -> IO ()
checkExercise = checkExerciseWith g 
 where g eq = checkRuleSmart $ \x y -> fromContext x `eq` fromContext y

checkExerciseWith :: (Arbitrary a, Show a) => ((a -> a -> Bool) -> Rule (Context a) -> IO b) -> Exercise a -> IO ()
checkExerciseWith f a = do 
   putStrLn ("** " ++ show (exerciseCode a))
   let check txt p = putLabel txt >> quickCheck p
   check "parser/pretty printer" $ 
      checkParserPretty (equivalence a) (parser a) (prettyPrinter a)
--   check "equality relation" $ 
--      checkEquivalence (ruleset a) (equality a) 
--   check "equivalence relation" $ 
--      checkEquivalence (ruleset a) (equivalence a)
--   check "equality/equivalence" $ \x -> 
--      forAll (similar (ruleset a) x) $ \y ->
--      equality a x y ==> equivalence a x y
   putStrLn "Soundness non-buggy rules" 
   forM_ (filter (not . isBuggyRule) $ ruleset a) $ \r -> 
      putLabel ("    " ++ name r) >> f (equivalence a) r
   
   case testGenerator a of 
      Nothing -> return ()
      Just g -> do
         check "non-trivial terms" $ 
            forAll g $ \x -> 
            let trivial  = isReady a x
                rejected = not trivial
                suitable = not trivial in
            classify trivial  "trivial"  $
            classify rejected "rejected" $
            classify suitable "suitable" $ property True 
         check "soundness strategy/generator" $ 
            forAll g $
               isReady a . fromContext . applyD (strategy a) . inContext

-- check combination of parser and pretty-printer
checkParserPretty :: (a -> a -> Bool) -> (String -> Either b a) -> (a -> String) -> a -> Bool
checkParserPretty eq parser pretty p = 
   either (const False) (eq p) (parser (pretty p))

{-
checkEquivalence :: (Arbitrary a, Show a) => [Rule (Context a)] -> (a -> a -> Bool) -> a -> Property
checkEquivalence rs eq x =
   forAll (similar rs x) $ \y ->
   forAll (similar rs y) $ \z ->
      eq x x && (eq x y == eq y x) && (if eq x y && eq y z then eq x z else True) 
   
similar :: Arbitrary a => [Rule (Context a)] -> a -> Gen a
similar rs a =
   let new = a : [ fromContext cb | r <- rs, cb <- applyAll r (inContext a) ]
   in oneof [arbitrary, oneof $ map return new] -}

checksForList :: Exercise a -> IO ()
checksForList ex
   | status ex /= Experimental || null xs = return ()
   | otherwise = do
         let err s = putStrLn $ "Error: " ++ s
         putStrLn ("** " ++ show (exerciseCode ex))
         mapM_ (either err return . checksForTerm ex) xs
 where xs = examples ex

checksForTerm :: Monad m => Exercise a -> a -> m ()
checksForTerm ex a = 
   let txt = prettyPrinter ex a in
   case derivations (unlabel $ strategy ex) (inContext a) of
      [] -> fail $ "no derivation for " ++ txt
      (_, xs):_ -> do
         unless (isReady ex (last as)) $
            fail $ "not solved: " ++ txt
         case [ (x, y) | x <- as, y <- as, not (equivalence ex x y) ] of
            (x, y):_ -> fail $ "not equivalent: " ++ prettyPrinter ex x ++ "  and  "
                                                  ++ prettyPrinter ex y
            _        -> return ()
         case filter (not . checkParserPretty (similarity ex) (parser ex) (prettyPrinter ex)) as of
            hd:_ -> let s = prettyPrinter ex hd in
                    fail $ "parse error for " ++ s ++ ": parsed as " ++
                           either show (prettyPrinter ex) (parser ex s)
            _    -> return ()
       where
         as = a : map (fromContext . snd) xs