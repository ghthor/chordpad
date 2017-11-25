module Main exposing (..)

import Html exposing (Html, text, div, h1, img, ul, li)
import Html.Attributes exposing (src)
import Keyboard


---- MODEL ----


type OutputValue
    = Unassigned
    | Char String


type Key
    = Held NotePage
    | Open NotePage


type alias HandLayout =
    ( Key, Key, Key, Key )


type Hand
    = L
    | R


type Finger
    = Index
    | Middle
    | Ring
    | Pinky


type alias UserInput =
    ( Hand, Finger )


type Dir
    = W
    | N
    | E
    | S


type alias MapLayout =
    ( NotePage, NotePage, NotePage, NotePage )


layoutFor : Hand -> KeyLayout -> HandLayout
layoutFor hand { l, r } =
    case hand of
        L ->
            l

        R ->
            r


keyFor : Finger -> HandLayout -> Key
keyFor finger ( index, middle, ring, pinky ) =
    case finger of
        Index ->
            index

        Middle ->
            middle

        Ring ->
            ring

        Pinky ->
            pinky


keyForInput : Hand -> Finger -> KeyLayout -> Key
keyForInput hand finger layout =
    layout
        |> layoutFor hand
        |> keyFor finger


keybindingFor : Keyboard.KeyCode -> Maybe UserInput
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


pageFor : Dir -> MapLayout -> NotePage
pageFor direction ( w, n, e, s ) =
    case direction of
        W ->
            w

        N ->
            n

        E ->
            e

        S ->
            s


type alias KeyLayout =
    { l : HandLayout
    , r : HandLayout
    }


type NotePage
    = Empty
    | Output OutputValue
    | Simple
        { output : OutputValue
        , layout : KeyLayout
        }
    | Location
        { map : MapLayout
        , output : OutputValue
        , layout : KeyLayout
        }


pageOutput : NotePage -> OutputValue
pageOutput page =
    case page of
        Empty ->
            Unassigned

        Output value ->
            value

        Simple page ->
            page.output

        Location page ->
            page.output


keyOutput : Key -> OutputValue
keyOutput key =
    case key of
        Held note ->
            pageOutput note

        Open note ->
            pageOutput note


char : String -> Key
char c =
    Open (Output (Char c))


rootPage =
    Simple
        { output = Unassigned
        , layout =
            { l = ( char "a", char "s", char "d", char "f" )
            , r = ( char "j", char "k", char "l", char ";" )
            }
        }


type alias Model =
    { root : NotePage, current : NotePage, keys : List Keyboard.KeyCode }


init : ( Model, Cmd Msg )
init =
    ( { root = rootPage, current = rootPage, keys = [] }, Cmd.none )



---- UPDATE ----


type Msg
    = NoOp
    | KeyDown Keyboard.KeyCode
    | KeyUp Keyboard.KeyCode


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


viewCodes : List Keyboard.KeyCode -> Html msg
viewCodes codes =
    codes
        |> List.map toString
        |> String.join ", "
        |> text


viewUserInput : List Keyboard.KeyCode -> Html msg
viewUserInput codes =
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
        , viewUserInput model.keys
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
