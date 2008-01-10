-----------------------------------------------------------------------------
-- |
-- Maintainer  :  alex.gerdes@ou.nl
-- Stability   :  provisional
-- Portability :  portable (depends on ghc)
--
-- (todo)
--
-----------------------------------------------------------------------------
module Domain.Fraction.Expr where

import Common.Unification
import Common.Utils
import Data.List
import Data.Maybe
import Ratio
import qualified Data.Set as S

infixl 7 :*:, :/: 
infixl 6 :+:, :-:

-- | The data type Expr is the abstract syntax for the domain
-- | of arithmetic expressions.
data Expr a =  Var String              -- variable
            |  Lit a                   -- literal
            |  Expr a :*: Expr a       -- multiplication
            |  Expr a :/: Expr a       -- fraction
            |  Expr a :+: Expr a       -- addition
            |  Expr a :-: Expr a       -- substraction
 deriving (Show, Eq, Ord)

type ExprRat = Expr Rational

-- | The type ExprAlg is the algebra for the data type Expr
-- | Used in the fold for Expr.
type ExprAlg a b = (String -> a,
                    b -> a,
                    a -> a -> a, 
                    a -> a -> a, 
                    a -> a -> a,
                    a -> a -> a)                  

-- | foldExpr is the standard folfd for Expr.
foldExpr :: ExprAlg b a -> Expr a -> b
foldExpr (var, lit, mul, frac, add, sub) = rec
 where
   rec expr = 
      case expr of
         Var x    -> var x
         Lit x    -> lit x
         x :*: y  -> rec x `mul`  rec y
         x :/: y  -> rec x `frac` rec y
         x :+: y  -> rec x `add`  rec y
         x :-: y  -> rec x `sub`  rec y
              
-- | evalExpr takes a function that gives a expression value to a variable,
-- | and a Expr expression, and evaluates the expression.
evalExpr :: Fractional a => (String -> a) -> Expr a -> a
evalExpr env = foldExpr (env, id, (*), (/), (+), (-))

-- | Function to unify to fraction formulas: a returned substitution maps 
-- | variables (String) to fraction formulas 
unifyExpr :: Eq a => Expr a -> Expr a -> Maybe (Substitution (Expr a))
unifyExpr x y = 
   case (x, y) of
      (Var v, Var w) | v == w -> return emptySubst
      (Var v, _)              -> return (singletonSubst v y)
      (_    , Var w)          -> return (singletonSubst w x)
      (Lit x, Lit y) | x == y -> return emptySubst
      (x1 :*: x2,  y1 :*: y2) -> unifyList [x1, x2] [y1, y2]
      (x1 :/: x2,  y1 :/: y2) -> unifyList [x1, x2] [y1, y2]
      (x1 :+: x2,  y1 :+: y2) -> unifyList [x1, x2] [y1, y2]
      (x1 :-: x2,  y1 :-: y2) -> unifyList [x1, x2] [y1, y2]
      _ -> Nothing


-- | eqExpr determines whether or not two Expr expression are arithmetically 
-- | equal, by evaluating the expressions on all valuations.
eqExpr :: Fractional a => Expr a -> Expr a -> Bool
eqExpr = (~=)

-- | Function varsExpr returns the variables that appear in a Expr expression.
varsExpr :: Expr a -> [String]
varsExpr = foldExpr (return, (\x -> []), union, union, union, union)

instance HasVars (Expr a) where
   getVars = S.fromList . varsExpr

instance MakeVar (Expr a) where
   makeVar = Var

instance Substitutable (Expr a) where 
   (|->) sub = foldExpr (var, Lit, (:*:), (:/:), (:+:), (:-:))
       where var x = fromMaybe (Var x) (lookupVar x sub)

instance Eq a => Unifiable (Expr a) where
   unify = unifyExpr

infix 1 ~=
x ~= y = normalise x == normalise y

normalise :: Fractional a => Expr a -> Expr a
normalise x = 
   let vs = S.toList $ getVars x
       v  = minimum vs
       (a, b) = exprSplit v x
       lit = normalise (simplify b)
       var = simplify (Var v :*: normalise (simplify a))
   in if null vs then simplify x else 
      case lit of 
         Lit 0 -> var
         _     -> var :+: lit
   
simplify :: Fractional a => Expr a -> Expr a
simplify this = 
   case this of
      a :+: b -> case (simplify a, simplify b) of
                   (Lit x, Lit y) -> Lit (x+y)
                   (Lit 0, c) -> c
                   (c, Lit 0) -> c
                   (c :+: d, e) -> c :+: (d :+: e)
                   (c, d) -> c :+: d
      a :*: b -> case (simplify a, simplify b) of
                   (Lit x, Lit y) -> Lit (x*y)
                   (Lit 0, c) -> Lit 0
                   (c, Lit 0) -> Lit 0
                   (Lit 1, c) -> c
                   (c, Lit 1) -> c
                   (c :*: d, e) -> c :*: (d :*: e)
                   (c, d) -> c :*: d
      a :/: b -> case (simplify a, simplify b) of
                   (Lit x, Lit y) -> Lit (x/y)
                   (Lit 0, c) -> Lit 0
                   (c, Lit 1) -> c
                   (c, d) -> c :/: d
      a :-: b -> case (simplify a, simplify b) of
                   (Lit x, Lit y) -> Lit (x-y)
                   (c, Lit 0) -> c
                   (c :-: d, e) -> c :-: (d :+: e)
                   (c, d) -> c :-: d
      _ -> this

exprSplit :: Fractional a => String -> Expr a -> (Expr a, Expr a)
exprSplit x this =
   case this of
      Var y | x==y -> (Lit 1, Lit 0)
      a :+: b -> let (a1, a2) = exprSplit x a
                     (b1, b2) = exprSplit x b
                 in (a1 :+: b1, a2 :+: b2)
      a :*: b -> let (a1, a2) = exprSplit x a
                     (b1, b2) = exprSplit x b
                 in (a1 :*: b2 :+: a2 :*: b1, a2 :*: b2)
      a :-: b -> let (a1, a2) = exprSplit x a
                     (b1, b2) = exprSplit x b
                 in (a1 :-: b1, a2 :-: b2)
      a :/: b -> let (a1, a2) = exprSplit x a
                     (b1, b2) = exprSplit x b      
                     p = case b2 of
                              Lit 0 -> Lit 0
                              _     -> a1 :/: b2
                     q = case b1 of
                              Lit 0 -> Lit 0
                              _     -> a2 :/: b1
                     r = case b2 of
                              Lit 0 -> Lit 0
                              _     -> a2 :/: b2
                 in (p :+: q, r)
      _ -> (Lit 0, this)

e1 = Var "x" :/: Lit 3 :+: Lit 2 :*: Var "x" :+: Lit (9::Rational)
e2 = Lit 2 :*: Var "x" :+: Var "x" :/: Lit 3 :+: Lit (9::Rational)
