import lustre/attribute
import lustre/element/html

pub fn navbar() {
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

      html.div([attribute.class("flex items-center gap-6")], [
        html.a(
          [
            attribute.href("/snippets/create"),
            attribute.class(
              "text-md font-medium text-gray-600 dark:text-gray-400
               hover:text-green-600 dark:hover:text-green-400 transition-colors",
            ),
          ],
          [html.text("Create Snippet")],
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
      ]),
    ],
  )
}
// pub fn navbar() {
//   html.nav(
//     [
//       attribute.class(
//         "flex justify-between px-4 py-2 border-b border-gray-600 border-b-2",
//       ),
//     ],
//     [
//       html.a(
//         [
//           attribute.href("/"),
//           attribute.class(
//             "text-2xl text-green-600 hover:text-green-500 font-bold",
//           ),
//         ],
//         [html.text("Pastem")],
//       ),

//       html.div([attribute.class("flex gap-x-2")], [
//         html.a(
//           [
//             attribute.href("/snippets/create"),
//             attribute.class("hover:text-blue-500 text-xl"),
//           ],
//           [
//             html.text("Create Snippet"),
//           ],
//         ),
//         html.a(
//           [
//             attribute.href("/login"),
//             attribute.class("hover:text-blue-500 text-xl"),
//           ],
//           [
//             html.text("Login"),
//           ],
//         ),
//       ]),
//     ],
//   )
// }
