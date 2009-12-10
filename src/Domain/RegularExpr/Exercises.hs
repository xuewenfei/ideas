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
-----------------------------------------------------------------------------
module Domain.RegularExpr.Exercises (regexpExercise) where

import Common.Exercise
import Common.Traversable
import Common.Rewriting hiding (difference)
import Domain.RegularExpr.Expr
import Domain.RegularExpr.Parser
import Domain.RegularExpr.Strategy
import Domain.RegularExpr.Definitions
import Data.List
import Control.Monad
import System.Random
import Test.QuickCheck

regexpExercise :: Exercise RegExp
regexpExercise = makeExercise
   { description    = "Rewrite a regular expression"
   , exerciseCode   = makeCode "regexp" "normalform"
   , status         = Provisional
   , parser         = parseRegExp
   , prettyPrinter  = ppRegExp
   , equivalence    = eqRE
   , similarity     = equalWith operators -- modulo associativity
   , isReady        = deterministic
   , isSuitable     = (>1) . length . crush
   , difference     = differenceMode eqRE
   , strategy       = deterministicStrategy
--   , extraRules     :: [Rule (Context a)]  -- Extra rules (possibly buggy) not appearing in strategy
   , testGenerator  = Just arbitrary
   , randomExercise = simpleGenerator myGen
   , examples       = generate 5 (mkStdGen 2805) (replicateM 50 myGen)
   }

   
testje = printDerivation regexpExercise $ ex2

Right ex1 = parseRegExp "ABABAB|AB|T|ABAB"
Right ex2 = parseRegExp "A|A|B|A"
Right ex3 = parseRegExp "T+cc|d*F?"

myGen :: Gen RegExp
myGen = restrictGenerator (isSuitable regexpExercise) arbitrary

-- equivalence of regular expressions
eqRE :: Eq a => RE a -> RE a -> Bool
eqRE = (==)

{-
checkUntil :: Ord a => Int -> RE a -> RE a -> Bool
checkUntil n r s = empty r == empty s && (n==0 || next)
 where
   make = groupBy eqFst . sortBy cmpFst . firsts
   eqFst  (a, _) (b, _) = a==b 
   cmpFst (a, _) (b, _) = compare a b
   
   as = make r
   bs = make s
   next = and ((length as == length bs) : zipWith f as bs)
   
   -- f ((a, _):
   f _ _ = False -}