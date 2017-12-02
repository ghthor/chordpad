module Corpus exposing (..)

import Dict
import Char


type Section
    = Start
    | Seq
    | End


type alias CharCount =
    Dict.Dict Char Int


type alias WordDict =
    Dict.Dict Char (List String)


type alias Corpus =
    { chars : CharCount
    , all : WordDict
    , lowerCase : WordDict
    , upperCase : WordDict
    , digits : WordDict
    , symbols : WordDict
    }


insertWord : String -> WordDict -> WordDict
insertWord word corpus =
    case String.uncons word of
        Nothing ->
            corpus

        Just ( start, word ) ->
            let
                updatedWords =
                    word :: (Dict.get start corpus |> Maybe.withDefault [])
            in
                Dict.insert start updatedWords corpus


newCharCount : String -> CharCount
newCharCount src =
    insertChar src Dict.empty


insertChar : String -> CharCount -> CharCount
insertChar src count =
    case String.uncons src of
        Nothing ->
            count

        Just ( c, src ) ->
            count
                |> Dict.insert c
                    (Dict.get c count
                        |> Maybe.withDefault 0
                        |> (+) 1
                    )
                |> insertChar src


newWordDict : List String -> WordDict
newWordDict words =
    List.foldl insertWord Dict.empty words


toSortedList : WordDict -> List ( Char, List String )
toSortedList words =
    Dict.toList words
        |> List.sortBy (Tuple.second >> List.length)
        |> List.reverse


charIsSymbol : Char -> Bool
charIsSymbol c =
    (not <| Char.isLower c)
        && (not <| Char.isUpper c)
        && (not <| Char.isDigit c)


new : String -> Corpus
new src =
    let
        allWords =
            newWordDict <| String.words <| src
    in
        { chars = newCharCount src
        , all = allWords
        , lowerCase =
            allWords
                |> Dict.filter (\c v -> Char.isLower c)
        , upperCase =
            allWords
                |> Dict.filter (\c v -> Char.isUpper c)
        , digits =
            allWords
                |> Dict.filter (\c v -> Char.isDigit c)
        , symbols =
            allWords
                |> Dict.filter (\c v -> charIsSymbol c)
        }
