{-# LANGUAGE RecordWildCards #-}

module Main (main) where

import Control.Exception (SomeException, displayException, try)
import Control.Monad (replicateM, unless, when)
import Control.Monad.IO.Class (liftIO)
import Control.Monad.Loops (allM)
import Control.Monad.Trans.Cont (ContT (..), evalContT)
import Control.Monad.Trans.State.Strict (StateT, evalStateT, state)
import Data.Bits ((.&.), shiftL, shiftR)
import Data.Traversable (for)
import Data.Word (Word64)
import Foreign.C.Types (CSize (..))
import Foreign.Marshal.Array (allocaArray, peekArray, pokeArray)
import Foreign.Ptr (Ptr)
import Options.Applicative
import System.Exit (exitFailure)
import System.Random.SplitMix (SMGen, initSMGen, mkSMGen, nextWord64)

----- FFI declarations -----

foreign import ccall "long_int_add"
  c_long_int_add :: Ptr Word64 -> Ptr Word64 -> CSize -> IO ()

foreign import ccall "long_int_sub"
  c_long_int_sub :: Ptr Word64 -> Ptr Word64 -> CSize -> IO ()

foreign import ccall "long_int_mul"
  c_long_int_mul :: Ptr Word64 -> Ptr Word64 -> Ptr Word64 -> CSize -> IO ()

foreign import ccall "long_int_add_checked"
  c_long_int_add_checked :: Ptr Word64 -> Ptr Word64 -> CSize -> IO Word64

foreign import ccall "long_int_sub_checked"
  c_long_int_sub_checked :: Ptr Word64 -> Ptr Word64 -> CSize -> IO Word64

foreign import ccall "long_int_mul_checked"
  c_long_int_mul_checked :: Ptr Word64 -> Ptr Word64 -> Ptr Word64 -> CSize -> IO Word64

----- Integer/Words conversion -----

wordMask :: Integer
wordMask = (1 `shiftL` 64) - 1

integerToWords :: Int -> Integer -> [Word64]
integerToWords n = take n . (++ repeat 0) . go
  where
    go 0 = []
    go x = fromIntegral (x .&. wordMask) : go (x `shiftR` 64)

wordsToInteger :: [Word64] -> Integer
wordsToInteger = foldl' (\acc w -> (acc `shiftL` 64) + toInteger w) 0 . reverse

----- FFI wrappers -----

type RunOpSimple = Int -> Integer -> Integer -> IO Integer
type RunOpWithOutcome = Int -> Integer -> Integer -> IO (Integer, Word64)

type WithOutcome o fn = (o -> Word64) -> fn -> RunOpWithOutcome

runAdditiveWithOutcome :: WithOutcome o (Ptr Word64 -> Ptr Word64 -> CSize -> IO o)
runAdditiveWithOutcome toOutcome fn qwords a b =
  evalContT $ do
    aPtr <- ContT $ allocaArray qwords
    bPtr <- ContT $ allocaArray qwords
    liftIO $ pokeArray aPtr (integerToWords qwords a)
    liftIO $ pokeArray bPtr (integerToWords qwords b)
    outcome <- liftIO $ toOutcome <$> fn aPtr bPtr (fromIntegral qwords)
    answer <- liftIO $ wordsToInteger <$> peekArray qwords aPtr
    pure (answer, outcome)

runMulWithOutcome :: WithOutcome o (Ptr Word64 -> Ptr Word64 -> Ptr Word64 -> CSize -> IO o)
runMulWithOutcome toOutcome fn qwords a b =
  evalContT $ do
    aPtr <- ContT $ allocaArray qwords
    bPtr <- ContT $ allocaArray qwords
    outPtr <- ContT $ allocaArray (qwords * 2)
    liftIO $ pokeArray aPtr (integerToWords qwords a)
    liftIO $ pokeArray bPtr (integerToWords qwords b)
    outcome <- liftIO $ toOutcome <$> fn aPtr bPtr outPtr (fromIntegral qwords)
    answer <- liftIO $ wordsToInteger <$> peekArray (qwords * 2) outPtr
    pure (answer, outcome)

asChecked :: WithOutcome Word64 fn -> fn -> RunOpWithOutcome
asChecked runWithOutcome = runWithOutcome id

asUnchecked :: WithOutcome () fn -> fn -> RunOpSimple
asUnchecked runWithOutcome fn qwords a b = fst <$> runWithOutcome (const 0) fn qwords a b

runAddChecked :: RunOpWithOutcome
runAddChecked = asChecked runAdditiveWithOutcome c_long_int_add_checked

runSubChecked :: RunOpWithOutcome
runSubChecked = asChecked runAdditiveWithOutcome c_long_int_sub_checked

runMulChecked :: RunOpWithOutcome
runMulChecked = asChecked runMulWithOutcome c_long_int_mul_checked

runAdd :: RunOpSimple
runAdd = asUnchecked runAdditiveWithOutcome c_long_int_add

runSub :: RunOpSimple
runSub = asUnchecked runAdditiveWithOutcome c_long_int_sub

runMul :: RunOpSimple
runMul = asUnchecked runMulWithOutcome c_long_int_mul

----- ABI checking -----

reportAbiViolations :: Word64 -> IO ()
reportAbiViolations outcome = do
  putStrLn "ABI violated:"
  when (outcome .&. 1  /= 0) $ printClobbered "RBX"
  when (outcome .&. 2  /= 0) $ printClobbered "RBP"
  when (outcome .&. 4  /= 0) $ printClobbered "R12"
  when (outcome .&. 8  /= 0) $ printClobbered "R13"
  when (outcome .&. 16 /= 0) $ printClobbered "R14"
  when (outcome .&. 32 /= 0) $ printClobbered "R15"
  when (outcome .&. 64 /= 0) $ putStrLn "  - stack misaligned"
  where
    printClobbered reg = putStrLn $ "  - " ++ reg ++ " clobbered"

----- Operations -----

data Operation = Operation
  { opName :: String
  , opRun :: Int -> Integer -> Integer -> IO Integer
  , opRunChecked :: Int -> Integer -> Integer -> IO (Integer, Word64)
  , opCalcAnswer :: Integer -> Integer -> Integer -> Integer
  }

addOp :: Operation
addOp = Operation "add" runAdd runAddChecked (\m a b -> (a + b) `mod` m)

subOp :: Operation
subOp = Operation "sub" runSub runSubChecked (\m a b -> (a - b + m) `mod` m)

mulOp :: Operation
mulOp = Operation "mul" runMul runMulChecked (\m a b -> (a * b) `mod` (m * m))

operations :: [Operation]
operations = [addOp, subOp, mulOp]

----- Random -----

type Rand = StateT SMGen IO

nextWord :: Rand Word64
nextWord = state nextWord64

randomValue :: Int -> Rand Integer
randomValue qwords = wordsToInteger <$> replicateM qwords nextWord

randomPair :: Int -> Rand (Integer, Integer)
randomPair qwords = (,) <$> randomValue qwords <*> randomValue qwords

----- Testing -----

data TestResult
  = TestOK
  | TestWrongAnswer Integer
  | TestAbiViolation Word64
  | TestException SomeException

runTest :: Bool -> Operation -> Int -> Integer -> Integer -> Integer -> IO TestResult
runTest doCheckAbi Operation{..} qwords expectedAnswer a b =
  if doCheckAbi
    then do
      r <- try (opRunChecked qwords a b) :: IO (Either SomeException (Integer, Word64))
      pure $ case r of
        Left ex -> TestException ex
        Right (actualAnswer, outcome)
          | outcome /= 0 -> TestAbiViolation outcome
          | actualAnswer == expectedAnswer -> TestOK
          | otherwise -> TestWrongAnswer actualAnswer
    else do
      r <- try (opRun qwords a b) :: IO (Either SomeException Integer)
      pure $ case r of
        Left ex -> TestException ex
        Right actualAnswer
          | actualAnswer == expectedAnswer -> TestOK
          | otherwise -> TestWrongAnswer actualAnswer

reportTest :: String -> Int -> Integer -> Integer -> Integer -> TestResult -> IO Bool
reportTest opName idx a b expectedAnswer result = do
  putStr $ "Test " ++ show idx ++ ". "
  case result of
    TestOK -> do
      putStrLn "OK"
      pure True
    err -> do
      putStr "ERROR: "
      case err of
        TestWrongAnswer actualAnswer ->
          putStrLn $ unlines
            [ ""
            , show a
            , opName
            , show b
            , "= (real answer)"
            , show expectedAnswer
            , "!= (your answer)"
            , show actualAnswer
            ]
        TestAbiViolation outcome ->
          reportAbiViolations outcome
        TestException ex ->
          putStrLn $ displayException ex
      pure False

----- Deterministic tests -----

data DeterministicTest = DeterministicTest
  { dtOp :: Operation
  , dtA :: Integer
  , dtB :: Integer
  }

deterministicTests :: Int -> [DeterministicTest]
deterministicTests qwords =
  [ DeterministicTest mulOp maxValue maxValue
  , DeterministicTest mulOp maxValue (maxValue - 1)
  , DeterministicTest mulOp (maxValue - 1) maxValue
  ]
  where
    maxValue = 2 ^ (qwords * 64) - 1

runDeterministicTests :: Bool -> Int -> [DeterministicTest] -> IO Bool
runDeterministicTests doCheckAbi qwords tests = do
  putStrLn "===== deterministic ====="
  allM runAndReport (zip [1..] tests)
  where
    modulus = 2 ^ (qwords * 64)
    runAndReport (idx, DeterministicTest{..}) = do
      let Operation{..} = dtOp
          expectedAnswer = opCalcAnswer modulus dtA dtB
      result <- runTest doCheckAbi dtOp qwords expectedAnswer dtA dtB
      reportTest opName idx dtA dtB expectedAnswer result

----- Random tests -----

runRandomTests :: Bool -> Int -> Int -> Operation -> Rand Bool
runRandomTests doCheckAbi qwords nTests op@Operation{..} = do
  liftIO $ putStrLn $ "===== " ++ opName ++ " ====="
  allM runAndReport [1 .. nTests]
  where
    modulus = 2 ^ (qwords * 64)
    runAndReport idx = do
      (a, b) <- randomPair qwords
      let expectedAnswer = opCalcAnswer modulus a b
      result <- liftIO $ runTest doCheckAbi op qwords expectedAnswer a b
      liftIO $ reportTest opName idx a b expectedAnswer result

----- Main -----

data Options = Options
  { qwords :: Int
  , nTests :: Int
  , rngSeed :: Maybe Word64
  , checkAbi :: Bool
  }

optionsParser :: Parser Options
optionsParser =
  Options
    <$> option auto (long "qwords" <> metavar "N" <> value 128 <> showDefault
          <> help "Max qwords (max value will be: 2^(N*64) - 1)")
    <*> option auto (long "n-tests" <> metavar "N" <> value 1000 <> showDefault
          <> help "Number of tests per operation")
    <*> optional (option auto (long "seed" <> metavar "N"
          <> help "Fixed RNG seed for reproducible tests"))
    <*> switch (long "check-abi"
          <> help "Check ABI conformance on FFI calls")

main :: IO ()
main = do
  Options{..} <- execParser $ info (optionsParser <**> helper) fullDesc
  detResult <- runDeterministicTests checkAbi qwords (deterministicTests qwords)
  unless (detResult) exitFailure
  gen <- maybe initSMGen (pure . mkSMGen) rngSeed
  results <- flip evalStateT gen $ for operations $ \op ->
    runRandomTests checkAbi qwords nTests op
  unless (and results) exitFailure
