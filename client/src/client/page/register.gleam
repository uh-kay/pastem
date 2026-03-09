import formal/form.{type Form}

pub type RegisterForm {
  RegisterForm(username: String, email: String, password: String)
}

pub type Model {
  FormPage(form: Form(RegisterForm))
}

pub fn register_form() {
  form.new({
    use username <- form.field("username", form.parse_string)
    use email <- form.field("email", form.parse_email)
    use password <- form.field("password", form.parse_string)

    form.success(RegisterForm(username, email, password))
  })
}
