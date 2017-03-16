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
  }

-- MODEL
type alias Model =
  { endpoints : (List String)
  , tapName : String
  , tap : Tap
  }

emptyModel : Model
emptyModel =
  { endpoints = []
  , tapName = ""
  , tap = { address = "", id = 0, label = "", portNumber = 0 }
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
  | TapCreated (Result Http.Error Tap)

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
    TapCreated (Ok tap)->
      { model | tap = tap }
        ! []
    TapCreated (Err _) ->
      model ! []

createTap : String -> Cmd Msg
createTap name =
  let
    tap = Http.jsonBody <| Encode.object
      [ ("address", Encode.string name)
      , ("port", Encode.int 8444)
      , ("label", Encode.string "yeah")
      ]
    request = Http.post "/tap" tap decodeTap
  in
    Http.send TapCreated request

-- error, message, statusCode (int)
decodeTheThing : Decode.Decoder String
decodeTheThing =
  Decode.at ["derp"] Decode.string

decodeTap : Decode.Decoder Tap
decodeTap =
  Decode.map4 Tap
    (Decode.field "address" Decode.string)
    (Decode.field "id" Decode.int)
    (Decode.field "label" Decode.string)
    (Decode.field "port" Decode.int)

-- VIEW
view : Model -> Html Msg
view model =
  div
    []
    [ h1 [] [ text "scope" ]
    , input [ placeholder "New tap name", onInput UpdateTapName ] []
    , button [ onClick CreateTap ] [ text "Create Tap" ]
    , text model.tap.address
    , text (toString model.tap.portNumber)
    , text (toString model.tap.id)
    , text model.tap.label
    ]
