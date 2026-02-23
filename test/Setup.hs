import Data.Time.Clock (getCurrentTime)
import Distribution.Simple (defaultMainWithHooks, simpleUserHooks)
import Distribution.Simple.UserHooks (UserHooks (..))
import System.Directory (setModificationTime)

-- | Touch Main.hs before every build so that Cabal always recompiles and
--   relinks the test executable against the current liblong-int.a.
--
--   Cabal does not track changes to external static libraries specified via
--   extra-lib-dirs / extra-libraries, so without this hook the test binary
--   can go stale after the library is rebuilt.
main :: IO ()
main =
  defaultMainWithHooks
    simpleUserHooks
      { preBuild = \_ _ -> do
          now <- getCurrentTime
          setModificationTime "Main.hs" now
          pure (Nothing, [])
      }
