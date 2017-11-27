module Main exposing (..)

import KeyMap exposing (..)
import Dict
import Html exposing (Html, text, div, h1, img, ul, li)
import Html.Attributes exposing (src)
import Keyboard


---- MODEL ----


type alias User =
    { output : List OutputValue
    , path : InputPath
    }


type alias Model =
    { root : KeyMap
    , user : User
    , keys : List Keyboard.KeyCode
    }


init : ( Model, Cmd Msg )
init =
    ( { root = Graph Dict.empty, user = User [] [], keys = [] }, Cmd.none )



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
            ( { model | keys = code :: model.keys }, Cmd.none )

        KeyUp code ->
            let
                keys =
                    model.keys
                        |> List.filter (\c -> c /= code)
            in
                ( { model | keys = keys }, Cmd.none )

        SetKeyMap keyMap ->
            case model.user.path of
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


viewCodes : List Keyboard.KeyCode -> Html msg
viewCodes codes =
    codes
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
    div []
        [ img [ src "/logo.svg" ] []
        , h1 [] [ text "Your Elm App is working!" ]
        , viewCodes model.keys
        , viewKeyInput model.keys
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
