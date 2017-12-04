module KeyMap exposing (..)

import Dict


type alias Coord =
    ( Int, Int )


origin : Coord
origin =
    ( 0, 0 )


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


moveList : List Dir -> Coord -> Coord
moveList dirs loc =
    case dirs of
        [] ->
            loc

        dir :: dirs ->
            moveList dirs <| moveBy dir loc


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


handFromIndex : Int -> Hand
handFromIndex index =
    case index of
        0 ->
            L

        _ ->
            R


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


fingerFromIndex : Int -> Finger
fingerFromIndex index =
    case index of
        0 ->
            Index

        1 ->
            Middle

        2 ->
            Ring

        _ ->
            Pinky


type alias KeyInput =
    ( Hand, Finger )


type alias KeyInputIndex =
    ( Int, Int )


keyInputIndex : KeyInput -> KeyInputIndex
keyInputIndex ( hand, finger ) =
    ( handIndex hand, fingerIndex finger )


keyInputForIndex : KeyInputIndex -> KeyInput
keyInputForIndex ( hand, finger ) =
    ( handFromIndex hand, fingerFromIndex finger )


type UserInput
    = Move Dir
    | Press KeyInput


type alias UserInputs =
    List UserInput


toKeyInput : UserInput -> Maybe KeyInput
toKeyInput input =
    case input of
        Press key ->
            Just key

        Move _ ->
            Nothing


keyInputExistsIn : UserInputs -> KeyInput -> Bool
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


type alias GraphLayer =
    Dict.Dict Coord GraphNode


getOutputValueForPath : UserInputs -> GraphLayer -> OutputValue
getOutputValueForPath path layer =
    case path of
        [] ->
            -- TODO
            Unassigned

        (Move dir) :: path ->
            getOutputValueAt (moveBy dir ( 0, 0 )) path layer

        (Press key) :: path ->
            -- TODO
            Unassigned


getOutputValueAt : Coord -> UserInputs -> GraphLayer -> OutputValue
getOutputValueAt loc path layer =
    -- TODO
    Unassigned


getOutputValueAtKey : KeyInput -> UserInputs -> Keys -> OutputValue
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


getNodeWithMoveList : GraphLayer -> List Dir -> Maybe ( List Dir, GraphNode )
getNodeWithMoveList layer path =
    case getNodeByMoveList layer path of
        Just node ->
            Just ( path, node )

        Nothing ->
            Nothing


getNodeByMoveList : GraphLayer -> List Dir -> Maybe GraphNode
getNodeByMoveList layer path =
    getNodeAt ( 0, 0 ) path layer


getNodeAt : Coord -> List Dir -> GraphLayer -> Maybe GraphNode
getNodeAt loc path layer =
    case path of
        [] ->
            case Dict.get loc layer of
                Just node ->
                    Just node

                Nothing ->
                    Nothing

        dir :: path ->
            getNodeAt (moveBy dir loc) path layer


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


getNodesByViewPort : ( Coord, ViewPortSize ) -> GraphLayer -> List (List ( Coord, Maybe GraphNode ))
getNodesByViewPort ( origin, size ) layer =
    layerViewPort origin size
        |> List.map
            (\row ->
                row
                    |> List.map
                        (\loc ->
                            ( loc, Dict.get loc layer )
                        )
            )
