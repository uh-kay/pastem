import lustre/attribute
import lustre/element/html

pub fn label(text, style) {
  html.label([attribute.class(style)], [html.text(text)])
}
