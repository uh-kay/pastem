import client/component/navbar
import client/page/create
import client/page/home
import client/page/login
import client/page/show
import client/page_model.{type PageModel}
import client/route.{
  type Route, CreateSnippet, Home, Login, NotFound, ShowSnippet,
}
import gleam/http/response.{type Response}
import gleam/int
import gleam/option.{type Option, None, Some}
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import rsvp.{type Error}
import shared.{type Snippet}

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", [])

  Nil
}

fn fetch_snippets() {
  let url = "/api/snippets"
  let handler =
    rsvp.expect_json(shared.snippet_list_decoder(), ServerReturnedSnippetList)

  rsvp.get(url, handler)
}

type Model {
  Model(
    snippets: List(Snippet),
    current_snippet: Option(Snippet),
    current_route: Route,
    page_model: PageModel,
    logged_in: Bool,
    error: Option(String),
  )
}

fn init(snippets) {
  let model =
    Model(
      snippets: snippets,
      current_snippet: None,
      current_route: Home,
      logged_in: False,
      page_model: page_model.init(Home),
      error: None,
    )

  let initial_effects = effect.batch([fetch_user(), fetch_snippets()])

  #(model, initial_effects)
}

fn fetch_user() {
  let url = "/api/users/me"
  let handler = rsvp.expect_ok_response(ServerReturnedUser)

  rsvp.get(url, handler)
}

type Msg {
  // component
  NavbarMsg(navbar.Msg)

  // page
  HomeMsg(home.Msg)
  CreateSnippetMsg(create.Msg)
  ShowSnippetMsg(show.Msg)
  LoginMsg(login.Msg)

  // api
  ServerReturnedUser(Result(Response(String), Error))
  ServerReturnedSnippetList(Result(List(Snippet), Error))
  ServerReturnedSnippet(Result(Snippet, Error))
}

fn update(model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    NavbarMsg(msg) ->
      case msg {
        navbar.UserClickedHome -> #(
          Model(..model, current_route: Home),
          effect.none(),
        )
        navbar.UserClickedLogin -> #(
          Model(..model, current_route: Login),
          effect.none(),
        )
        navbar.UserClickedRegister -> todo
        navbar.UserClickedCreateSnippet -> #(
          Model(..model, current_route: CreateSnippet),
          effect.none(),
        )
        navbar.UserClickedLogout -> todo
      }
    HomeMsg(msg) ->
      case msg {
        home.UserClickedSnippet(id) -> {
          let snippet = fetch_snippet(id)
          #(Model(..model, current_route: ShowSnippet(id)), snippet)
        }
      }
    CreateSnippetMsg(msg) ->
      case msg {
        create.UserSubmittedCreateForm(result) -> {
          case result {
            Ok(create_snippet) -> {
              let effect = create.save_snippet(create_snippet)
              #(
                Model(..model, current_route: Home),
                effect |> effect.map(CreateSnippetMsg),
              )
            }
            Error(form) -> #(
              Model(
                ..model,
                page_model: page_model.CreateSnippet(create.FormPage(form)),
              ),
              effect.none(),
            )
          }
        }
        create.ServerSavedSnippet(_) -> #(model, fetch_snippets())
      }
    ShowSnippetMsg(_) -> #(model, effect.none())
    LoginMsg(msg) ->
      case msg {
        login.UserSubmittedLoginForm(result) ->
          case result {
            Ok(login) -> {
              let effect = login.do_login(login)
              #(
                Model(..model, current_route: Home, logged_in: True),
                effect |> effect.map(LoginMsg),
              )
            }
            Error(form) -> #(
              Model(
                ..model,
                page_model: page_model.Login(login.FormPage(form)),
                current_route: Login,
              ),
              effect.none(),
            )
          }
        login.ServerReturnedToken(res) ->
          case res {
            Ok(_) -> #(model, effect.none())
            Error(_) -> #(
              Model(..model, current_route: Login, logged_in: False),
              effect.none(),
            )
          }
      }
    ServerReturnedUser(res) ->
      case res {
        Ok(_) -> #(Model(..model, logged_in: True), effect.none())
        Error(_) -> #(Model(..model, logged_in: False), effect.none())
      }
    ServerReturnedSnippetList(res) ->
      case res {
        Ok(snippets) -> #(Model(..model, snippets: snippets), effect.none())
        Error(_) -> #(
          Model(..model, error: Some("failed to get snippets")),
          effect.none(),
        )
      }
    ServerReturnedSnippet(res) ->
      case res {
        Ok(snippet) -> #(
          Model(..model, current_snippet: Some(snippet)),
          effect.none(),
        )
        Error(err) -> {
          echo err
          #(Model(..model, error: Some("failed to get snippet")), effect.none())
        }
      }
  }
}

fn fetch_snippet(id) {
  let url = "/api/snippets/" <> int.to_string(id)
  let handler =
    rsvp.expect_json(shared.snippet_item_decoder(), ServerReturnedSnippet)

  rsvp.get(url, handler)
}

fn view_page(model: Model, view: Element(a), msg: fn(a) -> Msg) {
  element.fragment([
    navbar.navbar(model.logged_in) |> element.map(NavbarMsg),
    view |> element.map(msg),
  ])
}

fn view(model: Model) -> Element(Msg) {
  case model.current_route {
    Home ->
      view_page(
        model,
        home.view(home.Model(
          snippets: model.snippets,
          logged_in: model.logged_in,
        )),
        HomeMsg,
      )
    CreateSnippet ->
      view_page(
        model,
        create.view(create.FormPage(form: create.create_snippet_form())),
        CreateSnippetMsg,
      )
    ShowSnippet(_id) ->
      view_page(
        model,
        show.view(show.Model(
          snippet: model.current_snippet,
          logged_in: model.logged_in,
        )),
        ShowSnippetMsg,
      )
    Login ->
      view_page(
        model,
        login.view(login.FormPage(form: login.login_form())),
        LoginMsg,
      )
    route.Register -> todo
    route.Logout -> todo
    NotFound -> element.none()
  }
}
