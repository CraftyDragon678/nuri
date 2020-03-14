module Repl where

import           Prelude                           hiding ( writeFile )

import           System.IO                                ( hFlush )

import           Data.Text                                ( strip )
import           Data.ByteString.Lazy.Internal            ( unpackBytes )

import           Control.Lens                             ( makeLenses
                                                          , view
                                                          )
import           Control.Lens.TH                          ( )

import           Data.Binary                              ( encode
                                                          , decode
                                                          )

import           Text.Megaparsec                          ( runParser
                                                          , eof
                                                          , errorBundlePretty
                                                          )
import           Text.Pretty.Simple                       ( pPrint )

import           Nuri.Stmt
import           Nuri.Codegen.Stmt
import           Nuri.Parse.Stmt

import           Haneul.Builder
import           Haneul.BuilderInternal
import           Haneul.Constant
import           Haneul.Serial                            ( )

newtype ReplState = ReplState { _prompt :: Text }

$(makeLenses ''ReplState)

newtype Repl a = Repl { unRepl :: StateT ReplState IO a }
  deriving (Monad, Functor, Applicative, MonadState ReplState, MonadIO)

parseInput :: Text -> String -> MaybeT IO (NonEmpty Stmt)
parseInput input fileName = do
  case runParser (parseStmts <* eof) fileName input of
    Left err -> do
      (liftIO . putTextLn . toText . errorBundlePretty) err
      hoistMaybe Nothing
    Right parseResult -> return parseResult

printResult :: (NonEmpty Stmt) -> IO ()
printResult stmts = do
  (liftIO . pPrint) stmts
  let program =
        ( internalToFuncObject
          . runBuilder defaultInternal
              { _internalGlobalVarNames = defaultGlobalNames
              }
          . compileStmts
          )
          stmts
      compiledCode  = view funcCode program
      compiledTable = view funcConstTable program

  putStrLn "---------------"
  pPrint compiledTable
  pPrint compiledCode
  putStrLn "---------------"

  let encodedProgram = encode program
  writeFileLBS "./test.hn" encodedProgram

  when ((decode encodedProgram) == program)
       (putStrLn "Program encoding is valid")

repl :: Repl ()
repl = forever $ do
  st <- get
  liftIO $ do
    putText (view prompt st)
    hFlush stdout
  input <- strip <$> liftIO getLine
  liftIO $ when (input == ":quit") exitSuccess
  result <- (liftIO . runMaybeT . parseInput input) "(반응형)"
  case result of
    Just stmts -> liftIO (printResult stmts)
    Nothing    -> pass

runRepl :: Repl a -> ReplState -> IO a
runRepl f = evalStateT (unRepl f)
