import lustre/attribute
import lustre/element/html
import lustre/event

pub type Msg {
  UserClickedHome
  UserClickedLogin
  UserClickedRegister
  UserClickedCreateSnippet
  UserClickedLogout
}

pub fn navbar(logged_in: Bool) {
  html.nav(
    [
      attribute.class(
        "sticky top-0 z-50 flex items-center justify-between px-6 py-3
         bg-white/80 dark:bg-gray-900/80 backdrop-blur-md",
      ),
    ],
    [
      html.a(
        [
          event.prevent_default(event.on_click(UserClickedHome)),
          attribute.href("/"),
          attribute.class(
            "flex items-center gap-2 text-xl font-bold tracking-tight
             text-gray-900 dark:text-white hover:opacity-80 transition-opacity",
          ),
        ],
        [html.text("Pastem")],
      ),

      html.div([attribute.class("flex items-center gap-6")], case logged_in {
        True -> [
          html.a(
            [
              event.prevent_default(event.on_click(UserClickedLogout)),
              attribute.href("/logout"),
              attribute.class(
                "text-md font-medium text-gray-600 dark:text-gray-400
                 hover:text-green-600 dark:hover:text-green-400 transition-colors",
              ),
            ],
            [html.text("Logout")],
          ),
          html.a(
            [
              event.prevent_default(event.on_click(UserClickedCreateSnippet)),
              attribute.href("/snippets/create"),
              attribute.class(
                "px-4 py-2 text-md font-medium text-white bg-green-600
                   rounded-lg hover:bg-green-500 transition-all shadow-sm
                   active:scale-95",
              ),
            ],
            [html.text("Create Snippet")],
          ),
        ]
        False -> [
          html.a(
            [
              event.prevent_default(event.on_click(UserClickedRegister)),
              attribute.href("/register"),
              attribute.class(
                "text-md font-medium text-gray-600 dark:text-gray-400
                   hover:text-green-600 dark:hover:text-green-400 transition-colors",
              ),
            ],
            [html.text("Register")],
          ),
          html.a(
            [
              event.prevent_default(event.on_click(UserClickedLogin)),
              attribute.href("/login"),
              attribute.class(
                "px-4 py-2 text-md font-medium text-white bg-green-600
                   rounded-lg hover:bg-green-500 transition-all shadow-sm
                   active:scale-95",
              ),
            ],
            [html.text("Login")],
          ),
        ]
      }),
    ],
  )
}
