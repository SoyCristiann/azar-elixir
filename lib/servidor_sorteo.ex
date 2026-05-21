defmodule AzarSa.ServidorSorteo do
  use GenServer
  alias AzarSa.Storage
  alias AzarSa.Logger

  #API del cliente (Sistema)
  @doc """
  Inicia el servidor de sorteos y lo registra globalmente en la red.
  """
  def start_link(id_sorteo) do
    nombre_global= {:global, "Sorteo-#{id_sorteo}"}
    GenServer.start_link(__MODULE__, id_sorteo, name: nombre_global)
  end

  @doc """
  Consulta el estado actual del sorteo en memoria (El proceso es de forma síncrona).
  """
  def consultar_estado(id_sorteo) do
    #Se busca el proceso por su nombre global
    GenServer.call({:global, "Sorteo-#{id_sorteo}"}, :obtener_estado)
  end

  @doc """
  Intenta comprar un billete completo. (Tabmién es un proceso sincrono). El servidor se encargará de validar la compra, actualizar su estado y registrar la operación en la bitácora.
  """
  def comprar_billete(id_sorteo, numero_billete) do
    GenServer.call({:global, "Sorteo-#{id_sorteo}"}, {:comprar_billete, numero_billete})
  end



  #Llamadas del servidor
  @impl true
  def init(id_sorteo) do
    #El servidor lee la base de datos del JSON
    IO.puts("Iniciando el servidor para el sorteo #{id_sorteo}")
    datos_json= Storage.leer_json("data/sorteos.json")

    #Se extrae específicamente la lista de sorteos del JSON.
    lista_sorteos= datos_json["sorteos"] || datos_json


    #Busca la propia información
    estado_inicial= Enum.find(lista_sorteos, fn sorteo ->
      to_string(sorteo["id"]) == to_string(id_sorteo)
    end)

    #Si no existe el sorteo, se inicia con un estado vacío
    estado= estado_inicial || %{"id" => id_sorteo, "estado" => "No encontrado en JSON"}

    #Se retorna el estado para guardarlo en la memoria del proceso.
    {:ok, estado}
  end

  @impl true
  def handle_call(:obtener_estado, _from, estado_actual) do
    #Se retorna el estado sin modificrlo
    {:reply, estado_actual, estado_actual}
  end

  @impl true
  def handle_call({:comprar_billete, numero_billete}, _from, estado) do
    # Se obtiene la lista de billetes ya vendidos, si no existe, se usa una lista vacía.
    vendidos = Map.get(estado, "billetes_vendidos", [])

    # Se valida la regla: ¿está vedido el billete?
    if numero_billete in vendidos do
      # Se retorna error y se mantiene el estado intacto
      Logger.registrar_log("Compra billete #{numero_billete} en Sorteo #{estado["id"]}", "Negado - Ya vendido")
      {:reply, {:error, "El billete #{numero_billete} ya ha sido vendido"}, estado}
    else
      # Si el billete está disponible, se agrega a la lista y se crea un nuevo estado
      nuevos_vendidos = [numero_billete | vendidos]
      nuevo_estado = Map.put(estado, "billetes_vendidos", nuevos_vendidos)

      #Se registra el éxito en la bitácora con el logger
      Logger.registrar_log("Compra billete #{numero_billete} en Sorteo #{estado["id"]}", "Aprobado")

      #Se responde con éxito al cliente y se actualiza la memoria del GenServer
      {:reply, {:ok, "Billete #{numero_billete} comprado con éxito"}, nuevo_estado}
    end
  end

end
