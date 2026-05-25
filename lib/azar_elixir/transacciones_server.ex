defmodule AzarSa.TransaccionesServer do
  use GenServer

  #El sistema procesa solicitudes provenientes de la red.
  #Redirige esas solicitudes basándose en el sorteo correspondiente (id_sorteo).

  require Logger

  # Inicia el proceso y lo registra con el nombre del módulo (AzarSa.TransaccionesServer) para que se pueda llamar desde cualquier parte sin saber el PID.
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Función de acceso público: envuelve el mensaje que envía al servidor. Espera una respuesta.
  def comprar(documento, id_sorteo, numero, tipo, valor) do
    GenServer.call(__MODULE__, {:comprar, documento, id_sorteo, numero, tipo, valor})
  end

  # --- CALLBACKS DEL SERVIDOR (La lógica interna) ---
  # Estas funciones corren dentro del proceso del servidor (Aislado).

  @impl true
  def init(state) do
    # Inicializamos el estado vacío, ya que la persistencia la maneja el archivo JSON
    {:ok, state}
  end

  @impl true
  def handle_call({:comprar, documento, id_sorteo, numero, tipo, valor}, _from, state) do
    #Demuestra la recepción desde la red y la redirección
    Logger.info("🌐 [NODO RED: #{Node.self()}] Solicitud de compra recibida. Redirigiendo hacia el sorteo: #{id_sorteo}...")

    #Recibimos el mensaje y ejecutamos la lógica.
    # El resultado se envía de vuelta al cliente.
    resultado = AzarSa.Transacciones.comprar_billete(documento, id_sorteo, numero, tipo, valor)

    # {:reply, respuesta_a_enviar, nuevo_estado}
    {:reply, resultado, state}
  end
end
