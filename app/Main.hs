module Main where

import           Control.Exception   (IOException, catch)
import           Control.Monad       (Monad, filterM, join, liftM, mapM, return,
                                      (>>=))
import           Data.Bool           (Bool, otherwise)
import           Data.Char           (intToDigit)
import           Data.Foldable       (foldMap)
import           Data.Function       (($), (.))
import           Data.Functor        ((<$>))
import           Data.Int            (Int)
import           Data.List           (concatMap, length, replicate, unlines,notElem,filter)
import           Data.Monoid         (Monoid (..), (<>))
import           Data.Ord            (max, (<))
import           Data.String         (String)
import           Data.Time.Calendar  (Day, addGregorianMonthsClip, toGregorian)
import           Data.Time.Clock     (getCurrentTime, utctDay)
import           Numeric             (showIntAtBase)
import           Options.Applicative (Parser, execParser, fullDesc, header,
                                      help, helper, info, long, many, metavar,
                                      progDesc, strOption, switch, (<**>))
import           PlpdMailTemplate    (printMailTemplate)
import           Prelude             (fromIntegral, (-))
import           System.Directory    (copyFile, createDirectory,
                                      doesDirectoryExist, doesFileExist,
                                      listDirectory, removeDirectoryRecursive)

import           Control.Applicative ((<*>))
import           System.FilePath     (FilePath, (</>))
import           System.IO           (IO, print, putStrLn)
import           System.Posix.Files  (setFileMode, setOwnerAndGroup,
                                      unionFileModes)
import qualified System.Posix.Files  as PosixFiles
import           System.Posix.Types  (FileMode)
import           System.Posix.User   (getGroupEntryForName, getUserEntryForName,
                                      groupID, userID)
import           Text.Show           (Show (..))

{-
Beschreibung des Programms:

Variablen:

  - SYNCTHINGDIR
  - TARGETDIR
  - USER

Beschreibung:

  - Berechne aktuellen Monat und Jahr (CURMONTH), sowie den letzten (LASTMONTH)
  - Gehe in $SYNCTHINGDIR, gehe alle Verzeichnisse drunter durch, für jedes DIR
    - Falls DIR/CURMONTH nicht existiert, nächstes DIR.
    - Sonst kopiere DIR/CURMONTH/* nach TARGETDIR/DIR/CURMONTH/
    - Außerdem lösche TARGETDIR/DIR/PREVMONTH, falls existent
  - Für alle Verzeichnisse DIR in TARGETDIR
    - Setze owner:group auf USER:ssh
    - Setze Rechte 775
    - Für jede Datei FILE
      - Setze owner:group auf USER:ssh
      - Setze Rechte 664
 -}

newtype FsGroup = FsGroup { fsGroup :: String }
newtype FsOwner = FsOwner { fsOwner :: String }
newtype FsSource = FsSource { fsSource :: FilePath }
newtype FsTarget = FsTarget { fsTarget :: FilePath }
newtype FsFileMode = FsFileMode { fileMode :: FileMode }

instance Show FsFileMode where
  show (FsFileMode x) = pad 3 ( showIntAtBase 8 intToDigit x "" )
    where pad n s = replicate (max 0 (n - length s)) '0' <> s

instance Monoid FsFileMode where
  mempty = FsFileMode PosixFiles.nullFileMode
  (FsFileMode a) `mappend` (FsFileMode b) = FsFileMode (a `unionFileModes` b)

ownerReadMode :: FsFileMode
ownerWriteMode :: FsFileMode
ownerExecuteMode :: FsFileMode
ownerModes :: FsFileMode
groupReadMode :: FsFileMode
groupWriteMode :: FsFileMode
groupExecuteMode :: FsFileMode
groupModes :: FsFileMode
otherReadMode :: FsFileMode
otherWriteMode :: FsFileMode
otherExecuteMode :: FsFileMode
otherModes :: FsFileMode
ownerReadMode = FsFileMode PosixFiles.ownerReadMode
ownerWriteMode = FsFileMode PosixFiles.ownerWriteMode
ownerExecuteMode = FsFileMode PosixFiles.ownerExecuteMode
ownerModes = FsFileMode PosixFiles.ownerModes
groupReadMode = FsFileMode PosixFiles.groupReadMode
groupWriteMode = FsFileMode PosixFiles.groupWriteMode
groupExecuteMode = FsFileMode PosixFiles.groupExecuteMode
groupModes = FsFileMode PosixFiles.groupModes
otherReadMode = FsFileMode PosixFiles.otherReadMode
otherWriteMode = FsFileMode PosixFiles.otherWriteMode
otherExecuteMode = FsFileMode PosixFiles.otherExecuteMode
otherModes = FsFileMode PosixFiles.otherModes

data FsOperation =
    FsCopy FsSource FsTarget
  | FsMkdir FsTarget
  | FsRemoveDir FilePath
  | FsChown FilePath FsGroup FsOwner
  | FsChmod FilePath FsFileMode

quote :: String -> String
quote = ( "'" <> ) .  ( <> "'" )

instance Show FsOperation where
  show (FsCopy (FsSource source) (FsTarget target)) = "cp " <> quote source <> " " <> quote target
  show (FsMkdir (FsTarget t)) = "mkdir " <> quote t
  show (FsRemoveDir t) = "rm -r " <> t
  show (FsChown path (FsGroup group) (FsOwner owner)) = "chown " <> quote path <> " " <> group <> ":" <> owner
  show (FsChmod p flags) = "chmod " <> quote p <> " " <> show flags

data CliVars = CliVars {
    cliSourceDir   :: FilePath
  , cliTargetDir   :: FilePath
  , cliUser        :: String
  , cliGroup       :: String
  , cliWetRun      :: Bool
  , cliExcludeDirs :: [FilePath]
  }

cliVarsParser :: Parser CliVars
cliVarsParser =
  CliVars
      <$> strOption
          ( long "source-dir"
         <> help "Source directory for the files (syncthing?)"
         <> metavar "SOURCE_DIR")
      <*> strOption
          ( long "target-dir"
         <> metavar "TARGET_DIR"
         <> help "Target directory for the files (HTTP server dir?)" )
      <*> strOption
          ( long "user"
         <> metavar "USER"
         <> help "User to set as owner of all files/dirs" )
      <*> strOption
          ( long "group"
         <> metavar "GROUP"
         <> help "Group to set for all files/dirs" )
      <*> switch
          ( long "wet-run"
          <> help "really execute the actions (opposite of dry-run)")
      <*> many ( strOption
          ( long "exclude"
         <> metavar "EXCLUSION"
         <> help "Exclude the following directories from copying" ) )

readCliVars :: IO CliVars
readCliVars = execParser opts
  where opts = info (cliVarsParser <**> helper)
         ( fullDesc
         <> progDesc "Copy current month from SOURCE_DIR to TARGET_DIR, then set permissions according to USER:GROUP"
         <> header "keepbooks - plapadoo book-keeping automated" )

data MonthYear = MonthYear {
    myMonth :: Int
  , myYear  :: Int
  }

instance Show MonthYear where
  show x = show (myYear x) <> "-" <> pad (myMonth x)
    where pad n | n < 10 = "0" <> show n
                | otherwise = show n

dayToMonthYear :: Day -> MonthYear
dayToMonthYear day =
  let (year,month,_) = toGregorian day
  in (MonthYear { myMonth = month,myYear = fromIntegral year })

currentMonthYear :: IO MonthYear
currentMonthYear = dayToMonthYear <$> utctDay <$> getCurrentTime

lastMonthYear :: IO MonthYear
lastMonthYear = dayToMonthYear <$> addGregorianMonthsClip (-1) <$> utctDay <$> getCurrentTime

dirsBelowJustName :: FilePath -> IO [FilePath]
dirsBelowJustName dir = listDirectoryIgnoreExns dir >>= filterM (doesDirectoryExist . (dir </>))

filesBelowJustName :: FilePath -> IO [FilePath]
filesBelowJustName dir = listDirectoryIgnoreExns dir >>= filterM (doesFileExist . (dir </>))

-- | The 'concatMapM' function generalizes 'concatMap' to arbitrary monads.
concatMapM        :: (Monad m) => (a -> m [b]) -> [a] -> m [b]
concatMapM f xs   =  liftM join (mapM f xs)

removeOld :: FsTarget -> MonthYear -> IO [FsOperation]
removeOld (FsTarget target) lastMy =
  let lastMyStr = show lastMy
      categoryRmOp cat = FsRemoveDir (target </> cat </> lastMyStr)
  in do
    cats <- dirsBelowJustName target
    return (categoryRmOp <$> cats)

copyNew :: FsSource -> FsTarget -> [FilePath] -> MonthYear -> IO [FsOperation]
copyNew (FsSource source) (FsTarget target) exclusions currentMy = do
  sourceCats <- filter (`notElem` exclusions) <$> (dirsBelowJustName source)
  let currentMyStr = show currentMy
      dirFilter = doesDirectoryExist . (</> currentMyStr) . (source </>)
  filteredCats <- filterM dirFilter sourceCats
  let
      categoryOp :: FilePath -> IO [FsOperation]
      categoryOp cat =
        let mkdir = FsMkdir (FsTarget (target </> cat </> currentMyStr))
            copySource fn = FsSource (source </> cat </> currentMyStr </> fn)
            copyTarget fn = FsTarget (target </> cat </> currentMyStr </> fn)
            fileOp fn = FsCopy (copySource fn) (copyTarget fn)
        in do
           catFiles <- filesBelowJustName (source </> cat </> currentMyStr)
           return $ mkdir : (fileOp <$> catFiles)
  concatMapM categoryOp filteredCats

copyAndMove :: FsSource -> FsTarget -> [FilePath] -> MonthYear -> MonthYear -> IO [FsOperation]
copyAndMove source target exclusions currentMy lastMy = do
  deleteOps <- removeOld target lastMy
  copyOps <- copyNew source target exclusions currentMy
  return (copyOps <> deleteOps)

listDirectoryIgnoreExns :: FilePath -> IO [FilePath]
listDirectoryIgnoreExns fp =
  let errorHandler :: IOException -> IO [FilePath]
      errorHandler _ = return []
  in listDirectory fp `catch` errorHandler

filesAndDirsRecursive :: FilePath -> IO [FilePath]
filesAndDirsRecursive fp = do
  filesAndDirs <- ( (fp </>) <$> ) <$> listDirectoryIgnoreExns fp
  files <- filterM doesFileExist filesAndDirs
  dirs <- filterM doesDirectoryExist filesAndDirs
  recursion <- concatMapM filesAndDirsRecursive dirs
  return (files <> dirs <> recursion)

filesRecursive :: FilePath -> IO [FilePath]
filesRecursive fp = filesAndDirsRecursive fp >>= filterM doesFileExist

dirsRecursive :: FilePath -> IO [FilePath]
dirsRecursive fp = filesAndDirsRecursive fp >>= filterM doesDirectoryExist

adjustRights :: FsTarget -> FsGroup -> FsOwner -> IO [FsOperation]
adjustRights (FsTarget target) group owner = do
  files <- filesRecursive target
  dirs <- dirsRecursive target
  return $ (concatMap adjustDir dirs) <> (concatMap adjustFile files)
  where dirM = ownerModes <> groupModes <> otherReadMode <> otherExecuteMode
        fileM = ownerReadMode <> ownerWriteMode <> groupReadMode <> groupWriteMode <> otherReadMode
        adjustDir dir = [FsChown dir group owner,FsChmod dir dirM]
        adjustFile file = [FsChown file group owner,FsChmod file fileM]

createDirectoryIgnoreExns :: FilePath -> IO ()
createDirectoryIgnoreExns fp =
  let errorHandler :: IOException -> IO ()
      errorHandler _ = return ()
  in createDirectory fp `catch` errorHandler

interpretOperation :: FsOperation -> IO ()
interpretOperation op = do
  print op
  interpretOperation' op
  where
    userIdForName name = userID <$> getUserEntryForName name
    groupIdForName name = groupID <$> getGroupEntryForName name
    interpretOperation' (FsCopy (FsSource source) (FsTarget target)) = copyFile source target
    interpretOperation' (FsMkdir (FsTarget t)) = createDirectoryIgnoreExns t
    interpretOperation' (FsRemoveDir t) = removeDirectoryRecursive t
    interpretOperation' (FsChown path (FsGroup groupName) (FsOwner ownerName)) = do
      user <- userIdForName ownerName
      group <- groupIdForName groupName
      setOwnerAndGroup path user group
    interpretOperation' (FsChmod p (FsFileMode flags)) = setFileMode p flags

keepBooks :: CliVars -> IO ()
keepBooks cliVars = do
  let source = FsSource (cliSourceDir cliVars)
      target = FsTarget (cliTargetDir cliVars)
      exclusions = cliExcludeDirs cliVars
  cmy <- currentMonthYear
  lmy <- lastMonthYear
  copyAndMoveOps <- copyAndMove source target exclusions cmy lmy
  if cliWetRun cliVars
    then do
      putStrLn "Copying and moving documents..."
      foldMap interpretOperation copyAndMoveOps
      let owner = FsOwner (cliUser cliVars)
          group = FsGroup (cliGroup cliVars)
      rightsOps <- adjustRights target group owner
      putStrLn "Now adjusting rights..."
      foldMap interpretOperation rightsOps
      putStrLn "Finished, please send the following mail:"
      printMailTemplate
    else do
      putStrLn "would perform the following move/delete operations:\n"
      putStrLn (unlines (((" • " <>) . show) <$> copyAndMoveOps))

main :: IO ()
main = readCliVars >>= keepBooks
