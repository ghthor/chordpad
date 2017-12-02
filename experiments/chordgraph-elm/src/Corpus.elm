module Corpus exposing (..)

import Dict
import Char
import Html
    exposing
        ( Html
        , div
        , h1
        , text
        , ol
        , li
        )
import Html.Attributes exposing (class)


type Section
    = Start
    | Seq
    | End


type alias CharCount =
    Dict.Dict Char Int


type alias WordTail =
    { tail : String
    , count : Int
    }


type alias WordTails =
    Dict.Dict String WordTail


type alias WordHead =
    { head : Char
    , count : Int
    , tails : Dict.Dict String WordTail
    }


type alias WordHeads =
    Dict.Dict Char WordHead


type alias Corpus =
    { chars : CharCount
    , all : WordHeads
    , lowerCase : WordHeads
    , upperCase : WordHeads
    , digits : WordHeads
    , symbols : WordHeads
    }


newWordHeads : List String -> WordHeads
newWordHeads words =
    List.foldl insertWord Dict.empty words


newWordTails : String -> WordTails
newWordTails tail =
    updateWordTail tail Dict.empty


updateWordTail : String -> WordTails -> WordTails
updateWordTail tail tails =
    Dict.get tail tails
        |> (\node ->
                case node of
                    Nothing ->
                        { tail = tail
                        , count = 1
                        }

                    Just tail ->
                        { tail | count = tail.count + 1 }
           )
        |> (\node ->
                Dict.insert tail node tails
           )


updateWordHead : ( Char, String ) -> WordHeads -> WordHeads
updateWordHead ( head, tail ) words =
    Dict.get head words
        |> (\word ->
                case word of
                    Nothing ->
                        { head = head
                        , count = 1
                        , tails = newWordTails tail
                        }

                    Just word ->
                        { word
                            | count = word.count + 1
                            , tails = updateWordTail tail word.tails
                        }
           )
        |> (\word ->
                Dict.insert head word words
           )


insertWord : String -> WordHeads -> WordHeads
insertWord word heads =
    case String.uncons word of
        Nothing ->
            heads

        Just word ->
            updateWordHead word heads


newCharCount : String -> CharCount
newCharCount src =
    -- TODO Optimization** use String.foldl instead of uncons
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


toSortedHeads : WordHeads -> List WordHead
toSortedHeads words =
    Dict.toList words
        |> List.map Tuple.second
        |> List.sortBy .count
        |> List.reverse


toSortedTails : WordTails -> List WordTail
toSortedTails tails =
    Dict.toList tails
        |> List.map Tuple.second
        |> List.sortBy .count
        |> List.reverse


toSortedCharCount : CharCount -> List ( Char, Int )
toSortedCharCount chars =
    Dict.toList chars
        |> List.sortBy Tuple.second
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
            newWordHeads <| String.words <| src
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


viewCharCount : CharCount -> Html never
viewCharCount chars =
    ol []
        (toSortedCharCount chars
            |> List.map
                (\char ->
                    li [] [ text <| toString char ]
                )
        )


viewWordHeads : WordHeads -> Html never
viewWordHeads words =
    ol []
        (toSortedHeads words
            |> List.map
                (\word ->
                    li []
                        [ text <| toString ( word.head, word.count )
                        , viewWordTails word.tails
                        ]
                )
        )


viewWordTails : WordTails -> Html never
viewWordTails tails =
    ol []
        (toSortedTails tails
            |> List.map
                (\{ tail, count } ->
                    li [] [ text <| toString ( tail, count ) ]
                )
        )


view : Corpus -> Html never
view corpus =
    div [ class "corpus-model" ]
        [ div [ class "corpus-chars" ]
            [ h1 [] [ text "Char Count's" ]
            , viewCharCount corpus.chars
            ]
        , div [ class "corpus-lower" ]
            [ h1 [] [ text "Lower Case" ]
            , viewWordHeads corpus.lowerCase
            ]
        , div [ class "corpus-upper" ]
            [ h1 [] [ text "Upper Case" ]
            , viewWordHeads corpus.upperCase
            ]
        , div [ class "corpus-digits" ]
            [ h1 [] [ text "Digit's" ]
            , viewWordHeads corpus.digits
            ]
        , div [ class "corpus-symbols" ]
            [ h1 [] [ text "Symbol's" ]
            , viewWordHeads corpus.symbols
            ]
        , div [ class "corpus-all" ]
            [ h1 [] [ text "All Entries" ]
            , viewWordHeads corpus.all
            ]
        ]
