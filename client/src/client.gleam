import client/component/navbar
import client/page/home
import client/page/login
import client/page/show
import client/page_model.{type PageModel}
import client/route.{type Route, Home, Login, NotFound, ShowSnippet}
import gleam/int
import gleam/option.{type Option, None, Some}
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import rsvp
import shared.{type Snippet}

pub fn main() -> Nil {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", [])

  Nil
}

fn fetch_snippets() {
  let url = "/api/snippets"
  let handler =
    rsvp.expect_json(shared.snippet_list_decoder(), ApiReturnedSnippetList)

  rsvp.get(url, handler)
}

type Model {
  Model(
    snippets: List(Snippet),
    current_snippet: Option(Snippet),
    current_route: Route,
    saving: Bool,
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
      saving: False,
      logged_in: False,
      page_model: page_model.init(Home),
      error: None,
    )

  let initial_items = fetch_snippets()

  #(model, initial_items)
}

type Msg {
  // component
  NavbarMsg(navbar.Msg)

  // page
  HomeMsg(home.Msg)
  ShowSnippetMsg(show.Msg)
  LoginMsg(login.Msg)

  // api
  ApiReturnedSnippetList(Result(List(Snippet), rsvp.Error))
  ApiReturnedSnippet(Result(Snippet, rsvp.Error))
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
      }
    HomeMsg(msg) ->
      case msg {
        home.UserClickedSnippet(id) -> {
          let snippet = fetch_snippet(id)
          #(Model(..model, current_route: ShowSnippet(id)), snippet)
        }
      }
    ShowSnippetMsg(_) -> #(model, effect.none())
    LoginMsg(msg) ->
      case msg {
        login.UserSubmittedLoginForm(result) ->
          case result {
            Ok(login) -> {
              let effect = login.do_login(login.email, login.password)
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
        login.ApiReturnedToken(res) -> {
          case res {
            Ok(_) -> #(model, effect.none())
            Error(_) -> #(
              Model(..model, current_route: Login, logged_in: False),
              effect.none(),
            )
          }
        }
      }
    ApiReturnedSnippetList(res) ->
      case res {
        Ok(snippets) -> #(Model(..model, snippets: snippets), effect.none())
        Error(_) -> #(
          Model(..model, error: Some("failed to get snippets")),
          effect.none(),
        )
      }
    ApiReturnedSnippet(res) ->
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
    rsvp.expect_json(shared.snippet_item_decoder(), ApiReturnedSnippet)

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
    NotFound -> element.none()
  }
}
