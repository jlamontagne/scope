import Html exposing (..)
import Html.App as App
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Json
import List
import Task

main =
  App.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

-- MODEL
type alias Model =
  { endpoints : (List String)
  }

init : (Model, Cmd Msg)
init =
  ( Model []
  , getEndpoints "foo"
  )

-- model : Model
-- model =
--   { endpoints = [] }

-- UPDATE
type Msg
  = FetchSucceed (List String)
  | FetchFail Http.Error
  | Pin String
  | PinFail Http.Error
  | PinOk String

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    FetchSucceed newEndpoints ->
      -- ({ model | endpoints = newEndpoints }, Cmd.none)
      (Model newEndpoints, Cmd.none)
    FetchFail _ ->
      (model, Cmd.none)
    Pin endpoint ->
      (model, pinEndpoint endpoint)
    PinOk _ ->
      (model, Cmd.none)
    PinFail _ ->
      (model, Cmd.none)

-- VIEW
view : Model -> Html Msg
view model =
  div []
    (List.map (\e -> div []
      [ button [ onClick (Pin e) ] [ text "PIN" ]
      , text (toString e)
      ]) model.endpoints)

-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none

-- HTTP
getEndpoints : String -> Cmd Msg
getEndpoints foo =
  let
    url =
      "/taps"
  in
     Task.perform FetchFail FetchSucceed (Http.get decodeEndpoints url)

decodeEndpoints : Json.Decoder (List String)
decodeEndpoints =
  Json.list Json.string

pinEndpoint : String -> Cmd Msg
pinEndpoint endpoint =
  let
    url =
      "/pin"
  in
     Task.perform PinFail PinOk (Http.post (Json.string) url (Http.string endpoint))
