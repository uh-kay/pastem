import gleam/http/request
import lustre/attribute
import lustre/element/html

pub fn navbar(req: request.Request(a)) {
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
          attribute.href("/"),
          attribute.class(
            "flex items-center gap-2 text-xl font-bold tracking-tight
             text-gray-900 dark:text-white hover:opacity-80 transition-opacity",
          ),
        ],
        [html.text("Pastem")],
      ),

      html.div(
        [attribute.class("flex items-center gap-6")],
        case request.get_header(req, "authorization") {
          Ok(_) -> [
            html.a(
              [
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
          Error(_) -> [
            html.a(
              [
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
        },
      ),
    ],
  )
}
