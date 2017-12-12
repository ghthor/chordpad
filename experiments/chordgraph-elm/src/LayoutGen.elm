module LayoutGen exposing (..)

import KeyMap exposing (..)
import Corpus
import Dict


standardKeyPriority : List KeyInput
standardKeyPriority =
    [ ( R, Index )
    , ( L, Index )
    , ( R, Middle )
    , ( L, Middle )
    , ( R, Ring )
    , ( L, Ring )
    , ( R, Pinky )
    , ( L, Pinky )
    ]


digitKeyPriority : List KeyInput
digitKeyPriority =
    [ ( L, Pinky )
    , ( L, Ring )
    , ( L, Middle )
    , ( L, Index )
    , ( R, Index )
    , ( R, Middle )
    , ( R, Ring )
    , ( R, Pinky )
    ]


standardNodePriority : List Coord
standardNodePriority =
    [ origin
    , ( -1, 0 )
    , ( 1, 0 )
    , ( 0, -1 )
    , ( -2, 0 )
    , ( 2, 0 )
    , ( 0, -2 )
    , ( -2, -1 )
    , ( 2, -1 )
    ]


digitLayout : List Char -> Keys
digitLayout chars =
    List.map (\c -> OutputDigit c) chars
        |> List.map2 (,) digitKeyPriority
        |> List.foldl
            (\( key, output ) keys ->
                Dict.insert (keyInputIndex key) (KeyOutput output) keys
            )
            Dict.empty


lowerDigits : Keys
lowerDigits =
    digitLayout [ '0', '1', '2', '3', '4', '5', '6', '7' ]


upperDigits : Keys
upperDigits =
    digitLayout [ '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' ]


matchingKeyInput : KeyInput -> KeyInput -> Bool
matchingKeyInput a b =
    (keyInputIndex a) == (keyInputIndex b)


partitionWordHeads : Int -> List Corpus.WordHead -> List (List Corpus.WordHead) -> List (List Corpus.WordHead)
partitionWordHeads size words parts =
    case words of
        [] ->
            parts

        _ ->
            List.take size words :: partitionWordHeads size (List.drop size words) parts


generateRootLayouts : List Corpus.WordHead -> List Keys
generateRootLayouts =
    generateLayouts standardKeyPriority


generateLayouts : List KeyInput -> List Corpus.WordHead -> List Keys
generateLayouts availableKeys words =
    let
        headsPerLayout =
            List.length availableKeys
    in
        partitionWordHeads headsPerLayout words []
            |> List.map (generateLayout availableKeys)


generateLayout : List KeyInput -> List Corpus.WordHead -> Keys
generateLayout availableKeys words =
    List.map2 (,) availableKeys words
        |> List.map (generateKey availableKeys)
        |> List.foldl
            (\( input, key ) keys ->
                Dict.insert (keyInputIndex input) key keys
            )
            Dict.empty


generateKey : List KeyInput -> ( KeyInput, Corpus.WordHead ) -> ( KeyInput, Key )
generateKey availableKeys =
    case availableKeys of
        [ input ] ->
            (\( input, word ) ->
                -- TODO OutputString the whole Tail
                ( input, KeyOutput <| OutputChar word.head )
            )

        _ ->
            (\( input, word ) ->
                let
                    remainingKeys =
                        List.filter (matchingKeyInput input >> not) availableKeys
                in
                    ( input
                    , generateKeyWithTails remainingKeys word
                    )
            )


generateKeyWithTails : List KeyInput -> Corpus.WordHead -> Key
generateKeyWithTails availableKeys word =
    case word.tails |> Corpus.toWordHeads |> Corpus.toSortedHeads of
        [] ->
            KeyOutput <| OutputChar word.head

        tails ->
            tails
                |> generateLayouts availableKeys
                |> generateLayer standardNodePriority
                |> Path (OutputChar word.head)


generateLayer : List Coord -> List Keys -> GraphLayer
generateLayer locations layouts =
    insertLayouts locations layouts Dict.empty


insertLayouts : List Coord -> List Keys -> GraphLayer -> GraphLayer
insertLayouts locations layouts layer =
    List.map2 (,) locations layouts
        |> List.foldl
            (\( loc, layout ) layer ->
                Dict.insert loc (Layout layout) layer
            )
            layer


generateRootLayer : Corpus.Corpus -> GraphLayer
generateRootLayer corpus =
    Dict.empty
        |> insertDigitLayers
        |> insertLowerCaseAndSymbols corpus


insertDigitLayers : GraphLayer -> GraphLayer
insertDigitLayers layer =
    [ ( ( 0, 1 ), lowerDigits )
    , ( ( 1, 1 ), upperDigits )
    ]
        |> List.foldl
            (\( loc, keys ) layer ->
                Dict.insert loc (Layout keys) layer
            )
            layer


insertLowerCaseAndSymbols : Corpus.Corpus -> GraphLayer -> GraphLayer
insertLowerCaseAndSymbols corpus layer =
    corpus
        |> Corpus.toLowerCaseAndSymbolsSortedByCharCount
        |> generateRootLayouts
        |> (\layouts -> insertLayouts standardNodePriority layouts layer)
