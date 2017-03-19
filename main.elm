import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import List
import Task


main =
    Html.program
      { init = init
      , view = view
      , update = update
      , subscriptions = \_ -> Sub.none
      }


type alias Tap =
    { address : String
    , id : Maybe Int
    , label : String
    , portNumber : Int
    }


type alias Model =
    { endpoints : (List String)
    , newTap : Tap
    , tap : Tap
    , wat : String
    }


emptyModel : Model
emptyModel =
    { endpoints = []
    , newTap = { address = "", id = Nothing, label = "", portNumber = 0 }
    , tap = { address = "", id = Nothing, label = "", portNumber = 0 }
    , wat = ""
    }


init : (Model, Cmd Msg)
init =
    emptyModel ! []


type Msg
    = NoOp
    | NewTapLabel String
    | NewTapAddress String
    | NewTapPort String
    | CreateTap
    | TapCreated (Result Http.Error Tap)


update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
    case msg of
        NoOp ->
            model ! []

        NewTapLabel label ->
            { model | newTap = updateTap (Just label) Nothing Nothing model.newTap }
                ! []

        NewTapAddress address ->
            { model | newTap = updateTap Nothing (Just address) Nothing model.newTap }
                ! []

        NewTapPort portNumber ->
            { model | newTap = updateTap Nothing Nothing (Just portNumber) model.newTap }
                ! []

        CreateTap ->
            (model, createTap model.newTap)

        TapCreated (Ok tap) ->
            { model | tap = tap }
                ! []

        TapCreated (Err err) ->
            case err of
                Http.BadUrl _ ->
                    model ! []

                Http.Timeout ->
                    model ! []

                Http.NetworkError ->
                    model ! []

                Http.BadStatus aa ->
                    { model | wat = aa.status.message }
                        ! []

                Http.BadPayload first bb ->
                    model ! []


updateTap : Maybe String -> Maybe String -> Maybe String -> Tap -> Tap
updateTap label address portNumber tap =
    { tap
        | label =
            case label of
                Nothing ->
                    tap.label

                Just a ->
                    a

        , address =
            case address of
                Nothing ->
                    tap.address

                Just a ->
                    a

        , portNumber =
            case portNumber of
                Nothing ->
                    tap.portNumber
                Just a ->
                    String.toInt a |> Result.withDefault -1
    }


createTap : Tap -> Cmd Msg
createTap tap =
    let
        body =
            Http.jsonBody <| Encode.object
                [ ("address", Encode.string tap.address)
                , ("port", Encode.int tap.portNumber)
                , ("label", Encode.string tap.label)
                ]

        request =
            Http.post "/tap" body decodeTap
    in
        Http.send TapCreated request


decodeTheThing : Decode.Decoder String
decodeTheThing =
    Decode.at ["derp"] Decode.string


decodeTap : Decode.Decoder Tap
decodeTap =
    Decode.map4 Tap
        (Decode.field "address" Decode.string)
        (Decode.field "id" (Decode.nullable Decode.int))
        (Decode.field "label" Decode.string)
        (Decode.field "port" Decode.int)


view : Model -> Html Msg
view model =
    div
        []
        [ h1 [] [ text "scope" ]
        , input [ placeholder "Label", onInput NewTapLabel ] []
        , input [ placeholder "URL", onInput NewTapAddress ] []
        , input [ placeholder "Port", onInput NewTapPort ] []
        , button [ onClick CreateTap ] [ text "Create Tap" ]
        , text model.tap.address
        , text (toString model.tap.portNumber)
        , text (toString model.tap.id)
        , text model.tap.label
        , text model.wat
        ]
