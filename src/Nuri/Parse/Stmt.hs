module Nuri.Parse.Stmt where

import           Text.Megaparsec
import           Text.Megaparsec.Char
import qualified Text.Megaparsec.Char.Lexer    as L

import           Nuri.Parse
import           Nuri.Parse.Expr
import           Nuri.Stmt
import           Nuri.Expr

exprStmt :: Parser Stmt
exprStmt = ExprStmt <$> (expr <* notFollowedBy returnKeywords)

returnStmt :: Parser Stmt
returnStmt = Return <$> (expr <* returnKeywords)

functionDecl :: Parser Stmt
functionDecl = L.nonIndented scn (L.indentBlock scn p)
 where
  p = do
    pos  <- getSourcePos
    args <- many (char '[' *> identifier <* char ']')
    sc
    funcName <- funcIdentifier
    lexeme $ char ':'
    return (L.IndentSome Nothing (return . FuncDecl pos funcName args) stmt)
  stmt = try exprStmt <|> returnStmt
