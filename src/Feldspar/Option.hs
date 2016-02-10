module Feldspar.Option
  ( OptionT
  , Option
  , none
  , some
  , guarded
  , option
  , caseOption
  , fromSome
  , optionM
  , caseOptionM
  , fromSomeM
  , optionT
  , caseOptionT
  , fromSomeT
  ) where



import Control.Monad.Operational.Higher
import Control.Monad.Identity
import Control.Monad.Trans

import Feldspar



data Opt (prog :: * -> *) a
    = None String
    | Some a
    | Guard String (Data Bool) a

instance HFunctor Opt
  where
    hfmap f (None msg)      = None msg
    hfmap f (Some a)        = Some a
    hfmap f (Guard msg c a) = Guard msg c a

-- | Transformer version of 'Option'
newtype OptionT m a = Option (ProgramT Opt m a)
  deriving (Functor, Applicative, Monad, MonadTrans)

-- | Optional value, analogous to @`Either` `String` a@ in normal Haskell
type Option = OptionT Identity

-- | Construct a missing 'Option' value (analogous to 'Left' in normal Haskell)
none :: String -> OptionT m a
none = Option . singleton . None

-- | Construct a present 'Option' value (analogous to 'Right' in normal Haskell)
some :: a -> OptionT m a
some = Option . singleton . Some

-- | Construct an 'Option' from a guard and a value. The value will not be
-- evaluated if the guard is false.
guarded :: String -> Data Bool -> a -> OptionT m a
guarded msg c a = Option $ singleton $ Guard msg c a

-- | Deconstruct an 'Option' value (analogous to 'either' in normal Haskell)
option :: Syntax b
    => (String -> b)  -- ^ 'none' case
    -> (a -> b)       -- ^ 'some' case
    -> Option a
    -> b
option noneCase someCase (Option opt) = go (view opt)
  where
    go (Return a)             = someCase a
    go (None msg      :>>= k) = noneCase msg
    go (Some a        :>>= k) = go $ view $ k a
    go (Guard msg c a :>>= k) = cond c (go $ view $ k a) (noneCase msg)

-- | Deconstruct an 'Option' value
caseOption :: Syntax b
    => Option a
    -> (String -> b)  -- ^ 'none' case
    -> (a -> b)       -- ^ 'some' case
    -> b
caseOption o n s = option n s o

-- | Extract the value of an 'Option' that is assumed to be present
fromSome :: Syntax a => Option a -> a
fromSome = option (const example) id

-- | Deconstruct an 'Option' value (analogous to 'maybe' in normal Haskell)
optionM :: MonadComp m
    => (String -> m ())  -- ^ 'none' case
    -> (a -> m ())       -- ^ 'some' case
    -> Option a
    -> m ()
optionM noneCase someCase (Option opt) = go $ view opt
  where
    go (Return a)             = someCase a
    go (None msg      :>>= k) = noneCase msg
    go (Some a        :>>= k) = go $ view $ k a
    go (Guard msg c a :>>= k) = iff c (go $ view $ k a) (noneCase msg)

-- | Deconstruct an 'Option' value
caseOptionM :: MonadComp m
    => Option a
    -> (String -> m ())  -- ^ 'none' case
    -> (a -> m ())       -- ^ 'some' case
    -> m ()
caseOptionM o n s = optionM n s o

-- | Extract the value of an 'Option' that is assumed to be present
fromSomeM :: (Syntax a, MonadComp m) => Option a -> m a
fromSomeM opt = do
    r <- newRef
    caseOptionM opt
        (const $ return ())
        (setRef r)
    unsafeFreezeRef r

-- | Deconstruct an 'OptionT' value
optionT :: MonadComp m
    => (String -> m ())  -- ^ 'none' case
    -> (a -> m ())       -- ^ 'some' case
    -> OptionT m a
    -> m ()
optionT noneCase someCase (Option opt) = go =<< viewT opt
  where
    go (Return a)             = someCase a
    go (None msg      :>>= k) = noneCase msg
    go (Some a        :>>= k) = go =<< viewT (k a)
    go (Guard msg c a :>>= k) = iff c (go =<< viewT (k a)) (noneCase msg)

-- | Deconstruct an 'OptionT' value
caseOptionT :: MonadComp m
    => OptionT m a
    -> (String -> m ())  -- ^ 'none' case
    -> (a -> m ())       -- ^ 'some' case
    -> m ()
caseOptionT o n s = optionT n s o

-- | Extract the value of an 'OptionT' that is assumed to be present
fromSomeT :: (Syntax a, MonadComp m) => OptionT m a -> m a
fromSomeT opt = do
    r <- newRef
    caseOptionT opt
        (const $ return ())
        (setRef r)
    unsafeFreezeRef r
