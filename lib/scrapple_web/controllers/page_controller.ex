defmodule ScrappleWeb.PageController do
  use ScrappleWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
