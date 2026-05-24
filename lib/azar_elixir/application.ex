defmodule AzarSa.Application do
  use Application

  def start(_type, _args) do
    children = [
      AzarElixirWeb.Endpoint,
      AzarSa.TransaccionesServer
    ]

    opts = [strategy: :one_for_one, name: AzarSa.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
