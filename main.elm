-- FIXME:
-- Input validation on create tap
import Debug exposing (..)
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
    , id : Int
    , label : String
    , portNumber : Int
    , routes : List Route
    , viewRoutes : Bool
    }


type alias Response =
    -- { headers : String
    -- , payload : String
    -- }
    { payload : String }


type alias Route =
    { method : String
    , path : String
    , pinned : Maybe Response
    , responses : List Response
    }


type alias Model =
    { endpoints : List String
    , taps : List Tap
    , newTapLabel : Maybe String
    , newTapAddress : Maybe String
    , newTapPort : Maybe Int
    , newTap : Maybe Tap
    , error : Maybe String
    }


emptyModel : Model
emptyModel =
    { endpoints = []
    , taps = []
    , newTapLabel = Nothing
    , newTapAddress = Nothing
    , newTapPort = Nothing
    , newTap = Nothing
    , error = Nothing
    }


fetchTaps : Cmd Msg
fetchTaps =
    Http.get "/taps" (Decode.list decodeTap) |> Http.send FetchedTaps


fetchRoutes : Tap -> Cmd Msg
fetchRoutes tap =
    Http.get ("/tap/" ++ (toString tap.id) ++ "/routes") (Decode.list decodeRoute)
        |> Http.send (FetchedRoutes tap)


init : (Model, Cmd Msg)
init =
    emptyModel ! [ fetchTaps ]


decodeResponse : Decode.Decoder Response
decodeResponse =
    Decode.map Response
        -- (Decode.field "headers" Decode.string)
        (Decode.field "payload" Decode.string)

decodeRoute : Decode.Decoder Route
decodeRoute =
    Decode.map4 Route
        (Decode.field "method" Decode.string)
        (Decode.field "path" Decode.string)
        (Decode.field "pinned" (Decode.nullable decodeResponse))
        (Decode.field "responses" (Decode.list decodeResponse))


decodeTap : Decode.Decoder Tap
decodeTap =
    Decode.map6 Tap
        (Decode.field "address" Decode.string)
        (Decode.field "id" Decode.int)
        (Decode.field "label" Decode.string)
        (Decode.field "port" Decode.int)
        (Decode.succeed [])
        (Decode.succeed False)

delete : String -> Http.Request ()
delete url =
    Http.request
        { method = "DELETE"
        , headers = []
        , url = url
        , body = Http.emptyBody
        , expect = Http.expectStringResponse (\_ -> Ok ())
        , timeout = Nothing
        , withCredentials = False
        }


type Msg
    = NoOp
    | NewTapLabel String
    | NewTapAddress String
    | NewTapPort String
    | CreateTap
    | TapCreated (Result Http.Error Tap)
    | RemoveTap Tap
    | TapRemoved Tap (Result Http.Error ())
    | FetchedTaps (Result Http.Error (List Tap))
    | FetchedRoutes Tap (Result Http.Error (List Route))
    | ToggleRoutes Tap


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
                | newTap = Just tap
                , taps = tap :: model.taps
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

        RemoveTap tap ->
            let
                request =
                    delete ("/tap/" ++ (toString tap.id))
            in
               (model, Http.send (TapRemoved tap) request)

        TapRemoved remTap (Ok _) ->
            { model
                | taps = List.filter (\tap -> tap.id /= remTap.id) model.taps
            }
                ! []

        TapRemoved _ (Err _) ->
            model ! []

        FetchedTaps (Ok taps) ->
            { model | taps = taps}
                ! List.map fetchRoutes taps

        FetchedTaps (Err _) ->
            model ! []

        FetchedRoutes updateTap (Ok routes) ->
            { model
                | taps = List.map (\tap ->
                    if tap.id == updateTap.id then
                        { tap | routes = routes }
                    else
                        tap
                ) model.taps
            }
                ! []

        FetchedRoutes _ (Err _) ->
            model ! []

        ToggleRoutes viewTap ->
            { model
                | taps = List.map (\tap ->
                    if tap.id == viewTap.id then
                       { tap | viewRoutes = not tap.viewRoutes }
                    else
                        tap
                ) model.taps
            }
                ! [ fetchRoutes viewTap ]



view : Model -> Html Msg
view model =
    div
        []
        [ h1 [] [ text "scope" ]
        , viewCreateTap model
        , viewTaps model
        ]

viewRoute : Route -> Html Msg
viewRoute route =
    div
        []
        [ div [] [ text route.method, text " ", text route.path ] ]

viewRoutes : Tap -> Html Msg
viewRoutes tap =
    if tap.viewRoutes then
        div []
            [ text "Routes: "
            , div [] (List.map viewRoute tap.routes)
            ]
    else
        div [] []


viewTap : Tap -> Html Msg
viewTap tap =
    li
        []
        [ div [] [ text "Backing address: ", text tap.address ]
        , div [] [ text "Proxy port: ", text <| toString tap.portNumber ]
        , div [] [ text "Label: ", text tap.label ]
        , button [ onClick (RemoveTap tap) ] [ text "Remove Tap" ]
        , button [ onClick (ToggleRoutes tap) ] [ text "Toggle Routes" ]
        , viewRoutes tap
        ]


viewTaps : Model -> Html Msg
viewTaps model =
    ul
        []
        (List.map viewTap model.taps)


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
