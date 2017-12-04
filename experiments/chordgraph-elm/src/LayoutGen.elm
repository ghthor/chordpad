module LayoutGen exposing (..)

import KeyMap exposing (..)
import Corpus
import Dict


keyInputsSortedByPriority : List KeyInput
keyInputsSortedByPriority =
    [ ( R, Index )
    , ( L, Index )
    , ( R, Middle )
    , ( L, Middle )
    , ( R, Ring )
    , ( L, Ring )
    , ( R, Pinky )
    , ( L, Pinky )
    ]


matchingKeyInput : KeyInput -> KeyInput -> Bool
matchingKeyInput a b =
    (keyInputIndex a) == (keyInputIndex b)


generateLayerUsingWordHeads : Corpus.WordHeads -> GraphLayer
generateLayerUsingWordHeads words =
    words
        |> Corpus.toSortedHeads
        |> generateLayerForWordHeads keyInputsSortedByPriority


partitionWordHeads : Int -> List Corpus.WordHead -> List (List Corpus.WordHead) -> List (List Corpus.WordHead)
partitionWordHeads size words parts =
    case words of
        [] ->
            parts

        _ ->
            List.take size words :: partitionWordHeads size (List.drop size words) parts


generateLayerForWordHeads : List KeyInput -> List Corpus.WordHead -> GraphLayer
generateLayerForWordHeads availableKeys words =
    let
        headsPerLayout =
            List.length availableKeys
    in
        partitionWordHeads headsPerLayout words []
            |> List.map (generateLayoutForWordHeads availableKeys)
            |> generateLayerFromLayouts


generateLayoutForWordHeads : List KeyInput -> List Corpus.WordHead -> Keys
generateLayoutForWordHeads availableKeys words =
    case availableKeys of
        [ input ] ->
            List.map2 (,) availableKeys words
                |> List.map
                    (\( input, word ) ->
                        -- TODO OutputString the whole Tail
                        ( input, KeyOutput <| OutputChar word.head )
                    )
                |> List.foldl
                    (\( input, key ) keys ->
                        Dict.insert (keyInputIndex input) key keys
                    )
                    Dict.empty

        _ ->
            List.map2 (,) availableKeys words
                |> List.map
                    (\( input, word ) ->
                        let
                            remainingKeys =
                                List.filter (matchingKeyInput input >> not) availableKeys
                        in
                            ( input
                            , word.tails
                                |> Corpus.toWordHeads
                                |> Corpus.toSortedHeads
                                |> generateLayerForWordHeads remainingKeys
                                |> Path (OutputChar word.head)
                            )
                    )
                |> List.foldl
                    (\( input, key ) keys ->
                        Dict.insert (keyInputIndex input) key keys
                    )
                    Dict.empty


generateLayerFromLayouts : List Keys -> GraphLayer
generateLayerFromLayouts layouts =
    List.map2 (,)
        [ origin
        , moveBy W origin
        , moveBy E origin
        , moveBy S origin
        , moveBy N origin
        , moveList [ W, S ] origin
        , moveList [ W, N ] origin
        , moveList [ E, S ] origin
        , moveList [ E, N ] origin
        , moveList [ S, S ] origin
        , moveList [ N, N ] origin
        ]
        layouts
        |> List.foldl
            (\( loc, layout ) layer ->
                Dict.insert loc (Layout layout) layer
            )
            Dict.empty
