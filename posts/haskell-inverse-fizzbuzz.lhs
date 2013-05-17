---
title: InverseFizzbuzz :: PenAndPaper -> Haskell
date: 2013-05-01
tags: code, haskell
metadescription: Explores a way to solve inverse fizzbuzz on paper and then using algebraic data types with Haskell.
---

Inverse fizzbuzz is a problem that plays on a well known programming exercise
and interview question called fizzbuzz, which is itself based on a children's
game.  If you haven't read Krishnan Raman's [Inverse
Fizzbuzz](http://www.jasq.org/2/post/2012/05/inverse-fizzbuzz.html) post, it's a
perfect introduction and fun read. I'll assume you're familiar with the basics
before reading on.

The challenge appears deceptively simple at first: given a list of fizz, buzz,
or fizzbuzz strings generated by a contiguous sequence of integers from an
unknown starting value, find the shortest contiguous sequence of integers that
can produce the list of strings.

At the outset we're shown that ```["fizz", "buzz"]``` can be represented as
```[3, 5]``` or ```[9, 10]```, where the latter comes later in the sequence but
contains the shortest possible span of digits. This catch can tempt us towards a
brute force solution: generating all possible representations of the input and
choosing the first one that meets our criteria. We might naively arrive at
something like this:

> import Data.List (sortBy)
> import Data.Ord (comparing)
> import Data.Maybe (fromMaybe)
>
> multiple :: Int -> Int -> Bool
> multiple x y = x `mod` y == 0
>
> -- given a fizzbuzz string as input, determine the base int value
> baseInt :: String -> Int
> baseInt "fizz"     = 3
> baseInt "buzz"     = 5
> baseInt "fizzbuzz" = 15
> baseInt _          = error "invalid fizzbuzz value"
>
> -- given an initial int, zip contiguous multiples of 3 & 5 with input strings
> zipFizzbuzzes :: [String] -> Int -> [(Int, String)]
> zipFizzbuzzes fb n = zip sequence fb
>   where sequence = [x | x <- [n..], x `multiple` 3 || x `multiple` 5]
>
> -- generate all of the possible inverses for a given starting value
> allInverses :: [String] -> [[(Int, String)]]
> allInverses fb = map (zipFizzbuzzes fb) bases
>   where bases  = [base, base*2..]
>         base   = baseInt . head $ fb
>
> -- only map a function to the head of a non-empty list
> safeMapHead :: (a -> b) -> [[a]] -> [b]
> safeMapHead _ []    = []
> safeMapHead f (x:_) = map f x
>
> inverseFizzbuzz :: Int -> [String] -> [Int]
> inverseFizzbuzz n fb = safeMapHead fst $ sortBy (comparing len) inverses
>   where inverses = filter isValid . take n $ allInverses fb
>         isValid  = all $ \(i, f) -> i `multiple` (baseInt f)
>         len seq  = (fst . last) seq - (fst . head) seq

If we notice that the fizzbuzz sequence repeats at each multiple of 15
(fizzbuzz), we can even make a small modification to ```allInverses``` that
turns our infinite solution into a finite one:

> allInverses' :: [String] -> [[(Int, String)]]
> allInverses' fb = map (zipFizzbuzzes fb) bases
>   where bases   = [base, base*2..15]  -- no need to check starting values > 15
>         base    = baseInt . head $ fb

This solution shows off some of haskell's strengths by making it easy to pattern
match strings, lazily evaluate infinite lists, and compose functions. It makes
for a fun algorithmic exercise, but we've barely exercised haskell's
expressiveness with types and data structures.

The first step to our new solution is realizing that, fundamentally, this isn't
a programming problem. It's entirely possible to solve on pen and paper in a
very small number of steps, for any valid sequence of any length. To understand
why, we need a better definition of the fizzbuzz sequence.

Our earlier catch showed that one sequence of multiples of 3 and 5 (```[9,
10]```) could have a shorter span than another (```[3, 5]```). What we need is a
way to represent these as distinct members of the sequence while preserving
ordering and preserving the distance between predecessors and
successors. Conceptually we can see that the sequence is bounded by multiples of
15. Every multiple of 15 is followed by a multiple of 3, then 5, then 3, 3, 5,
3, and 15 again. We can define each of the seven elements in the repeating
sequence uniquely in these terms, for any possible value of ```n >= 0```:

```
15n + 3, 15n + 5, 15n + 6, 15n + 9, 15n + 10, 15n + 12, 15n + 15
```

In haskell we might write:

> infiniteFizzbuzz  = concatMap makeSeq [0..]
>   where makeSeq n = map (\x -> 15 * n + x) [3, 5, 6, 9, 10, 12, 15]

This definition will produce all successive multiples of 3 and 5 the same as a
list comprehension:

```
[ x | x <- [3..], x `mod` 3 == 0 || x `mod` 5 == 0]
```

However, because our new definition treats each value in the repeating sequence
as unique, we can show that the span between any two members of the sequence
does not change as ```n``` grows. For instance, ```(15n + 15) - (15n + 3)``` can
be reduced to eliminate ```n``` and produce a constant. We may have a longer
sequence that goes past 15n + 15, but we can show that it's possible to reduce
any two points with ```n + 1``` to a constant as well:

```
(15(n+1) + 15) - (15n + 3) = (15n + 15 + 15) - (15n + 3)
                           = 15n + 15 + 15 - 15n - 3
                           = 30 - 3
                           = 27
```

It's important to note that any input sequence can be represented infinitely
many ways by choosing a different starting value for ```n```, but the distance
between the starting and ending members of the sequence will remain constant.
For this reason we can always choose an appropriate starting value with
```n = 0``` and produce a solution with the shortest possible span of digits.

Looking at our seven element repeating sequence, we can see that any possible
consecutive combination of four or more digits does not repeat, meaning that
for any input list of length four or greater, there is a unique solution.

For instance, if we're given the input ```["fizz", "buzz", "fizz", "fizz"]```,
we can converge on a unique solution by starting with a finite list of possible
starting values for the first string in the input, and reducing it as we inspect
subsequent inputs:

| Input consumed so far   | Valid starting values                 |
|-------------------------|---------------------------------------|
| fizz                    | [15n + 3, 15n + 6, 15n + 9, 15n + 12] |
| fizz, buzz              | [15n + 3, 15n + 9]                    |
| fizz, buzz, fizz        | [15n + 3, 15n + 9]                    |
| fizz, buzz, fizz, fizz  | [15n + 3]                             |


This gives us the basis for a pen and paper solution. But it turns out this
leads to an even more interesting haskell solution. Our new definition of the
sequence can first be modeled as an algebraic type:

> data FifteenN = Plus3 | Plus5 | Plus6 | Plus9 | Plus10 | Plus12 | Plus15
>   deriving (Show, Eq, Enum)

This already gives us a concise way to represent the infinite fizzbuzz sequence,
thanks to derived typeclasses:

> infiniteFizzbuzz' = cycle [Plus3 .. Plus15]

The rest of our solution will be simpler if we have a way to represent values of
```FifteenN``` as ```String```s and in terms of their base ```Int```s:

> toFizzbuzz :: FifteenN -> String
> toFizzbuzz fb | fb == Plus15              = "fizzbuzz"
>               | fb `elem` [Plus5, Plus10] = "buzz"
>               | otherwise                 = "fizz"
>
> toInt :: FifteenN -> Int
> toInt Plus3  = 3
> toInt Plus5  = 5
> toInt Plus6  = 6
> toInt Plus9  = 9
> toInt Plus10 = 10
> toInt Plus12 = 12
> toInt Plus15 = 15

Since the original problem requires us to return a value of type ```[Int]```,
we'll also need a way to bind specific ```Int``` values to ```FifteenN```
values. We can create a bound fizzbuzz type as:

> data BoundFB = BoundFB FifteenN Int
>   deriving (Show, Eq)


We'll also want a way to lazily generate an infinite list of ```BoundFB``` for
a given starting value of ```FifteenN```, and a way to determine whether or not
a particular ```BoundFB``` can be represented as a given input string:

> fizzbuzzesFrom :: FifteenN -> [BoundFB]
> fizzbuzzesFrom start = map (uncurry BoundFB) $ zip fizzs mults
>   where mults = [x | x <- [toInt start..], x `multiple` 3 || x `multiple` 5]
>         fizzs = dropWhile (/=start) $ cycle [Plus3 .. Plus15]
>
> canEqual :: String -> BoundFB -> Bool
> canEqual s (BoundFB plus _) = toFizzbuzz plus == s

We can define a function that lets us map the first input string to a
list of possible starting values:

> options :: [String] -> [FifteenN]
> options ("fizz"    :_) = [Plus3, Plus6, Plus9, Plus12]
> options ("buzz"    :_) = [Plus5, Plus10]
> options ("fizzbuzz":_) = [Plus15]
> options _              = []


Before we look at the remainder of the solution, note that there are a finite
number of solutions for inputs of length three or less, and if you check them
all you'll see that the ```[9, 10]``` representation of ```["fizz", "buzz"]```
is the only special case. For all other inputs of length three or less, choosing
the first possible representation results in the shortest possible sequence. It
may feel like cheating to ditch our sorting algorithm, but a truly special case
deserves to be handled separately.

> -- helper function to convert our (input string, bound value) tuple to an Int
> extractInt :: (String, BoundFB) -> Int
> extractInt (_, BoundFB _ n) = n
>
> -- finds the first valid solution or []
> inverseFizzbuzz' :: [String] -> [Int]
> inverseFizzbuzz' ["fizz", "buzz"] = [9, 10]
> inverseFizzbuzz' fizzStrings      = safeMapHead extractInt solutions
>     where
>       infiniteSeqs = map fizzbuzzesFrom (options fizzStrings)
>       zipped       = map (zip fizzStrings) infiniteSeqs
>       solutions    = filter isValid zipped
>       isValid      = all $ uncurry canEqual

This last solution showed us all the same benefits of haskell as before, but
with an added level of type safety that still lets us express complex
computations in a very concise and elegant way.