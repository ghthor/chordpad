module LayoutGen exposing (..)

import KeyMap exposing (..)
import Corpus
import Dict
import Char


type Cell
    = Coord


generateLayerUsingCharCounts : Corpus.CharCount -> GraphLayer
generateLayerUsingCharCounts chars =
    chars
        |> Corpus.toSortedCharCount
        |> List.map
            (\( char, count ) ->
                Char <| String.fromChar char
            )
        |> createLayerWithOutputs


createLayerWithOutputs : List OutputValue -> GraphLayer
createLayerWithOutputs outputs =
    insertLayoutsWithOutputs
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
        outputs
        Dict.empty


insertLayoutsWithOutputs : List Coord -> List OutputValue -> GraphLayer -> GraphLayer
insertLayoutsWithOutputs locations outputs layer =
    case locations of
        [] ->
            layer

        location :: locations ->
            case outputs of
                [] ->
                    layer

                _ ->
                    layer
                        |> Dict.insert location (Layout <| layoutWithOutputs <| List.take 8 outputs)
                        |> insertLayoutsWithOutputs locations (List.drop 8 outputs)


layoutWithOutputs : List OutputValue -> Keys
layoutWithOutputs outputs =
    List.map2 (,)
        [ ( R, Index )
        , ( L, Index )
        , ( R, Middle )
        , ( L, Middle )
        , ( R, Ring )
        , ( L, Ring )
        , ( R, Pinky )
        , ( L, Pinky )
        ]
        outputs
        |> List.foldl
            (\( key, output ) keys ->
                Dict.insert (keyInputIndex key) (KeyOutput output) keys
            )
            Dict.empty
