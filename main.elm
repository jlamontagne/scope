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

-- MODEL
type alias Model =
  { endpoints : (List String)
  , tapName : String
  }

emptyModel : Model
emptyModel =
  { endpoints = []
  , tapName = ""
  }

init : (Model, Cmd Msg)
init =
  ( emptyModel ! []
  )

-- UPDATE
type Msg
  = NoOp
  | UpdateTapName String
  | CreateTap
  | TapCreated (Result Http.Error String)

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NoOp ->
      model ! []
    UpdateTapName name ->
      { model | tapName = name }
        ! []
    CreateTap ->
      (model, createTap model.tapName)
    TapCreated (Ok message)->
      model ! []
    TapCreated (Err _) ->
      model ! []

createTap : String -> Cmd Msg
createTap name =
  let
    url = "/tap"
    thing = Encode.object
      [ ("address", Encode.string name)
      , ("port", Encode.int 8444)
      , ("label", Encode.string "yeah")
      ]
    derp = Http.jsonBody thing
    request = Http.post url derp decodeTheThing
  in
    Http.send TapCreated request

decodeTheThing : Decode.Decoder String
decodeTheThing =
  Decode.at ["derp"] Decode.string

-- VIEW
view : Model -> Html Msg
view model =
  div
    []
    [ h1 [] [ text "scope" ]
    , input [ placeholder "New tap name", onInput UpdateTapName ] []
    , button [ onClick CreateTap ] [ text "Create Tap" ]
    ]
