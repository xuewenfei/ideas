module Domain.Math.PrimeFactors
   ( PrimeFactors
   , factors, multiplicity, coprime
   , square, power, splitPower
   ) where

import qualified Data.IntMap as IM

-------------------------------------------------------------
-- Representation

-- Invariants:
-- * Keys in map are prime numbers only (exception: representation of 0)
-- * Elements in map are positive (non-zero)
-- * Zero is represented by [(0,1)] (since 0^1 equals 0)
-- * The number can be negative, in which case we use the factors of 
--   its absolute value
data PrimeFactors = PF Integer Factors 

type Factors = IM.IntMap Int

-------------------------------------------------------------
-- Conversion to and from factors

toFactors :: Integer -> Factors
toFactors n
   | n > 0     = rec primes n
   | n < 0     = rec primes (-n)
   | otherwise = IM.singleton 0 1
 where
   rec (p:ps) n
      | n <= 1    = IM.empty
      | otherwise = f 0 n
    where
      p2 = fromIntegral p
      f i m
         | r == 0    = f (i+1) q
         | i >  0    = IM.insert p i (rec ps m)
         | otherwise = rec ps m
       where
         (q, r) = quotRem m p2


fromFactors :: Factors -> Integer
fromFactors = product . map f . IM.toList
 where f (a, i) = fromIntegral a ^ fromIntegral i

primes :: [Int]
primes = rec [2..]
 where
   rec (x:xs) = x : rec (filter (\y -> y `mod` x /= 0) xs)

-------------------------------------------------------------
-- Type class instances

instance Show PrimeFactors where
   show (PF a m) = show a ++ " (factors = " ++ show (IM.toList m) ++ ")"

instance Eq PrimeFactors where
    PF a _ == PF b _ = a==b

instance Ord PrimeFactors where
   PF a _ `compare` PF b _ = a `compare` b
   
instance Num PrimeFactors where
   PF a m1 + PF b m2
      | a==0         = PF b m2 -- prevent recomputing prime factors
      | b==0         = PF a m1
      | otherwise    = fromInteger (a+b)
   a - b             = a + negate b
   PF a m1 * PF b m2
      | a==0 || b==0 = 0
      | otherwise    = PF (a*b) (IM.unionWith (+) m1 m2)
   negate (PF a m)   = PF (negate a) m
   abs    (PF a m)   = PF (abs a) m
   signum (PF a _)   = fromInteger (signum a)
   fromInteger n     = PF n (toFactors n)

instance Enum PrimeFactors where
   toEnum   = fromIntegral
   fromEnum = fromIntegral . toInteger
   
instance Real PrimeFactors where
   toRational = toRational . toInteger
   
instance Integral PrimeFactors where
   toInteger (PF a _) = a
   quotRem = quotRemPF
   
-------------------------------------------------------------
-- Utility functions

factors :: PrimeFactors -> [(Int, Int)]
factors (PF _ m) = IM.toList m

multiplicity :: Int -> PrimeFactors -> Int
multiplicity i (PF _ m) = IM.findWithDefault 0 i m

-- no prime in common
coprime :: PrimeFactors -> PrimeFactors -> Bool
coprime (PF _ m1) (PF _ m2) = IM.null (IM.intersection m1 m2)

square :: PrimeFactors -> PrimeFactors
square = (`power` 2)

power :: PrimeFactors -> Int -> PrimeFactors
power (PF a m) i = PF (a^i) (IM.map (*i) m)

-- splitPower i a = (b,c)  
--  => b^i * c = a
splitPower :: Int -> PrimeFactors -> (PrimeFactors, PrimeFactors)
splitPower i (PF a m) = (PF b p1, PF c p2)
 where 
   pairs = IM.map (`quotRem` i) m
   p1    = IM.filter (>0) (fmap fst pairs)
   p2    = IM.filter (>0) (fmap snd pairs)
   b     = fromFactors p1
   c     = a `div` (b^i)
   
quotRemPF :: PrimeFactors -> PrimeFactors -> (PrimeFactors, PrimeFactors) 
quotRemPF (PF a m1) (PF b m2)
   | b==0 = error "division by zero" 
   | a==0 = (0,0)
   | otherwise = sign $
        case (IM.null up, IM.null dn) of
           (True,  True)  -> (1, 0)
           (False, True)  -> (PF (fromFactors up) up, 0)
           (True,  False) -> (0, PF a m1)
           _              -> (fromInteger qn, fromInteger rn)
 where
   (up, dn) = IM.partition (>0) $ IM.filter (/=0) $ IM.unionWith (+) m1 (IM.map negate m2)
   (qn, rn) = fromFactors up `quotRem` fromFactors (IM.map negate dn)
   sign (q, r) = ( fromInteger (signum a*signum b) * q
                 , fromInteger (signum a) * r
                 )