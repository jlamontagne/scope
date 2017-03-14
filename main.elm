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

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NoOp ->
      model ! []
    UpdateTapName name ->
      { model | tapName = name }
        ! []
    CreateTap ->
      model ! []

-- VIEW
view : Model -> Html Msg
view model =
  div
    []
    [ h1 [] [ text "scope" ]
    , input [ placeholder "New tap name", onInput UpdateTapName ] []
    , button [ onClick CreateTap ] [ text "Create Tap" ]
    ]
