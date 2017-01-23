module Parser.Tokens exposing (..)

import Combine exposing (..)
import Combine.Char exposing (..)
import Parser.Types exposing (ModuleName)
import Parser.Util exposing (nextChar)


reserved : List String
reserved =
    [ "module"
    , "exposing"
    , "import"
    , "as"
    , "if"
    , "then"
    , "else"
    , "let"
    , "in"
    , "case"
    , "of"
    , "port"
    , "infixr"
    , "infixl"
    , "type"
      --, "alias" Apparently this is not a reserved keyword
    , "where"
    ]


portToken : Parser s String
portToken =
    string "port"


moduleToken : Parser s String
moduleToken =
    string "module"


exposingToken : Parser s String
exposingToken =
    string "exposing"


importToken : Parser s String
importToken =
    string "import"


asToken : Parser s String
asToken =
    string "as"


ifToken : Parser s String
ifToken =
    string "if"


thenToken : Parser s String
thenToken =
    string "then"


elseToken : Parser s String
elseToken =
    string "else"


caseToken : Parser s String
caseToken =
    string "case"


ofToken : Parser s String
ofToken =
    string "of"


unitToken : Parser s String
unitToken =
    string "()"


functionOrTypeName : Parser s String
functionOrTypeName =
    or functionName typeName


notReserved : String -> Parser s String
notReserved match =
    if List.member match reserved then
        fail "functionName is reserved"
    else
        succeed match


quotedEscaped : Char -> Parser s Char
quotedEscaped c =
    char '\\'
        *> (choice
                [ c <$ char c
                , '\n' <$ char 'n'
                , '\t' <$ char 't'
                , '\x07' <$ char 'a'
                , '\x08' <$ char 'b'
                , '\x0C' <$ char 'f'
                , '\x0D' <$ char 'r'
                , '\x0B' <$ char 'v'
                ]
           )


quotedSingleQuote : Parser s Char
quotedSingleQuote =
    char '\''
        *> char '\\'
        *> (choice
                [ '\'' <$ char '\''
                , '\n' <$ char 'n'
                , '\t' <$ char 't'
                , '\\' <$ char '\\'
                , '\x07' <$ char 'a'
                , '\x08' <$ char 'b'
                , '\x0C' <$ char 'f'
                , '\x0D' <$ char 'r'
                , '\x0B' <$ char 'v'
                ]
           )
        <* char '\''


characterLiteral : Parser s Char
characterLiteral =
    or quotedSingleQuote
        (char '\'' *> anyChar <* char '\'')


stringLiteral : Parser s String
stringLiteral =
    (char '"')
        *> (String.fromList
                <$> many
                        (or (char '\\' *> anyChar)
                            (noneOf [ '"' ])
                        )
           )
        <* (char '"')


multiLineStringLiteral : Parser s String
multiLineStringLiteral =
    between
        (string "\"\"\"")
        (string "\"\"\"")
        (String.fromList
            <$> many
                    (lookAhead (count 3 anyChar)
                        >>= (\x ->
                                if x == [ '"', '"', '"' ] then
                                    fail "end of input"
                                else
                                    anyChar
                            )
                    )
        )


functionName : Parser s String
functionName =
    regex "[a-z][a-zA-Z0-9_]*'?"
        >>= notReserved


typeName : Parser s String
typeName =
    regex "[A-Z][a-zA-Z0-9_]*"


moduleName : Parser s ModuleName
moduleName =
    sepBy1 (string ".") typeName


excludedOperators : List String
excludedOperators =
    [ ":", "->", "--", "=" ]


allowedOperatorTokens : List Char
allowedOperatorTokens =
    [ '+', '-', ':', '/', '*', '>', '<', '=', '/', '&', '^', '%', '|', '!', '.', '#', '$', '≡', '~', '?' ]


allowedPrefixOperatorTokens : List Char
allowedPrefixOperatorTokens =
    ',' :: allowedOperatorTokens


prefixOperatorToken : Parser s String
prefixOperatorToken =
    operatorTokenFromList allowedPrefixOperatorTokens


infixOperatorToken : Parser s String
infixOperatorToken =
    operatorTokenFromList allowedOperatorTokens


operatorTokenFromList : List Char -> Parser s String
operatorTokenFromList allowedChars =
    String.fromList
        <$> many1 (oneOf allowedChars)
        |> andThen
            (\m ->
                if List.member m excludedOperators then
                    fail "operator is not allowed"
                else
                    succeed m
            )
