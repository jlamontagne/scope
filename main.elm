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
    , newTapLabel : Maybe String
    , newTapAddress : Maybe String
    , newTapPort : Maybe Int
    , tap : Tap
    , error : Maybe String
    }


emptyModel : Model
emptyModel =
    { endpoints = []
    , newTapLabel = Nothing
    , newTapAddress = Nothing
    , newTapPort = Nothing
    , tap = { address = "", id = Nothing, label = "", portNumber = 0 }
    , error = Nothing
    }


init : (Model, Cmd Msg)
init =
    emptyModel ! []


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
            { model | newTapLabel = Just label }
                ! []

        NewTapAddress address ->
            { model | newTapAddress = Just address }
                ! []

        NewTapPort portNumberStr ->
            { model | newTapPort =
                String.toInt portNumberStr
                |> Result.map Just
                |> Result.withDefault Nothing
            }
                ! []

        CreateTap ->
            let
                address =
                    Maybe.map Encode.string model.newTapAddress
                        |> Maybe.withDefault Encode.null

                portNumber =
                    Maybe.map Encode.int model.newTapPort
                        |> Maybe.withDefault Encode.null

                label =
                    Maybe.map Encode.string model.newTapLabel
                        |> Maybe.withDefault Encode.null

                body =
                    Http.jsonBody <| Encode.object
                        [ ("address", address)
                        , ("port", portNumber)
                        , ("label", label)
                        ]

                request =
                    Http.post "/tap" body decodeTap
            in
                (model, Http.send TapCreated request)

        TapCreated (Ok tap) ->
            { model
                | tap = tap
                , error = Nothing
            }
                ! []

        TapCreated (Err err) ->
            case err of
                Http.BadUrl _ ->
                    model ! []

                Http.Timeout ->
                    model ! []

                Http.NetworkError ->
                    model ! []

                Http.BadStatus response ->
                    { model | error = Just response.status.message }
                        ! []

                Http.BadPayload first bb ->
                    model ! []


view : Model -> Html Msg
view model =
    div
        []
        [ h1 [] [ text "scope" ]
        , viewCreateTap model
        ]

viewCreateTap : Model -> Html Msg
viewCreateTap model =
    let
        error =
            case model.error of
                Nothing ->
                    div [] []

                Just message ->
                    div [] [ text message ]
    in
        Html.form
            [ onSubmit CreateTap ]
            [ input [ placeholder "Label", onInput NewTapLabel ] []
            , input [ placeholder "URL", onInput NewTapAddress ] []
            , input [ placeholder "Port", onInput NewTapPort ] []
            , button [] [ text "Create Tap" ]
            , error
            ]
