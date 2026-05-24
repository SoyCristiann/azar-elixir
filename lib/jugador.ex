defmodule AzarSa.Jugador do
  @moduledoc """
  Módulo encargado de agrupar todos los procesos y consultas propias del perfil Jugador,
  separando la lógica de negocio de la lógica de autenticación (Usuarios) y operativa (Transacciones).
  """

  alias AzarSa.Storage
  alias AzarSa.Logger
  alias AzarSa.Transacciones

  @ruta_usuarios "data/usuarios.json"
  @ruta_sorteos "data/sorteos.json"

  @doc """
  Devuelve las compras del usuario y calcula el total de dinero gastado.
  """
  def consultar_historial(documento, ruta_usuarios \\ @ruta_usuarios) do
    usuarios = obtener_lista_usuarios(ruta_usuarios)

    case Enum.find(usuarios, fn u -> u["documento"] == documento end) do
      nil ->
        {:error, "Usuario no encontrado"}
      usuario ->
        compras = Map.get(usuario, "compras", [])
        total_gastado = Enum.reduce(compras, 0, fn c, acc -> acc + c["valor_pagado"] end)

        {:ok, %{compras: compras, total_gastado: total_gastado}}
    end
  end

  @doc """
  Calcula la diferencia entre el dinero gastado en compras y el dinero ganado en premios.
  """
  def consultar_balance(documento, ruta_usuarios \\ @ruta_usuarios) do
    usuarios = obtener_lista_usuarios(ruta_usuarios)

    case Enum.find(usuarios, fn u -> u["documento"] == documento end) do
      nil ->
        {:error, "Usuario no encontrado"}
      usuario ->
        #Sumar todos los gastos
        compras = Map.get(usuario, "compras", [])
        total_gastado = Enum.reduce(compras, 0, fn c, acc -> acc + c["valor_pagado"] end)

        #Sumar todas las ganancias
        premios = Map.get(usuario, "premios_ganados", [])
        total_ganado = Enum.reduce(premios, 0, fn p, acc -> acc + p["valor"] end)

        #Calcular balance neto
        balance_neto = total_ganado - total_gastado

        {:ok, %{gastado: total_gastado, ganado: total_ganado, balance_neto: balance_neto}}
    end
  end

  @doc """
  Muestra los premios ganados y los mensajes enviados por el servidor.
  """
  def ver_notificaciones_y_premios(documento, ruta_usuarios \\ @ruta_usuarios) do
    usuarios = obtener_lista_usuarios(ruta_usuarios)

    case Enum.find(usuarios, fn u -> u["documento"] == documento end) do
      nil ->
        {:error, "Usuario no encontrado"}
      usuario ->
        {:ok, %{
          premios: Map.get(usuario, "premios_ganados", []),
          notificaciones: Map.get(usuario, "notificaciones", [])
        }}
    end
  end

  @doc """
  Permite cancelar un billete y borrarlo del historial, siempre y cuando
  el sorteo no se haya jugado aún.
  """
  def devolver_compra(documento, id_sorteo, numero_billete, ruta_usuarios \\ @ruta_usuarios, ruta_sorteos \\ @ruta_sorteos) do
    #Verifica con Transacciones si el sorteo sigue activo
    sorteos_activos = Transacciones.consultar_sorteos_disponibles(ruta_sorteos)
    sorteo_activo? = Enum.any?(sorteos_activos, fn s -> s["id"] == id_sorteo end)

    if not sorteo_activo? do
      {:error, "No se puede devolver la compra. El sorteo ya fue jugado o no existe."}
    else
      #Realiza la devolución en la lista de compras del usuario
      datos_usuarios = Storage.leer_json(ruta_usuarios)
      usuarios = Map.get(datos_usuarios, "usuarios", [])

      index_usuario = Enum.find_index(usuarios, fn u -> u["documento"] == documento end)

      if index_usuario do
        usuario_actual = Enum.at(usuarios, index_usuario)
        compras = Map.get(usuario_actual, "compras", [])

        compra_a_devolver = Enum.find(compras, fn c ->
          c["id_sorteo"] == id_sorteo and c["numero_billete"] == numero_billete
        end)

        if compra_a_devolver do
          #Quita la compra de la lista y actualiza el mapa
          compras_actualizadas = List.delete(compras, compra_a_devolver)
          usuario_actualizado = Map.put(usuario_actual, "compras", compras_actualizadas)
          usuarios_nuevos = List.replace_at(usuarios, index_usuario, usuario_actualizado)

          Storage.guardar_json(ruta_usuarios, %{"usuarios" => usuarios_nuevos})
          Logger.registrar_log("Devolución [#{documento}]", "OK - Sorteo: #{id_sorteo} | Num: #{numero_billete}")

          {:ok, "Compra devuelta exitosamente. Dinero reembolsado."}
        else
          {:error, "No se encontró el billete asociado a este usuario en el sorteo indicado."}
        end
      else
        {:error, "Usuario no encontrado."}
      end
    end
  end


  @doc """
  Calcula dinámicamente qué números quedan disponibles.
  Diferencia la disponibilidad entre billetes completos (intactos) y fracciones.
  """
  def consultar_numeros_disponibles(id_sorteo, ruta_sorteos \\ @ruta_sorteos, ruta_usuarios \\ @ruta_usuarios) do
    datos_sorteos = Storage.leer_json(ruta_sorteos)

    sorteos = case datos_sorteos do
      %{"sorteos" => lista} -> lista
      lista when is_list(lista) -> lista
      _ -> []
    end

    case Enum.find(sorteos, fn s -> s["id"] == id_sorteo end) do
      nil ->
        {:error, "Sorteo no encontrado"}
      sorteo ->

        #Valores por defecto en caso de que el JSON no los tenga
        total_billetes = Map.get(sorteo, "total_billetes", 100)
        num_fracciones_total = Map.get(sorteo, "num_fracciones", 10)

        #Extrae todas las compras asociadas únicamente a este sorteo
        usuarios = obtener_lista_usuarios(ruta_usuarios)
        compras_del_sorteo =
          Enum.flat_map(usuarios, fn u -> Map.get(u, "compras", []) end)
          |> Enum.filter(fn c -> c["id_sorteo"] == id_sorteo end)

        #Calcula el "consumo" de fracciones de cada billete usando reduce.
        #Creamos un mapa donde la llave es el número y el valor es la cantidad de fracciones vendidas.
        consumo_por_billete =
          Enum.reduce(compras_del_sorteo, %{}, fn compra, acc ->
            numero = compra["numero_billete"]

            # Si compró completo, se lleva todas las fracciones. Si es fracción, solo 1.
            cantidad_comprada = if compra["tipo"] == "completo", do: num_fracciones_total, else: 1

            # Acumula el consumo para ese número específico
            Map.update(acc, numero, cantidad_comprada, fn actual -> actual + cantidad_comprada end)
          end)

        #Clasifica la disponibilidad exacta evaluando del 1 al total de billetes:
        # - Un billete completo solo está disponible si tiene 0 fracciones vendidas.
        # - Una fracción está disponible si sus ventas no han alcanzado el límite de fracciones del sorteo.
        completos_disponibles =
          Enum.filter(1..total_billetes, fn n -> Map.get(consumo_por_billete, n, 0) == 0 end)

        fracciones_disponibles =
          Enum.filter(1..total_billetes, fn n -> Map.get(consumo_por_billete, n, 0) < num_fracciones_total end)

        {:ok, %{
          billetes_completos: completos_disponibles,
          fracciones: fracciones_disponibles
        }}
    end
  end

  #Extrae la lista de usuarios del JSON, manejando casos donde la estructura pueda ser inconsistente
  defp obtener_lista_usuarios(ruta) do
    case Storage.leer_json(ruta) do
      %{"usuarios" => lista} when is_list(lista) -> lista
      lista when is_list(lista) -> lista
      _ -> []
    end
  end
end
