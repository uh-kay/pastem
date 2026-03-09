import client/page/create
import client/page/home
import client/page/login
import client/page/register
import client/page/show
import client/route
import gleam/option.{None}

pub type PageModel {
  Home(home.Model)
  Login(login.Model)
  Register(register.Model)
  Logout
  CreateSnippet(create.Model)
  ShowSnippet(show.Model)
  NotFound
}

pub fn init(route: route.Route) -> PageModel {
  case route {
    route.Home -> Home(home.Model(snippets: [], logged_in: False))
    route.CreateSnippet ->
      CreateSnippet(create.FormPage(form: create.create_snippet_form()))
    route.ShowSnippet(_) ->
      ShowSnippet(show.Model(snippet: None, logged_in: False))
    route.Login -> Login(login.FormPage(form: login.login_form()))
    route.Register ->
      Register(register.FormPage(form: register.register_form()))
    route.Logout -> Logout
    route.NotFound -> NotFound
  }
}
