import Html as H
import Html.Attributes as A
import Html.Events as E
import Json.Decode as Json
import Maybe.Extra as Maybe
import Nav exposing (..)
import Navigation
import Profile
import State.Main exposing (..)
import User

main : Program Never Model Msg
main =
  Navigation.program UrlChange
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }

init : Navigation.Location -> ( Model, Cmd Msg )
init location =
  let
    model = initState location

   -- We want to react initially to UrlChange as well
    urlCmd = Navigation.modifyUrl (routeToPath (parseLocation location))
    profileCmd = Cmd.map ProfileMessage Profile.getMe
  in
    model ! [ urlCmd, profileCmd ]


-- UPDATE

type Msg
  = NewUrl Route
  | UrlChange Navigation.Location
  | UserMessage User.Msg
  | ProfileMessage Profile.Msg

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NewUrl route ->
      ( model ,  Navigation.newUrl (routeToPath route) )

    UrlChange location ->
      let
        newRoute = parseLocation location
        modelWithRoute = { model | route = newRoute }
        ( newModel, cmd ) =
          case newRoute of
            User userId ->
              let
                (userModel, cmd) =
                  User.update (User.GetUser userId) modelWithRoute.user
              in
                ({ modelWithRoute | user = userModel }, Cmd.map UserMessage cmd)

            Profile ->
              modelWithRoute ! [ Cmd.map ProfileMessage Profile.initTasks ]

            newRoute ->
              (modelWithRoute, Cmd.none)
      in
        newModel ! [ cmd ]

    UserMessage msg ->
      let
        (userModel, cmd) = User.update msg model.user
      in
        ( { model | user = userModel}, Cmd.map UserMessage cmd )

    ProfileMessage msg ->
      let
        (profileModel, cmd) = Profile.update msg model.profile
      in
        { model
          | profile = profileModel
          , initialLoading = False
        } ! [ Cmd.map ProfileMessage cmd ]

--SUBSCRIPTIONS

subscriptions : Model -> Sub Msg
subscriptions model =
  Sub.none

-- VIEW

view : Model -> H.Html Msg
view model =
  if model.initialLoading
  then
    H.div
      [ A.class "splash-screen" ]
      [ logoImage 400 ]
  else
    H.div []
      [ navigation model
      , viewPage model
      ]

--TODO move navbar code to Nav.elm

navigation : Model -> H.Html Msg
navigation model =
  H.nav
    [ A.class "navbar navbar-default navbar-fixed-top" ]
    [ H.div
        [ A.class "navbar-header" ]
        [ H.button
          [ A.class "navbar-toggle collapsed"
          , A.attribute "data-toggle" "collapse"
          , A.attribute "data-target" "#navigation"
          ]
          [ H.span [ A.class "sr-only" ] [ H.text "Navigaation avaus" ]
          , H.span [ A.class "icon-bar" ] []
          , H.span [ A.class "icon-bar" ] []
          , H.span [ A.class "icon-bar" ] []
          ]
        , logo
        ]
    , H.div
        [ A.class "collapse navbar-collapse"
        , A.id "navigation"
        ]
        (navigationList model)
    ]

logo : H.Html Msg
logo =
  H.div
    [ A.class "navbar-brand" ]
    [ H.a
      [ A.id "logo"
      , A.href "/"
      ]
      [ logoImage 163
      ]
    ]


logoImage : Int -> H.Html msg
logoImage width =
  H.img
    [ A.alt "Tradenomiitti"
    , A.src "/static/tradenomiitti_logo.svg"
    , A.width width
    ]
    []


navigationList : Model -> List (H.Html Msg)
navigationList model =
  [ H.ul
    [ A.class "nav navbar-nav nav-center" ]
    [ viewLink ListUsers
    , verticalBar
    , viewLink ListAds
    , viewLinkInverse CreateAd
    ]
  , H.ul
    [ A.class "nav navbar-nav navbar-right" ]
    [ viewLink Info
    , verticalBar
    , viewProfileLink model
    ]
  ]

verticalBar : H.Html msg
verticalBar =
  H.li
    [ A.class <| "navbar__vertical-bar" ]
    [ H.div [] []]


viewLinkInverse : Route -> H.Html Msg
viewLinkInverse route =
  H.li
    [ A.class "navbar__inverse-button" ]
    [ link route ]

viewLink : Route -> H.Html Msg
viewLink route =
  H.li
    []
    [ link route ]

viewProfileLink : Model -> H.Html Msg
viewProfileLink model =
  let
    route = Profile
    action =
      if Maybe.isJust model.profile.user
      then
        [ E.onWithOptions
            "click"
            { stopPropagation = False
            , preventDefault = True
            }
            (Json.succeed <| NewUrl route)
        ]
      else
        []

    endpoint = if Maybe.isJust model.profile.user
               then routeToPath route
               else ssoUrl model.rootUrl route
    linkText =
      model.profile.user
        |> Maybe.map .name
        |> Maybe.withDefault "Kirjaudu"

    linkGraphic =
      model.profile.user
        |> Maybe.map
          (\u ->
             H.span
             [ A.class "navbar__profile-pic" ]
             [ {- here an img tag? -}]
          )
        |> Maybe.withDefault
          (H.span
            [ A.class "navbar__profile-lock glyphicon glyphicon-lock" ]
            [])

  in
    H.li
      []
      [ H.a
          ( action ++
          [ A.href endpoint
          ])
          [ H.text linkText
          , linkGraphic
          ]
      ]


link : Route -> H.Html Msg
link route =
  let
    action =
      E.onWithOptions
        "click"
        { stopPropagation = False
        , preventDefault = True
        }
        (Json.succeed <| NewUrl route)
  in
    H.a
      [ action
      , A.href (routeToPath route)
      ]
      [ H.text (routeToString route) ]

viewPage : Model -> H.Html Msg
viewPage model =
  let
    content =
      case model.route of
        User userId ->
          H.map UserMessage <| User.view model.user
        Profile ->
          H.map ProfileMessage <| Profile.view model.profile model
        route ->
          notImplementedYet
  in
    H.div
      [ A.class "container-fluid app-content" ]
      [ content ]

notImplementedYet : H.Html Msg
notImplementedYet =
  H.div
    [ A.id "not-implemented" ]
    [ H.text "Tätä ominaisuutta ei ole vielä toteutettu" ]


routeToString : Route -> String
routeToString route =
  case route of
    User userId ->
      "Käyttäjä " ++ (toString userId)
    Profile ->
      "Oma Profiili"
    Home ->
      "Home"
    Info ->
      "Tietoa"
    NotFound ->
      "Ei löytynyt"
    ListUsers ->
      "Tradenomit"
    ListAds ->
      "Hakuilmoitukset"
    CreateAd ->
      "Jätä ilmoitus"

