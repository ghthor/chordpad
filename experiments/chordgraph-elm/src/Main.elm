module Main exposing (..)

import KeyMap exposing (..)
import LayoutGen exposing (..)
import Corpus
import Dict
import Set
import Html
    exposing
        ( Html
        , form
        , textarea
        , input
        , button
        , span
        , text
        , div
        , h1
        , ul
        , li
        )
import Html.Attributes
    exposing
        ( id
        , type_
        , style
        , class
        , classList
        , src
        , placeholder
        , value
        , autofocus
        )
import Html.Events exposing (onClick, onInput, onSubmit)
import Keyboard


rawCorpusDefault : String
rawCorpusDefault =
    """
This is useful for holding JSON or other
content that has "quotation marks".
"""


corpusDefault : Corpus.Corpus
corpusDefault =
    Corpus.new rawCorpusDefault



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
    , inputs : UserInputs
    , mode : InputMode
    , rawCorpus : String
    , corpus : Corpus.Corpus
    }


init : ( Model, Cmd Msg )
init =
    ( { keyCodes = Set.empty
      , root = LayoutGen.generateLayerUsingWordHeads corpusDefault.all
      , inputs = []
      , mode = Edit EditCorpus
      , rawCorpus = rawCorpusDefault
      , corpus = corpusDefault
      }
    , Cmd.none
    )



---- UPDATE ----


type InputMode
    = Normal
    | Edit EditMode


type EditMode
    = EditKeyBinding ( UserInputs, OutputValue )
    | EditCorpus


type UpdateGraphMsg
    = UpdateBinding OutputValue
    | UpdateRoot GraphLayer


type Msg
    = KeyDown Keyboard.KeyCode
    | KeyUp Keyboard.KeyCode
    | OpenEditor EditMode
    | UpdateCorpus String
    | UpdateGraph UpdateGraphMsg
    | CloseEditor
    | NoOp


updateCharBinding : String -> Msg
updateCharBinding str =
    UpdateGraph <| UpdateBinding <| OutputString str


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
                | mode = Edit (EditKeyBinding ( path, value ))
                , inputs = path
              }
            , Cmd.none
            )

        EditCorpus ->
            ( { model
                | mode = Edit <| EditCorpus
              }
            , Cmd.none
            )


updateGraph : UpdateGraphMsg -> Model -> ( Model, Cmd Msg )
updateGraph msg model =
    case msg of
        UpdateBinding value ->
            -- TODO Update Graph
            ( { model
                | mode = Edit (EditKeyBinding ( model.inputs, value ))
              }
            , Cmd.none
            )

        UpdateRoot graph ->
            ( { model | root = graph }, Cmd.none )


updateCorpus : String -> Model -> ( Model, Cmd Msg )
updateCorpus str model =
    let
        corpus =
            Corpus.new str
    in
        ( { model
            | rawCorpus = str
            , corpus = corpus
            , root = LayoutGen.generateLayerUsingWordHeads corpus.all
          }
        , Cmd.none
        )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        KeyDown code ->
            updateKeyDown code model

        KeyUp code ->
            updateKeyUp code model

        OpenEditor mode ->
            openEditor mode model

        UpdateCorpus str ->
            updateCorpus str model

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

                Edit EditCorpus ->
                    -- TODO Start a Graph update Task
                    ( { model
                        | keyCodes = Set.empty
                        , mode = Normal
                        , inputs = []
                      }
                    , Cmd.none
                    )

                _ ->
                    -- TODO Panic?
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
        (viewGraphLayer model.inputs <|
            getLayerByInputs origin model.inputs model.root
        )


viewGraphLayer : UserInputs -> GraphLayer -> List (Html Msg)
viewGraphLayer inputs layer =
    let
        origin =
            ( 0, 0 )

        user =
            ( origin
            , inputs
            )
    in
        getNodesByViewPort ( origin, KeyMap.FiveByFive ) layer
            |> List.map
                (\row ->
                    div [ class "graph-row" ]
                        (row
                            |> List.map (viewGraphNodeLocation user)
                        )
                )


viewGraphNodeLocation : ( Coord, UserInputs ) -> ( Coord, Maybe GraphNode ) -> Html Msg
viewGraphNodeLocation user node =
    case node of
        ( loc, Just node ) ->
            viewGraphNode user ( loc, node )

        ( loc, Nothing ) ->
            div [ class "graph-node" ] [ text (toString loc), text "TODO: Empty Location" ]


viewGraphNode : ( Coord, UserInputs ) -> ( Coord, GraphNode ) -> Html Msg
viewGraphNode ( origin, inputs ) node =
    case node of
        ( loc, Layout layout ) ->
            div
                [ classList
                    [ ( "graph-node", True )
                    , ( "key-layout", True )
                    ]
                ]
                ((text (toString loc))
                    :: (viewKeys inputs layout)
                )


type alias KeyView =
    { down : Bool
    , openEdit : Msg
    , label : String
    }


keyLabel : Keys -> KeyInput -> String
keyLabel layout key =
    case Dict.get (keyInputIndex key) layout of
        Just key ->
            labelForKey key

        Nothing ->
            ""


labelForKey : Key -> String
labelForKey key =
    case key of
        KeyOutput value ->
            labelForOutputValue value

        Path outputValue _ ->
            labelForOutputValue outputValue


labelForOutputValue : OutputValue -> String
labelForOutputValue value =
    case value of
        OutputString str ->
            str

        OutputChar ch ->
            String.fromChar ch

        Unassigned ->
            ""


viewKeys : UserInputs -> Keys -> List (Html Msg)
viewKeys inputs layout =
    [ ( leftHand, "left-hand" ), ( rightHand, "right-hand" ) ]
        |> (List.map
                (\( hand, handView ) ->
                    div [ class handView ]
                        (hand
                            |> List.map
                                (\key ->
                                    (viewKey
                                        { down = keyInputExistsIn inputs key
                                        , openEdit = NoOp
                                        , label = keyLabel layout key
                                        }
                                    )
                                )
                        )
                )
           )


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
                OutputString str ->
                    str

                OutputChar ch ->
                    String.fromChar ch

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


viewCorpusEditor : { rawCorpus : String, corpus : Corpus.Corpus } -> Html Msg
viewCorpusEditor { rawCorpus, corpus } =
    form [ class "corpus-editor", onSubmit CloseEditor ]
        [ textarea
            [ onInput UpdateCorpus ]
            [ text rawCorpus ]
        , div [] [ button [ type_ "submit" ] [ text "Done" ] ]
        , Corpus.view corpus
        ]


viewUserInputs : UserInputs -> Html msg
viewUserInputs path =
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
    div [ id "app" ] <|
        case model.mode of
            Normal ->
                [ viewGraphLayerRoot model
                , div
                    [ class "control-panel" ]
                    [ button [ onClick <| OpenEditor <| EditCorpus ]
                        [ text "Open Editor" ]
                    ]
                ]

            Edit (EditKeyBinding ( _, value )) ->
                [ viewBindingDialog value ]

            Edit EditCorpus ->
                [ viewCorpusEditor { rawCorpus = model.rawCorpus, corpus = model.corpus } ]



---- PROGRAM ----


main : Program Never Model Msg
main =
    Html.program
        { view = view
        , init = init
        , update = update
        , subscriptions = subscriptions
        }
