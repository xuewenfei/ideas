{-# OPTIONS -XFlexibleInstances #-}
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
module Common.Strategy.Abstract 
   ( Strategy, IsStrategy(..)
   , LabeledStrategy, label, unlabel
   , fullDerivationTree, derivationTree, rulesInStrategy
   , mapRules, cleanUpStrategy
     -- Accessors to the underlying representation
   , toCore, fromCore, liftCore, liftCore2, fixCore, makeLabeledStrategy
   , LabelInfo, strategyName, processLabelInfo, changeInfo
   , hidden, skipped, folded, IsLabeled(..)
   ) where

import Common.Strategy.Core
import Common.Strategy.BiasedChoice
import Common.Apply
import Common.Rewriting (RewriteRule(..))
import Common.Transformation
import Common.Derivation
import Common.Uniplate

-----------------------------------------------------------
--- Strategy data-type

-- | Abstract data type for strategies
newtype Strategy a = S { toCore :: Core LabelInfo a }

instance Show (Strategy a) where
   show = show . toCore

instance Apply Strategy where
   applyAll s = results . fullDerivationTree s

-----------------------------------------------------------
--- The information used as label in a strategy

data LabelInfo = Info 
   { labelName :: String 
   , hidden    :: Bool
   , skipped   :: Bool
   , folded    :: Bool
   }

instance Show LabelInfo where
   show = show . labelName

makeInfo :: String -> LabelInfo
makeInfo s = Info s False False False

-----------------------------------------------------------
--- Type class

-- | Type class to turn values into strategies
class Apply f => IsStrategy f where
   toStrategy :: f a -> Strategy a

instance IsStrategy (Core LabelInfo) where
   toStrategy = S

instance IsStrategy Strategy where
   toStrategy = id

instance IsStrategy (LabeledStrategy) where
  toStrategy (LS info (S core)) = 
     case core of
        Rule Nothing r | name r == labelName info -> 
             S (Rule (Just info) r)
        _ -> S (Label info core)

instance IsStrategy Rule where -- Major rules receive a label
   toStrategy r
      | isMajorRule r = toStrategy (toLabeled r)
      | otherwise     = S (Rule Nothing r)

instance IsStrategy RewriteRule where
   toStrategy r = 
      toStrategy (makeRule (ruleName r) (RewriteRule r))

-----------------------------------------------------------
--- Labeled Strategy data-type

-- | A strategy which is labeled with a string
data LabeledStrategy a = LS 
   { labelInfo :: LabelInfo  -- ^ Returns information associated with this label
   , unlabel   :: Strategy a -- ^ Removes the label from a strategy
   }

makeLabeledStrategy :: IsStrategy f => LabelInfo -> f a -> LabeledStrategy a
makeLabeledStrategy info = LS info . toStrategy

strategyName :: LabeledStrategy a -> String
strategyName = getLabel

instance Show (LabeledStrategy a) where
   show s = strategyName s ++ ": " ++ show (unlabel s)

instance Apply LabeledStrategy where
   applyAll = applyAll . toStrategy

class IsLabeled f where
   toLabeled :: f a -> LabeledStrategy a
   
instance IsLabeled LabeledStrategy where
   toLabeled = id

instance IsLabeled Rule where
   toLabeled r = LS (makeInfo (name r)) (S (Rule Nothing r))

instance IsLabeled RewriteRule where
   toLabeled r = toLabeled (makeRule (ruleName r) (RewriteRule r))

-- | Labels a strategy with a string
label :: IsStrategy f => String -> f a -> LabeledStrategy a
label l = LS (makeInfo l) . toStrategy

getLabel :: IsLabeled f => f a -> String
getLabel = labelName . labelInfo . toLabeled

changeInfo :: IsLabeled f => (LabelInfo -> LabelInfo) -> f a -> LabeledStrategy a
changeInfo f a = LS (f info) s
 where LS info s = toLabeled a

-----------------------------------------------------------
--- Process Label Information

processLabelInfo :: (l -> LabelInfo) -> Core l a -> Core l a
processLabelInfo f = rec
 where
   rec core = 
      case core of 
         Label l c
            | hidden info -> Fail
            | folded info -> Rule (Just l) asRule  
            | otherwise   -> new
          where 
            info   = f l
            new    = (if skipped info then mapRule minorRule else id) (Label l (rec c))
            asRule = makeSimpleRuleList (labelName info ++ " (folded)") (applyAll new)
         Rule (Just l) r 
            | hidden info  -> Fail
            | skipped info -> Rule (Just l) (minorRule r)
            | otherwise    -> Rule (Just l) r
          where
            info = f l
         _ -> build (map rec cs)
    where
      (cs, build) = uniplate core

-----------------------------------------------------------
--- Remaining functions

-- | Returns the derivation tree for a strategy and a term, including all
-- minor rules
fullDerivationTree :: IsStrategy f => f a -> a -> DerivationTree (Rule a) a
fullDerivationTree = makeBiasedTree p . processLabelInfo id . toCore . toStrategy 
 where 
   p t = endpoint t || any isMajorRule (annotations t) || any p (subtrees t)

-- | Returns the derivation tree for a strategy and a term with only major rules
derivationTree :: IsStrategy f => f a -> a -> DerivationTree (Rule a) a
derivationTree s = mergeSteps isMajorRule . fullDerivationTree s

-- | Returns a list of all major rules that are part of a labeled strategy
rulesInStrategy :: IsStrategy f => f a -> [Rule a]
rulesInStrategy f = [ r | Rule _ r <- universe (toCore (toStrategy f)), isMajorRule r ]
                    
-- | Apply a function to all the rules that make up a labeled strategy
mapRules :: (Rule a -> Rule b) -> LabeledStrategy a -> LabeledStrategy b
mapRules f (LS n s) = LS n (S (mapRule f (toCore s)))

-- | Use a function as do-after hook for all rules in a labeled strategy
cleanUpStrategy :: (a -> a) -> LabeledStrategy a -> LabeledStrategy a
cleanUpStrategy f (LS n s) = mapRules g (LS n (S core))
 where
   core = Rule Nothing (doAfter f idRule) :*: toCore s
   g r | isMajorRule r = doAfter f r  
       | otherwise     = r
       
-----------------------------------------------------------
--- Functions to lift the core combinators

fromCore :: Core LabelInfo a -> Strategy a
fromCore = toStrategy

liftCore :: IsStrategy f => (Core LabelInfo a -> Core LabelInfo a) -> f a -> Strategy a
liftCore f = fromCore . f . toCore . toStrategy

liftCore2 :: (IsStrategy f, IsStrategy g) => (Core LabelInfo a -> Core LabelInfo a -> Core LabelInfo a) -> f a -> g a -> Strategy a
liftCore2 f = liftCore . f . toCore . toStrategy

fixCore :: (Core l a -> Core l a) -> Core l a
fixCore f = Rec i (f (Var i)) -- disadvantage: function f is applied twice
 where
    s = coreVars (f (Rule Nothing idRule))
    i = if null s then 0 else maximum s + 1