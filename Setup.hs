import Control.Monad

import Data.Maybe

import Distribution.PackageDescription qualified as PD
import Distribution.Simple
import Distribution.Simple.BuildPaths
import Distribution.Simple.Compiler
import Distribution.Simple.LocalBuildInfo
import Distribution.Simple.Program
import Distribution.Simple.Setup
import Distribution.Simple.UserHooks
import Distribution.Simple.Utils
import Distribution.System
import Distribution.Text
import Distribution.Verbosity

import GHC.Conc

import System.Directory
import System.Exit

-- -------------------------------------------------------------------------- --
-- RocksDb Sources

rocksdbVersion :: String
rocksdbVersion = "9.7.3"

rocksdbTarFile :: FilePath
rocksdbTarFile = "rocksdb-" <> rocksdbVersion <.> "tar.gz"

-- | The subdirectory inside the rocksdb source tarball as defined by the
-- rocksdb release.
--
rocksdbDir :: String
rocksdbDir = "rocksdb-" <> rocksdbVersion

-- -------------------------------------------------------------------------- --
-- Main Function

main :: IO ()
main =
    defaultMainWithHooks simpleUserHooks
        { buildHook = rocksdbBuildHook
        , hookedPrograms
            = makeProgram
            : install_name_toolProgram
            : hookedPrograms simpleUserHooks
        }

-- -------------------------------------------------------------------------- --
-- Required Build Tools

makeProgram :: Program
makeProgram = simpleProgram "make"

install_name_toolProgram :: Program
install_name_toolProgram = simpleProgram "install_name_tool"

programDb :: ProgramDb
programDb = addKnownPrograms
    [makeProgram, install_name_toolProgram ]
    defaultProgramDb

-- -------------------------------------------------------------------------- --
-- RocksDb Build Hook

rocksdbBuildHook
  :: PD.PackageDescription
  -> LocalBuildInfo
  -> UserHooks
  -> BuildFlags
  -> IO ()
rocksdbBuildHook description localBuildInfo hooks flags = do

    nproc <- getNumProcessors

    pdb <- configureAllKnownPrograms verbosity programDb

    -- TODO check for rocksdb sources
    -- TODO extract version

    notice verbosity $ "Unpacking rocksdb sources to " <> baseBuildDir
    runDbProgram verbosity tarProgram pdb
        [ "-xzf"
        , rocksdbTarFile
        , "-C"
        , baseRocksdbDir
        ]

    -- Build and install rocksdb libraries (static and dynamic)
    notice verbosity $ "Building static rocksdb library in " <> rocksdbBuildDir
    runDbProgram verbosity makeProgram pdb
        [ "-C", rocksdbBuildDir
        , "-j" <> show (nproc * 2)
        , "static_lib"
        , "shared_lib"
        ]

    createDirectoryIfMissingVerbose verbosity True targetBuildDir
    installExecutableFile verbosity staticSource staticTarget
    installExecutableFile verbosity staticSource staticTarget_

    installExecutableFile verbosity dynSource dynTarget
    -- seems to be needed for local use of template haskell
    installExecutableFile verbosity dynSource dynTarget_

    -- fix rpath logic for macosX
    -- when (buildOS == OSX) $ do
    --   runDbProgram verbosity install_name_toolProgram pdb
    --       [ "-id"
    --       , "@rpath/" <> dynTargetFileName
    --       , dynTarget
    --       ]
    --   runDbProgram verbosity install_name_toolProgram pdb
    --       [ "-id"
    --       , "@rpath/" <> dynTargetFileName_
    --       , dynTarget_
    --       ]

    info verbosity "rocksdb build succeeded"
    buildHook simpleUserHooks description localBuildInfo hooks flags
  where
    verbosity = fromFlag $ buildVerbosity flags
    cid = compilerId $ compiler localBuildInfo

    -- The directory into which rocksdb sources are unpacked
    baseRocksdbDir :: FilePath
    baseRocksdbDir = baseBuildDir

    -- The directory where rocksdb is build.
    -- Also the directory where rocksdb build artifacts can be found
    rocksdbBuildDir :: FilePath
    rocksdbBuildDir = baseRocksdbDir </> rocksdbDir

    -- library name stem
    sourceLibname = "rocksdb"
    targetLibname = "C" <> sourceLibname

    -- base builddir for this component within dist-newstyle
    baseBuildDir = buildDir localBuildInfo

    -- directory where rocksdb build artifacts are placed
    targetBuildDir = baseBuildDir

    -- Static library names
    staticSource = rocksdbBuildDir </> mkGenericStaticLibName sourceLibname
    staticTarget = targetBuildDir </> mkGenericStaticLibName targetLibname
    staticTarget_ = targetBuildDir </> mkGenericStaticLibName sourceLibname

    -- Dynamic library names
    dynSource = rocksdbBuildDir </> "lib" <> sourceLibname <.> dllExtension buildPlatform
    dynTargetFileName = mkGenericSharedBundledLibName buildPlatform cid targetLibname
    dynTarget = targetBuildDir </> dynTargetFileName

    -- work around for cabal picking the wrong name during local builds with
    -- template Haskell and in the repl
    dynTargetFileName_ = mkGenericSharedLibName buildPlatform cid targetLibname
    dynTarget_ = targetBuildDir </> dynTargetFileName_

-- -------------------------------------------------------------------------- --
-- Utils

(</>) :: FilePath -> FilePath -> FilePath
a </> b = a <> "/" <> b

(<.>) :: FilePath -> FilePath -> FilePath
a <.> b = a <> "." <> b

