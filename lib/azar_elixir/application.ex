defmodule AzarSa.Application do
  use Application

  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: AzarElixir.PubSub},
      AzarElixirWeb.Endpoint,
      {Registry, keys: :unique, name: AzarSa.SorteosRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: AzarSa.SorteosSupervisor}
    ]

    opts = [strategy: :one_for_one, name: AzarSa.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
