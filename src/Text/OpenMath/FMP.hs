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
-- Formal mathematical properties (FMP)
--
-----------------------------------------------------------------------------
module Text.OpenMath.FMP where

import Data.List (union)
import Text.OpenMath.Object
import Text.OpenMath.Symbol
import Text.OpenMath.Dictionary.Quant1 (forallSymbol, existsSymbol)
import Text.OpenMath.Dictionary.Relation1 (eqSymbol, neqSymbol)

data FMP = FMP
   { quantor       :: Symbol
   , metaVariables :: [String]
   , leftHandSide  :: OMOBJ
   , relation      :: Symbol
   , rightHandSide :: OMOBJ
   }
   
toObject :: FMP -> OMOBJ
toObject fmp
   | null (metaVariables fmp) = body
   | otherwise =
        OMBIND (OMS (quantor fmp)) (metaVariables fmp) body
 where
   body = OMA [OMS (relation fmp), leftHandSide fmp, rightHandSide fmp]
   
eqFMP :: OMOBJ -> OMOBJ -> FMP
eqFMP lhs rhs = FMP
   { quantor       = forallSymbol
   , metaVariables = getOMVs lhs `union` getOMVs rhs
   , leftHandSide  = lhs
   , relation      = eqSymbol
   , rightHandSide = rhs
   }

-- | Represents a common misconception. In certain (most) situations,
-- the two objects are not the same.
buggyFMP :: OMOBJ -> OMOBJ -> FMP
buggyFMP lhs rhs = (eqFMP lhs rhs)
   { quantor  = existsSymbol
   , relation = neqSymbol
   }