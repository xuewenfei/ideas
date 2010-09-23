-----------------------------------------------------------------------------
-- Copyright 2010, Open Universiteit Nederland. This file is distributed 
-- under the terms of the GNU General Public License. For more information, 
-- see the file "LICENSE.txt", which is included in the distribution.
-----------------------------------------------------------------------------
-- |
-- Maintainer  :  bastiaan.heeren@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-----------------------------------------------------------------------------
module Domain.Math.DerivativeRules where

import Prelude hiding ((^))
import Common.Transformation
import Domain.Math.Expr
import Common.Id
import Common.Rewriting

derivativeRules :: [Rule Expr]
derivativeRules =
   [ ruleDerivCon, ruleDerivPlus, ruleDerivMin
   , ruleDerivMultiple, ruleDerivPower, ruleDerivVar 
   , ruleDerivProduct, ruleDerivQuotient {-, ruleDerivChain-}, ruleDerivChainPowerExprs
   , ruleSine, ruleLog 
   ]

diff :: Expr -> Expr
diff = unary diffSymbol

ln :: Expr -> Expr
ln = unary lnSymbol

lambda :: Expr -> Expr -> Expr
lambda = binary lambdaSymbol

fcomp :: Expr -> Expr -> Expr
fcomp = binary fcompSymbol

diffId :: Id
diffId = newId "calculus.differentiation"

-----------------------------------------------------------------
-- Rules for Diffs

ruleSine :: Rule Expr
ruleSine = rule (diffId, "sine") $ 
   \x -> diff (lambda x (sin x))  :~>  lambda x (cos x)

ruleLog :: Rule Expr
ruleLog = rule (diffId, "logarithmic") $
   \x -> diff (lambda x (ln x))  :~>  lambda x (1/x)
       
ruleDerivPlus :: Rule Expr
ruleDerivPlus = rule (diffId, "plus") $
   \x f g -> diff (lambda x (f + g))  :~>  diff (lambda x f) + diff (lambda x g)

ruleDerivMin :: Rule Expr
ruleDerivMin = rule (diffId, "min") $
   \x f g -> diff (lambda x (f - g))  :~>  diff (lambda x f) - diff (lambda x g)

ruleDerivVar :: Rule Expr
ruleDerivVar = rule (diffId, "var") $
   \x -> diff (lambda x x)  :~>  1

ruleDerivProduct :: Rule Expr
ruleDerivProduct = rule (diffId, "product") $
   \x f g -> diff (lambda x (f * g))  :~>  f*diff (lambda x g) + g*diff (lambda x f)
       
ruleDerivQuotient :: Rule Expr
ruleDerivQuotient = rule (diffId, "quotient") $ 
   \x f g -> diff (lambda x (f/g))  :~>  (g*diff (lambda x f) - f*diff (lambda x g)) / (g^2)

{- ruleDerivChain :: Rule Expr
ruleDerivChain = rule "Chain Rule" f
 where f (Diff x (f :.: g)) = return $ (Diff x f :.: g) :*: Diff x g
       f _                        = Nothing -}

-----------------------------------
-- Special rules (not defined with unification)

ruleDerivCon :: Rule Expr
ruleDerivCon = makeSimpleRule (diffId, "constant") f
 where 
   f (Sym d [Sym l [Var v, e]]) 
      | d == diffSymbol && l == lambdaSymbol && v `notElem` collectVars e = return 0
   f _ = Nothing
 
ruleDerivMultiple :: Rule Expr
ruleDerivMultiple = makeSimpleRule (diffId, "constant-multiple") f
 where 
    f (Sym d [Sym l [x@(Var v), n :*: e]]) 
       | d == diffSymbol && l == lambdaSymbol && v `notElem` collectVars n = 
       return $ n * diff (lambda x e)
    f (Sym d [Sym l [x@(Var v), e :*: n]]) 
       | d == diffSymbol && l == lambdaSymbol && v `notElem` collectVars n = 
       return $ n * diff (lambda x e)
    f _ = Nothing 

ruleDerivPower :: Rule Expr
ruleDerivPower = makeSimpleRule (diffId, "power") f
 where 
   f (Sym d [Sym l [x@(Var v), Sym p [x1, n]]]) 
      | d == diffSymbol && l == lambdaSymbol && p == powerSymbol && x==x1 && v `notElem` collectVars n =
      return $ n * (x ^ (n-1)) 
   f _ = Nothing

ruleDerivChainPowerExprs :: Rule Expr
ruleDerivChainPowerExprs = makeSimpleRule (diffId, "chain-rule-power") f 
 where 
   f (Sym d [Sym l [x@(Var v), Sym p [g, n]]]) 
      | d == diffSymbol && l == lambdaSymbol && p == powerSymbol && v `notElem` collectVars n =
      return $ n * (g ^ (n-1)) * diff (lambda x g)
   f _ = Nothing