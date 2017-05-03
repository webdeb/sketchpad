defmodule Sketchpad.Web.PageController do
  use Sketchpad.Web, :controller

  plug :require_user when not action in [:signin]
  def index(conn, _params) do
    render conn, "index.html"
  end

  def signin(conn, %{"user" => %{"username" => user }} = params) do
    conn
    |> put_session(:user_id, user)
    |> redirect(to: page_path(conn, :index))
  end

  defp require_user(conn, _) do
    if user_id = get_session(conn, :user_id) do
      conn
      |> assign(:user_id, user_id)
      |> assign(:user_token, Phoenix.Token.sign(conn, "user token", user_id))
    else
      conn
      |> put_flash(:error, "Please signin")
      |> render("signin.html")
      |> halt()
    end
  end
end
