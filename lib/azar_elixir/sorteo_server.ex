defmodule AzarSa.SorteoServer do
  use GenServer
  require Logger

  #Registra el proceso dinámicamente con su ID único
  def start_link(id_sorteo) do
    nombre_proceso = {:via, Registry, {AzarSa.SorteosRegistry, id_sorteo}}
    GenServer.start_link(__MODULE__, id_sorteo, name: nombre_proceso)
  end

  #Busca el PID exacto de ese sorteo y le manda la orden
  def comprar(id_sorteo, documento, numero, tipo, valor) do
    # Intentamos buscar el servidor
    case Registry.lookup(AzarSa.SorteosRegistry, id_sorteo) do
      [{pid, _}] ->
        GenServer.call(pid, {:comprar, documento, numero, tipo, valor})

      [] ->
        # Si no existe, lo creamos dinámicamente en este momento
        case DynamicSupervisor.start_child(AzarSa.SorteosSupervisor, {AzarSa.SorteoServer, id_sorteo}) do
          {:ok, pid} -> GenServer.call(pid, {:comprar, documento, numero, tipo, valor})
          {:error, {:already_started, pid}} -> GenServer.call(pid, {:comprar, documento, numero, tipo, valor})
          error -> error
        end
    end
  end

  # --- CALLBACKS INTERNOS ---

  @impl true
  def init(id_sorteo) do
    Logger.info("⚙️ [NUEVO SERVIDOR] Sorteo #{id_sorteo} inicializado con PID: #{inspect(self())}")
    {:ok, id_sorteo}
  end

  @impl true
  def handle_call({:comprar, documento, numero, tipo, valor}, _from, id_sorteo) do
    Logger.info("🌐 [NODO: #{Node.self()}] PID: #{inspect(self())} procesando compra exclusiva para sorteo: #{id_sorteo}")

    resultado = AzarSa.Transacciones.comprar_billete(documento, id_sorteo, numero, tipo, valor)
    {:reply, resultado, id_sorteo}
  end
end
