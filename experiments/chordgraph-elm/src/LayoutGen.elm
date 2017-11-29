module LayoutGen exposing (generateStarGraph)

import KeyMap exposing (..)
import Dict


type MapSize
    = OneByOne
    | ThreeByThree
    | FiveByFive


type CellType
    = E -- Empty
    | L -- Layout
    | O -- Output


type alias CellRow =
    List CellType


type alias CellMap =
    List CellRow


starGraph : CellMap
starGraph =
    [ [ E, E, E, E, E ]
    , [ E, E, L, E, E ]
    , [ E, L, L, L, E ]
    , [ E, E, L, E, E ]
    , [ E, E, E, E, E ]
    ]


softEdgeStarGraph : CellMap
softEdgeStarGraph =
    [ [ E, E, O, E, E ]
    , [ E, O, L, O, E ]
    , [ O, L, L, L, O ]
    , [ E, O, L, O, E ]
    , [ E, E, O, E, E ]
    ]


generateStarGraph : GraphLayer
generateStarGraph =
    generateGraphByCells starGraph


generateGraphByCells : CellMap -> GraphLayer
generateGraphByCells cells =
    genByCol ( -2, 2 ) cells Dict.empty
        |> Atlas


genByCol : Coord -> CellMap -> AtlasDict -> AtlasDict
genByCol tl col map =
    case col of
        [] ->
            map

        row :: rest ->
            genByRow tl row map
                |> genByCol (moveS tl) rest


genByRow : Coord -> CellRow -> AtlasDict -> AtlasDict
genByRow loc row map =
    case row of
        [] ->
            map

        cell :: rest ->
            insertCell loc cell map
                |> genByRow (moveE loc) rest


insertCell : Coord -> CellType -> AtlasDict -> AtlasDict
insertCell loc cell map =
    case (nodeForCell cell) of
        Just cell ->
            Dict.insert loc cell map

        Nothing ->
            map


nodeForCell : CellType -> Maybe GraphNode
nodeForCell cell =
    case cell of
        E ->
            Nothing

        L ->
            Just (Layout Dict.empty)

        O ->
            Just (NodeOutput Unassigned)
