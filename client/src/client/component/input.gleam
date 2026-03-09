import formal/form
import gleam/list
import lustre/attribute
import lustre/element/html

pub fn field_input(
  form: form.Form(t),
  name: String,
  kind: String,
  label: String,
  extra_attrs: List(attribute.Attribute(a)),
) {
  let errors = form.field_error_messages(form, name)

  html.div([attribute.class("mb-4")], [
    html.label([attribute.class("block mb-2 text-sm")], [
      html.text(label),
      ..list.map(errors, fn(msg) { html.small([], [html.text(msg)]) })
    ]),
    html.input([
      attribute.class(
        "border border-gray-400 rounded-md focus:border-transparent block w-full px-3 py-2",
      ),
      attribute.type_(kind),
      attribute.name(name),
      attribute.value(form.field_value(form, name)),
      case errors {
        [] -> attribute.none()
        _ -> attribute.aria_invalid("true")
      },
      ..extra_attrs
    ]),
  ])
}

pub fn radio(
  name name: String,
  value value: String,
  style style,
  extra_attrs extra_attrs: List(attribute.Attribute(a)),
) {
  html.input([
    attribute.type_("radio"),
    attribute.class(style),
    attribute.name(name),
    attribute.value(value),
    ..extra_attrs
  ])
}

pub fn textarea(
  name name,
  value value,
  style style,
  extra_attrs extra_attrs: List(attribute.Attribute(a)),
) {
  html.textarea(
    [attribute.name(name), attribute.class(style), ..extra_attrs],
    value,
  )
}
