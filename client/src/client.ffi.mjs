export function check_login() {
  return document.cookie.startsWith("logged_in=");
}
