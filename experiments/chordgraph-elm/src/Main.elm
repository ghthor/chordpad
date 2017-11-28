module Main exposing (..)

import KeyMap exposing (..)
import Dict
import Set
import Html exposing (Html, form, input, button, span, text, div, h1, ul, li)
import Html.Attributes exposing (id, type_, style, class, classList, src, placeholder, value, autofocus)
import Html.Events exposing (onClick, onInput, onSubmit)
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
    { keyCodes : KeyCodes
    , root : GraphLayer
    , inputs : InputPath
    , mode : InputMode
    }


init : ( Model, Cmd Msg )
init =
    ( { keyCodes = Set.empty
      , root = Simple (Layout Dict.empty)
      , inputs = []
      , mode = Normal
      }
    , Cmd.none
    )



---- UPDATE ----


type InputMode
    = Normal
    | Edit EditMode


type EditMode
    = EditKeyBinding ( InputPath, OutputValue )
    | EditCorpus


type UpdateGraphMsg
    = UpdateBinding OutputValue
    | UpdateRoot GraphLayer


type Msg
    = KeyDown Keyboard.KeyCode
    | KeyUp Keyboard.KeyCode
    | OpenEditor EditMode
    | UpdateGraph UpdateGraphMsg
    | CloseEditor
    | NoOp


updateCharBinding : String -> Msg
updateCharBinding str =
    UpdateGraph (UpdateBinding (Char str))


updateKeyDown : Keyboard.KeyCode -> Model -> ( Model, Cmd Msg )
updateKeyDown code model =
    case model.mode of
        Edit _ ->
            ( model, Cmd.none )

        Normal ->
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


updateKeyUp : Keyboard.KeyCode -> Model -> ( Model, Cmd Msg )
updateKeyUp code model =
    case model.mode of
        Edit _ ->
            ( model, Cmd.none )

        Normal ->
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


openEditor : EditMode -> Model -> ( Model, Cmd Msg )
openEditor msg model =
    case msg of
        EditKeyBinding ( path, value ) ->
            ( { model
                | mode = Edit (EditKeyBinding ( path, getOutputValueForPath path model.root ))
                , inputs = path
              }
            , Cmd.none
            )

        EditCorpus ->
            -- TODO
            ( model, Cmd.none )


updateGraph : UpdateGraphMsg -> Model -> ( Model, Cmd Msg )
updateGraph msg model =
    case msg of
        UpdateBinding value ->
            ( { model
                | mode = Edit (EditKeyBinding ( model.inputs, value ))
                , root = insertOutputValue model.inputs value model.root
              }
            , Cmd.none
            )

        UpdateRoot graph ->
            ( { model | root = graph }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        KeyDown code ->
            updateKeyDown code model

        KeyUp code ->
            updateKeyUp code model

        OpenEditor mode ->
            openEditor mode model

        UpdateGraph msg ->
            updateGraph msg model

        CloseEditor ->
            case model.mode of
                Edit (EditKeyBinding _) ->
                    ( { model
                        | keyCodes = Set.empty
                        , mode = Normal
                        , inputs = []
                      }
                    , Cmd.none
                    )

                _ ->
                    -- TODO
                    ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )



---- SUBSCRIPTIONS ----


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.mode of
        Edit _ ->
            Sub.none

        Normal ->
            Sub.batch
                [ Keyboard.downs KeyDown
                , Keyboard.ups KeyUp
                ]



---- VIEW ----


viewGraphLayerRoot : Model -> Html Msg
viewGraphLayerRoot model =
    div [ class "key-map-root" ]
        [ viewGraphLayer model.inputs model.root ]


viewGraphLayer : InputPath -> GraphLayer -> Html Msg
viewGraphLayer inputs map =
    case map of
        Simple (Layout layout) ->
            viewKeys inputs layout

        _ ->
            div [] []


type alias KeyView =
    { down : Bool
    , openEdit : Msg
    , label : String
    }


keyLabel : Keys -> KeyInput -> String
keyLabel layout key =
    case Dict.get (keyInputIndex key) layout of
        Just (KeyOutput (Char str)) ->
            str

        _ ->
            "+"


toKeyView : InputPath -> Keys -> KeyInput -> KeyView
toKeyView inputs layout key =
    -- FIXME Use Existing OutputValue instead of Unassigned in openEdit msg
    { down = keyInputExistsIn inputs key
    , openEdit = OpenEditor (EditKeyBinding ( List.append inputs [ Press key ], Unassigned ))
    , label = keyLabel layout key
    }


viewKeys : InputPath -> Keys -> Html Msg
viewKeys inputs layout =
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


viewKey : KeyView -> Html Msg
viewKey { down, openEdit, label } =
    button
        [ classList
            [ ( "key-box", True )
            , ( "key-down", down )
            ]
        , onClick openEdit
        ]
        [ text label ]


viewBindingDialog : OutputValue -> Html Msg
viewBindingDialog output =
    let
        currentValue =
            case output of
                Char str ->
                    str

                _ ->
                    ""
    in
        -- FIXME Focus see: https://stackoverflow.com/questions/31901397/how-to-set-focus-on-an-element-in-elm
        form [ class "key-map-binding-dialog", onSubmit CloseEditor ]
            [ input
                [ type_ "text"
                , autofocus True
                , placeholder "Enter a Value"
                , value currentValue
                , onInput updateCharBinding
                ]
                []
            , button [ type_ "submit" ] [ text "Done" ]
            ]


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
        [ case model.mode of
            Normal ->
                viewGraphLayerRoot model

            Edit (EditKeyBinding ( _, value )) ->
                viewBindingDialog value

            Edit EditCorpus ->
                viewGraphLayerRoot model
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
