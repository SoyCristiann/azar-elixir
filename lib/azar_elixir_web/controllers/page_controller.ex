defmodule AzarElixirWeb.PageController do
  use AzarElixirWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
