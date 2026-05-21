defmodule AzarSa.SupervisorSorteos do
  use Supervisor
  alias AzarSa.Storage

  @doc """
  Arranca el Supervisor principal.
  """
  def start_link(init_arg \\ []) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    IO.puts("Iniciando el Supervisor de Sorteos")

    # Lee el archivo para saber cuántos servidores debe levantar
    datos = Storage.leer_json("data/sorteos.json")
    lista_sorteos = datos["sorteos"] || datos

    #Se crean las tareas para el supervisor.
    # Por cada sorteo en el JSON, se configura un proceso hijo
    hijos = Enum.map(lista_sorteos, fn sorteo ->
      Supervisor.child_spec({AzarSa.ServidorSorteo, sorteo["id"]}, id: sorteo["id"])
    end)

    # Se enciende la vigilancia del supervisor.
    # strategy: :one_for_one significa que si un sorteo muere, solo se reinicia ese sorteo.
    Supervisor.init(hijos, strategy: :one_for_one)
  end
end
