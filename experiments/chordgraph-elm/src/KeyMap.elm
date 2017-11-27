module KeyMap exposing (..)

import Dict


type alias Coord =
    ( Int, Int )


type Dir
    = W
    | N
    | E
    | S


moveBy : Dir -> Coord -> Coord
moveBy dir ( x, y ) =
    case dir of
        W ->
            ( x - 1, y )

        N ->
            ( x, y + 1 )

        E ->
            ( x + 1, y )

        S ->
            ( x, y - 1 )


type Hand
    = L
    | R


handIndex : Hand -> Int
handIndex hand =
    case hand of
        L ->
            0

        R ->
            1


type Finger
    = Index
    | Middle
    | Ring
    | Pinky


fingerIndex : Finger -> Int
fingerIndex finger =
    case finger of
        Index ->
            0

        Middle ->
            1

        Ring ->
            2

        Pinky ->
            3


type alias KeyInput =
    ( Hand, Finger )


type alias KeyInputIndex =
    ( Int, Int )


keyInputIndex : KeyInput -> KeyInputIndex
keyInputIndex ( hand, finger ) =
    ( handIndex hand, fingerIndex finger )


type UserInput
    = Move Dir
    | Press KeyInput


type alias InputPath =
    List UserInput


type OutputValue
    = Unassigned
    | Char String


type alias KeyLayout =
    { output : OutputValue
    , keys : Dict.Dict KeyInputIndex KeyMap
    }


emptyKeyLayout : KeyLayout
emptyKeyLayout =
    KeyLayout Unassigned Dict.empty


type alias KeyMapGraph =
    Dict.Dict Coord KeyLayout


type KeyMap
    = Empty
    | Output OutputValue
    | Layout KeyLayout
    | Graph KeyMapGraph


insertKeyMap : InputPath -> KeyMap -> KeyMap -> KeyMap
insertKeyMap path value map =
    case path of
        [] ->
            value

        action :: path ->
            case action of
                Move dir ->
                    let
                        location =
                            moveBy dir ( 0, 0 )
                    in
                        case map of
                            Empty ->
                                insertKeyMap (action :: path) value (Graph Dict.empty)

                            Output output ->
                                insertKeyMapLayoutNode ( 0, 0 ) [] (KeyLayout output Dict.empty) Dict.empty
                                    |> Graph
                                    |> insertKeyMap (action :: path) value

                            Layout layout ->
                                insertKeyMapLayoutNode ( 0, 0 ) [] layout Dict.empty
                                    |> Graph
                                    |> insertKeyMap (action :: path) value

                            Graph graph ->
                                map

                Press key ->
                    case map of
                        Empty ->
                            insertKeyMapAtKey key path value emptyKeyLayout
                                |> Layout

                        Output output ->
                            insertKeyMapAtKey key path value (KeyLayout output Dict.empty)
                                |> Layout

                        Layout layout ->
                            insertKeyMapAtKey key path value layout
                                |> Layout

                        Graph graph ->
                            let
                                updatedLayout =
                                    Dict.get ( 0, 0 ) graph
                                        |> Maybe.withDefault emptyKeyLayout
                                        |> insertKeyMapAtKey key path value
                            in
                                Dict.insert ( 0, 0 ) updatedLayout graph
                                    |> Graph


insertKeyLayout : InputPath -> KeyLayout -> KeyMap -> KeyMap
insertKeyLayout path layout map =
    case path of
        [] ->
            case map of
                Empty ->
                    Layout layout

                Output _ ->
                    Layout layout

                Layout _ ->
                    Layout layout

                Graph graph ->
                    Graph (insertKeyMapLayoutNode ( 0, 0 ) [] layout graph)

        action :: path ->
            case action of
                Move dir ->
                    let
                        location =
                            moveBy dir ( 0, 0 )
                    in
                        case map of
                            Empty ->
                                insertKeyMapLayoutNode location path layout Dict.empty
                                    |> Graph

                            Output value ->
                                Dict.insert ( 0, 0 ) (KeyLayout value Dict.empty) Dict.empty
                                    |> insertKeyMapLayoutNode location path layout
                                    |> Graph

                            Layout origin ->
                                Dict.insert ( 0, 0 ) origin Dict.empty
                                    |> insertKeyMapLayoutNode location path layout
                                    |> Graph

                            Graph graph ->
                                insertKeyMapLayoutNode location path layout graph
                                    |> Graph

                Press key ->
                    case map of
                        Empty ->
                            emptyKeyLayout
                                |> insertKeyMapAtKey key path (Layout layout)
                                |> Layout

                        Output value ->
                            KeyLayout value Dict.empty
                                |> insertKeyMapAtKey key path (Layout layout)
                                |> Layout

                        Layout layout ->
                            layout
                                |> insertKeyMapAtKey key path (Layout layout)
                                |> Layout

                        Graph graph ->
                            insertKeyMapLayoutNode ( 0, 0 ) path layout graph
                                |> Graph


insertKeyMapNode : Coord -> InputPath -> KeyMap -> KeyMapGraph -> KeyMapGraph
insertKeyMapNode loc path value graph =
    case value of
        Layout layout ->
            insertKeyMapLayoutNode loc path layout graph

        _ ->
            case path of
                [] ->
                    let
                        updatedLayout =
                            Dict.get loc graph
                                |> Maybe.withDefault emptyKeyLayout
                                -- TODO: Have a sane default for inserting here? Maybe ALL indexes?
                                |> insertKeyMapAtKey ( R, Index ) [] value
                    in
                        Dict.insert loc updatedLayout graph

                action :: path ->
                    case action of
                        Move dir ->
                            insertKeyMapNode (moveBy dir loc) path value graph

                        Press key ->
                            let
                                updatedLayout =
                                    Dict.get loc graph
                                        |> Maybe.withDefault emptyKeyLayout
                                        |> insertKeyMapAtKey key path value
                            in
                                Dict.insert loc updatedLayout graph


insertKeyMapLayoutNode : Coord -> InputPath -> KeyLayout -> KeyMapGraph -> KeyMapGraph
insertKeyMapLayoutNode loc path layout graph =
    case path of
        [] ->
            Dict.insert loc layout graph

        action :: path ->
            case action of
                Move dir ->
                    insertKeyMapLayoutNode (moveBy dir loc) path layout graph

                Press key ->
                    let
                        updatedLayout =
                            Dict.get loc graph
                                |> Maybe.withDefault emptyKeyLayout
                                |> insertKeyMapAtKey key path (Layout layout)
                    in
                        Dict.insert loc updatedLayout graph


insertKeyMapAtKey : KeyInput -> InputPath -> KeyMap -> KeyLayout -> KeyLayout
insertKeyMapAtKey press path value layout =
    let
        index =
            keyInputIndex press
    in
        case path of
            [] ->
                { layout | keys = Dict.insert index value layout.keys }

            _ :: _ ->
                let
                    updatedKeyMap =
                        Dict.get index layout.keys
                            |> Maybe.withDefault Empty
                            |> insertKeyMap path value
                in
                    { layout | keys = Dict.insert index updatedKeyMap layout.keys }


getKeyMapForPath : InputPath -> KeyMap -> KeyMap
getKeyMapForPath path map =
    case path of
        [] ->
            map

        action :: path ->
            case action of
                Move dir ->
                    map

                Press key ->
                    map


getKeyMapByCoord : Coord -> InputPath -> KeyMap -> KeyMap
getKeyMapByCoord loc path map =
    case map of
        Graph graph ->
            case path of
                [] ->
                    case Dict.get loc graph of
                        Just layout ->
                            Layout layout

                        Nothing ->
                            map

                action :: path ->
                    case action of
                        Move dir ->
                            getKeyMapByCoord (moveBy dir loc) path map

                        Press key ->
                            case Dict.get loc graph of
                                Just layout ->
                                    getKeyMapAtKey key path layout

                                Nothing ->
                                    map

        _ ->
            map


getKeyMapAtKey : KeyInput -> InputPath -> KeyLayout -> KeyMap
getKeyMapAtKey key path layout =
    let
        map =
            Dict.get (keyInputIndex key) layout.keys
                |> Maybe.withDefault Empty
    in
        case path of
            [] ->
                map

            _ :: _ ->
                getKeyMapForPath path map
