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
-- (todo)
--
-----------------------------------------------------------------------------
module Domain.RelationAlgebra.Exercises where

import Domain.RelationAlgebra.Formula
import Domain.RelationAlgebra.Generator
import Domain.RelationAlgebra.Strategies
import Domain.RelationAlgebra.Rules
import Domain.RelationAlgebra.Parser
import Common.Transformation
import Common.Exercise
import Common.Context
import Control.Monad
import Test.QuickCheck

cnfExercise :: Exercise (Context RelAlg)
cnfExercise = makeExercise
   { shortTitle = "To conjunctive normal form"
   , parser        = \s -> case parseRelAlg s of
                              (p, [])   -> Right (inContext p)
                              (p, msgs) -> Left  (text (show msgs))
   , prettyPrinter = ppRelAlg . fromContext
--   , equivalence = \x y -> apply toCNF (inContext $ noContext x) == apply toCNF (inContext $ noContext y)
   , ruleset   = map liftRuleToContext relAlgRules
   , strategy  = toCNF
   , generator = liftM inContext arbitrary
   , suitableTerm = not . isCNF . fromContext
   }