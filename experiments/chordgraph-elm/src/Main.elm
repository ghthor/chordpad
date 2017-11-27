module Main exposing (..)

import KeyMap exposing (..)
import Dict
import Set
import Html exposing (Html, button, span, text, div, h1, ul, li)
import Html.Attributes exposing (id, style, class, classList, src)
import Keyboard


---- MODEL ----


keyInputsDisplayOrder : List KeyInput
keyInputsDisplayOrder =
    [ ( L, Pinky )
    , ( L, Ring )
    , ( L, Middle )
    , ( L, Index )
    , ( R, Index )
    , ( R, Middle )
    , ( R, Ring )
    , ( R, Pinky )
    ]


leftHand : List KeyInput
leftHand =
    [ ( L, Pinky )
    , ( L, Ring )
    , ( L, Middle )
    , ( L, Index )
    ]


rightHand : List KeyInput
rightHand =
    [ ( R, Index )
    , ( R, Middle )
    , ( R, Ring )
    , ( R, Pinky )
    ]


keybindingFor : Keyboard.KeyCode -> Maybe KeyInput
keybindingFor code =
    case code of
        65 ->
            Just ( L, Pinky )

        83 ->
            Just ( L, Ring )

        68 ->
            Just ( L, Middle )

        70 ->
            Just ( L, Index )

        74 ->
            Just ( R, Index )

        75 ->
            Just ( R, Middle )

        76 ->
            Just ( R, Ring )

        186 ->
            Just ( R, Pinky )

        _ ->
            Nothing


type alias KeyCodes =
    Set.Set Keyboard.KeyCode


type alias Model =
    { root : KeyMap
    , inputs : InputPath
    , keyCodes : KeyCodes
    }


init : ( Model, Cmd Msg )
init =
    ( { root = Layout emptyKeyLayout
      , inputs = []
      , keyCodes = Set.empty
      }
    , Cmd.none
    )



---- UPDATE ----


type Msg
    = KeyDown Keyboard.KeyCode
    | KeyUp Keyboard.KeyCode
    | SetKeyMap KeyMap
    | NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        KeyDown code ->
            if Set.member code model.keyCodes then
                ( model, Cmd.none )
            else
                let
                    updatedInputs =
                        case keybindingFor code of
                            Just key ->
                                if keyInputExistsIn model.inputs key then
                                    model.inputs
                                else
                                    List.append model.inputs [ Press key ]

                            Nothing ->
                                model.inputs
                in
                    ( { model
                        | keyCodes = Set.insert code model.keyCodes
                        , inputs = updatedInputs
                      }
                    , Cmd.none
                    )

        KeyUp code ->
            let
                updatedInputs =
                    case keybindingFor code of
                        Nothing ->
                            model.inputs

                        Just key ->
                            -- Only clear the inputs if the Key is part of the current set
                            if keyInputExistsIn model.inputs key then
                                []
                            else
                                model.inputs
            in
                ( { model
                    | keyCodes = Set.remove code model.keyCodes
                    , inputs = updatedInputs
                  }
                , Cmd.none
                )

        SetKeyMap keyMap ->
            case model.inputs of
                [] ->
                    ( { model | root = keyMap }, Cmd.none )

                path ->
                    ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )



---- SUBSCRIPTIONS ----


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Keyboard.downs KeyDown
        , Keyboard.ups KeyUp
        ]



---- VIEW ----


viewKeyMap : InputPath -> KeyMap -> Html msg
viewKeyMap inputs map =
    case map of
        Empty ->
            div [] []

        Output value ->
            div [] []

        Layout layout ->
            viewKeyLayout inputs layout

        Graph graph ->
            div [] []


type alias KeyView =
    ( Bool, KeyMap )


toKeyView : InputPath -> KeyLayout -> KeyInput -> KeyView
toKeyView inputs { keys } key =
    ( keyInputExistsIn inputs key
    , Dict.get (keyInputIndex key) keys
        |> Maybe.withDefault Empty
    )


viewKeyLayout : InputPath -> KeyLayout -> Html msg
viewKeyLayout inputs layout =
    div [ class "key-layout" ]
        [ div [ class "left-hand" ]
            (List.map (toKeyView inputs layout) leftHand
                |> List.map viewKey
            )
        , div [ class "right-hand" ]
            (List.map (toKeyView inputs layout) rightHand
                |> List.map viewKey
            )
        ]


viewKey : KeyView -> Html msg
viewKey ( down, key ) =
    case key of
        Empty ->
            viewEmptyKey down

        Output value ->
            case value of
                Unassigned ->
                    viewEmptyKey down

                Char str ->
                    viewKeyButton down str

        _ ->
            viewEmptyKey down


viewEmptyKey : Bool -> Html msg
viewEmptyKey down =
    viewKeyButton down "+"


viewKeyButton : Bool -> String -> Html msg
viewKeyButton down label =
    button
        [ classList
            [ ( "key-box", True )
            , ( "key-down", down )
            ]
        ]
        [ text label ]


viewInputPath : InputPath -> Html msg
viewInputPath path =
    path
        |> List.map toString
        |> List.map text
        |> List.map (\t -> li [] [ t ])
        |> ul []


viewKeyCodes : KeyCodes -> Html msg
viewKeyCodes codes =
    codes
        |> Set.toList
        |> List.map toString
        |> String.join ", "
        |> text


viewKeyInput : List Keyboard.KeyCode -> Html msg
viewKeyInput codes =
    codes
        |> List.filterMap keybindingFor
        |> List.map toString
        |> List.map text
        |> List.map (\t -> li [] [ t ])
        |> ul []


view : Model -> Html Msg
view model =
    div [ id "app" ]
        [ div [ class "key-map-root" ]
            [ viewKeyMap model.inputs model.root ]
        ]



---- PROGRAM ----


main : Program Never Model Msg
main =
    Html.program
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }
