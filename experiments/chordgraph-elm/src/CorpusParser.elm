module CorpusParser exposing (..)

import Dict


type Section
    = Start
    | Seq
    | End


type alias Corpus =
    Dict.Dict Char (List String)


insertWord : String -> Corpus -> Corpus
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


create : List String -> Corpus
create words =
    List.foldl insertWord Dict.empty words


toSortedList : Corpus -> List ( Char, List String )
toSortedList corpus =
    Dict.toList corpus
        |> List.sortBy (Tuple.second >> List.length)
