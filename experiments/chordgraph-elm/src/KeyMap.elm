module KeyMap exposing (..)

import Dict


type alias Coord =
    ( Int, Int )


dist : Coord -> Coord -> Int
dist ( a_x, a_y ) ( b_x, b_y ) =
    abs (b_x - a_x) + abs (b_y - a_y)


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


moveE : Coord -> Coord
moveE loc =
    moveBy E loc


moveS : Coord -> Coord
moveS loc =
    moveBy S loc


moveByN : Int -> Dir -> Coord -> Coord
moveByN mult dir loc =
    case mult of
        0 ->
            loc

        _ ->
            moveBy dir loc
                |> moveByN (mult - 1) dir


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


toKeyInput : UserInput -> Maybe KeyInput
toKeyInput input =
    case input of
        Press key ->
            Just key

        Move _ ->
            Nothing


keyInputExistsIn : InputPath -> KeyInput -> Bool
keyInputExistsIn path key =
    let
        index =
            keyInputIndex key
    in
        path
            |> List.filterMap toKeyInput
            |> List.any (\k -> (keyInputIndex k) == index)


type OutputValue
    = Unassigned
    | Char String


type alias Keys =
    Dict.Dict KeyInputIndex Key


type Key
    = KeyOutput OutputValue
    | Path OutputValue GraphLayer


type GraphNode
    = NodeOutput OutputValue
    | Layout Keys


type alias AtlasDict =
    Dict.Dict Coord GraphNode


type GraphLayer
    = Simple GraphNode
    | Atlas AtlasDict


atlasInsert : AtlasDict -> Coord -> GraphNode -> AtlasDict
atlasInsert map loc node =
    Dict.insert loc node map


upgradeToAtlas : GraphNode -> AtlasDict
upgradeToAtlas node =
    Dict.insert ( 0, 0 ) node Dict.empty


insertOutputValue : InputPath -> OutputValue -> GraphLayer -> GraphLayer
insertOutputValue path value layer =
    insertOutputValueAt ( 0, 0 ) path value layer


insertOutputValueAt : Coord -> InputPath -> OutputValue -> GraphLayer -> GraphLayer
insertOutputValueAt loc path value layer =
    case path of
        [] ->
            case layer of
                Simple node ->
                    case loc of
                        ( 0, 0 ) ->
                            Simple (NodeOutput value)

                        _ ->
                            upgradeToAtlas node
                                |> insertOutputValueInAtlas loc path value
                                |> Atlas

                Atlas map ->
                    insertOutputValueInAtlas loc path value map
                        |> Atlas

        action :: path ->
            case action of
                Move dir ->
                    case layer of
                        Simple node ->
                            upgradeToAtlas node
                                |> insertOutputValueInAtlas (moveBy dir loc) path value
                                |> Atlas

                        Atlas map ->
                            insertOutputValueInAtlas (moveBy dir loc) path value map
                                |> Atlas

                Press key ->
                    case layer of
                        Simple node ->
                            insertOutputValueAtKey key path value node
                                |> Simple

                        Atlas map ->
                            Dict.get loc map
                                |> Maybe.withDefault (Layout Dict.empty)
                                |> insertOutputValueAtKey key path value
                                |> atlasInsert map loc
                                |> Atlas


insertOutputValueInAtlas : Coord -> InputPath -> OutputValue -> AtlasDict -> AtlasDict
insertOutputValueInAtlas loc path value map =
    case path of
        [] ->
            atlasInsert map loc (NodeOutput value)

        (Move dir) :: path ->
            insertOutputValueInAtlas (moveBy dir loc) path value map

        (Press key) :: path ->
            Dict.get loc map
                |> Maybe.withDefault (Layout Dict.empty)
                |> insertOutputValueAtKey key path value
                |> atlasInsert map loc


insertOutputValueAtKey : KeyInput -> InputPath -> OutputValue -> GraphNode -> GraphNode
insertOutputValueAtKey key path value node =
    case node of
        NodeOutput _ ->
            insertOutputValueAtKey key path value (Layout Dict.empty)

        Layout layout ->
            let
                index =
                    keyInputIndex key

                updatedKey =
                    Dict.get index layout
                        |> insertOutputValueThroughKey path value
            in
                Dict.insert index updatedKey layout
                    |> Layout


insertOutputValueThroughKey : InputPath -> OutputValue -> Maybe Key -> Key
insertOutputValueThroughKey path value key =
    case path of
        [] ->
            case key of
                Just (Path _ layer) ->
                    Path value layer

                _ ->
                    KeyOutput value

        _ :: _ ->
            case key of
                Just (Path output layer) ->
                    insertOutputValue path value layer
                        |> Path output

                Just (KeyOutput output) ->
                    insertOutputValue path value (Simple (NodeOutput value))
                        |> Path output

                _ ->
                    insertOutputValue path value (Simple (NodeOutput value))
                        |> Path Unassigned


getOutputValueForPath : InputPath -> GraphLayer -> OutputValue
getOutputValueForPath path map =
    case path of
        [] ->
            case map of
                Simple (NodeOutput value) ->
                    value

                _ ->
                    Unassigned

        (Move dir) :: path ->
            getOutputValueAt (moveBy dir ( 0, 0 )) path map

        (Press key) :: path ->
            case map of
                Simple (Layout layout) ->
                    getOutputValueAtKey key path layout

                _ ->
                    -- TODO
                    Unassigned


getOutputValueAt : Coord -> InputPath -> GraphLayer -> OutputValue
getOutputValueAt loc path layer =
    -- TODO
    Unassigned


getOutputValueAtKey : KeyInput -> InputPath -> Keys -> OutputValue
getOutputValueAtKey key path layout =
    case path of
        [] ->
            case Dict.get (keyInputIndex key) layout of
                Just (KeyOutput value) ->
                    value

                _ ->
                    -- TODO
                    Unassigned

        _ :: _ ->
            -- TODO
            Unassigned


getNodeWithMoveList : AtlasDict -> List Dir -> Maybe ( List Dir, GraphNode )
getNodeWithMoveList map path =
    case getNodeByMoveList map path of
        Just node ->
            Just ( path, node )

        Nothing ->
            Nothing


getNodeByMoveList : AtlasDict -> List Dir -> Maybe GraphNode
getNodeByMoveList map path =
    getNodeAt ( 0, 0 ) path map


getNodeAt : Coord -> List Dir -> AtlasDict -> Maybe GraphNode
getNodeAt loc path map =
    case path of
        [] ->
            case Dict.get loc map of
                Just node ->
                    Just node

                Nothing ->
                    Nothing

        dir :: path ->
            getNodeAt (moveBy dir loc) path map


layerViewPort : Coord -> ViewPortSize -> List (List Coord)
layerViewPort ( x, y ) size =
    let
        dxy =
            case size of
                ThreeByThree ->
                    1

                FiveByFive ->
                    2

        width =
            (2 * dxy) + 1

        x_range =
            List.range (x - dxy) (x + dxy)

        y_range =
            List.range (y - dxy) (y + dxy)
                |> List.reverse
    in
        y_range
            |> List.map
                (\y ->
                    List.repeat width y
                        |> List.map2 (,) x_range
                )


type ViewPortSize
    = ThreeByThree
    | FiveByFive


getNodesByViewPort : ( Coord, ViewPortSize ) -> AtlasDict -> List (List ( Coord, Maybe GraphNode ))
getNodesByViewPort ( origin, size ) map =
    layerViewPort origin size
        |> List.map
            (\row ->
                row
                    |> List.map
                        (\loc ->
                            ( loc, Dict.get loc map )
                        )
            )
