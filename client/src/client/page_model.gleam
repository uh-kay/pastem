import client/page/home
import client/page/login
import client/page/show
import client/route
import gleam/option.{None}

pub type PageModel {
  Home(home.Model)
  Login(login.Model)
  ShowSnippet(show.Model)
  NotFound
}

pub fn init(route: route.Route) -> PageModel {
  case route {
    route.Home -> Home(home.Model(snippets: [], logged_in: False))
    route.ShowSnippet(_) ->
      ShowSnippet(show.Model(snippet: None, logged_in: False))
    route.Login -> Login(login.FormPage(form: login.login_form()))
    route.NotFound -> NotFound
  }
}
