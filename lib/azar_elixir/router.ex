defmodule AzarSa.Router do
  @moduledoc """
  Router que distribuye la carga basándose en la configuración externa.
  """

  def redirigir(id_sorteo, accion, args) do
    #Se obtiene los nodos desde el archivo de configuración (config.exs)
    # Si no encuentra la configuración, usa el nodo actual por defecto.
    nodos = Application.get_env(:azar_elixir, :router)[:nodos] || [node()]

    #Calcula el nodo destino usando Hashing Consistente
    # Esto asegura que el mismo sorteo siempre vaya al mismo servidor matemáticamente.
    nodo_destino = obtener_nodo_destino(id_sorteo, nodos)

    #Toma la decisión de ejecutar localmente o hacer una llamada remota.
    if nodo_destino == node() do
      apply(AzarSa.TransaccionesServer, accion, args)
    else
      :rpc.call(nodo_destino, AzarSa.TransaccionesServer, accion, args)
    end
  end

  defp obtener_nodo_destino(id_sorteo, nodos) do
    # Usa phash2 para mapear el ID del sorteo a un índice de la lista.
    indice = :erlang.phash2(id_sorteo, length(nodos))
    Enum.at(nodos, indice)
  end
end
