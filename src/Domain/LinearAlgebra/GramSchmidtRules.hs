-----------------------------------------------------------------------------
-- Copyright 2011, Open Universiteit Nederland. This file is distributed
-- under the terms of the GNU General Public License. For more information,
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------
module Domain.LinearAlgebra.GramSchmidtRules where

import Common.Library hiding (current)
import Control.Monad
import Data.Maybe
import Domain.LinearAlgebra.Vector

varI, varJ :: Ref Int
varI = makeRef "considered"
varJ = makeRef "j"

getVarI, getVarJ :: Context a -> Int
getVarI = fromMaybe 0 . (varI ?)
getVarJ = fromMaybe 0 . (varJ ?)

rulesGramSchmidt :: (Floating a, Reference a) => [Rule (Context (VectorSpace a))]
rulesGramSchmidt = [ruleNormalize, ruleOrthogonal, ruleNext]

-- Make the current vector of length 1
-- (only applicable if this is not already the case)
ruleNormalize :: Floating a => Rule (Context (VectorSpace a))
ruleNormalize = makeSimpleRuleList "Turn into unit Vector" $ \cvs -> do
   v  <- current cvs
   guard (norm v `notElem` [0, 1])
   new <- setCurrent (toUnit v) cvs
   return (replace new cvs)

-- Make the current vector orthogonal with some other vector
-- that has already been considered
ruleOrthogonal :: (Floating a, Reference a) => Rule (Context (VectorSpace a))
ruleOrthogonal = makeRule "Make orthogonal" $ 
   supplyParameters transOrthogonal args
 where
   args cvs = do
      let i = pred (getVarI cvs)
          j = pred (getVarJ cvs)
      guard (i>j)
      return (j, i)

-- Variable "j" is for administrating which vectors are already orthogonal
ruleNextOrthogonal :: Rule (Context (VectorSpace a))
ruleNextOrthogonal = minorRule $ makeSimpleRule "Orthogonal to next" $ \cvs -> do
   let i = getVarI cvs
       j = succ (getVarJ cvs)
   guard (j < i)
   return (insertRef varJ j cvs)

-- Consider the next vector
-- This rule should fail if there are no vectors left
ruleNext :: Rule (Context (VectorSpace a))
ruleNext = minorRule $ makeSimpleRule "Consider next vector" $ \cvs -> do
   vs <- fromContext cvs
   let i = getVarI cvs
   guard (i < length (vectors vs))
   return (insertRef varI (i+1) $ insertRef varJ 0 cvs)

current :: Context (VectorSpace a) -> Maybe (Vector a)
current cvs = do
   let i = getVarI cvs
   vs <- fromContext cvs
   listToMaybe (drop (i-1) (vectors vs))

setCurrent :: Vector a -> Context (VectorSpace a) -> Maybe (VectorSpace a)
setCurrent v cvs = do
   let i = getVarI cvs
   vs <- fromContext cvs
   case splitAt (i-1) (vectors vs) of
      (xs, _:ys) -> return $ makeVectorSpace (xs ++ v:ys)
      _          -> mzero

-- Two indices, change the second vector and make it orthogonal
-- to the first
transOrthogonal :: (Reference a, Floating a) => ParamTrans (Int, Int) (Context (VectorSpace a))
transOrthogonal = parameter2 "vector 1" "vector 2" $ \i j -> contextTrans $ \xs ->
   do guard (i /= j && i >=0 && j >= 0)
      u <- listToMaybe $ drop i (vectors xs)
      guard (isUnit u)
      case splitAt j (vectors xs) of
         (begin, v:end) -> Just $ makeVectorSpace $ begin ++ makeOrthogonal u v:end
         _ -> Nothing

-- Find proper abstraction, and move this function to transformation module
contextTrans :: (a -> Maybe a) -> Transformation (Context a)
contextTrans f = makeTrans $ \c -> do
   a   <- fromContext c
   new <- f a
   return (replace new c)