defmodule AzarSa.Transacciones do
  @ruta_usuarios "data/usuarios.json"
  @ruta_sorteos "data/sorteos.json"

  @doc """
  Consulta en el archivo JSON los sorteos disponibles.
  Filtra los sorteos que no tengan el estado ugado.
  """
  def consultar_sorteos_disponibles(ruta_sorteos \\ @ruta_sorteos) do
  #Se lee el mapa
  datos = AzarSa.Storage.leer_json(ruta_sorteos)

  #Se extrae la lista usando Map.get con un valor por defecto (lista vacía)
  sorteos = Map.get(datos, "sorteos", [])

  #Se filtra sobre la lista real.
  Enum.filter(sorteos, fn sorteo ->
    Map.get(sorteo, "estado", "activo") != "jugado"
  end)
end

  @doc """
  Registra la compra de un billete o fracción en el perfil del usuario.
  Valida que el sorteo esté disponible antes de procesar la transacción.
  """
  def comprar_billete(documento, id_sorteo, numero, tipo, valor_pagado, ruta_usuarios \\ @ruta_usuarios, ruta_sorteos \\ @ruta_sorteos) do
    #Validar que el sorteo esté disponible para la venta
    sorteos_activos = consultar_sorteos_disponibles(ruta_sorteos)
    sorteo_valido? = Enum.any?(sorteos_activos, fn s -> s["id"] == id_sorteo end)

    if not sorteo_valido? do
      AzarSa.Logger.registrar_log("Compra [#{documento}]", "NEGADO - Sorteo #{id_sorteo} no disponible")
      {:error, "El sorteo no está disponible o ya fue jugado."}
    else
      # Se cargan los datos de los usuarios
      datos_usuarios = AzarSa.Storage.leer_json(ruta_usuarios)
      usuarios = Map.get(datos_usuarios, "usuarios", [])

      #Busca al usuario específico por su documento y obtiene su índice en la lista de usuarios.
      index_usuario = Enum.find_index(usuarios, fn u -> u["documento"] == documento end)

      if index_usuario do
        #Crea la transacción
        nueva_compra = %{
          "id_sorteo" => id_sorteo,
          "numero_billete" => numero,
          "tipo" => tipo, # "completo" o "fraccion"
          "valor_pagado" => valor_pagado
        }

        #Actualiza la lista de compras del usuario
        usuario_actual = Enum.at(usuarios, index_usuario)
        compras_actualizadas = usuario_actual["compras"] ++ [nueva_compra]
        usuario_actualizado = Map.put(usuario_actual, "compras", compras_actualizadas)

        usuarios_nuevos = List.replace_at(usuarios, index_usuario, usuario_actualizado)

        #Guardar y registra el log
        AzarSa.Storage.guardar_json(ruta_usuarios, %{"usuarios" => usuarios_nuevos})
        AzarSa.Logger.registrar_log("Compra [#{documento}]", "OK - Sorteo: #{id_sorteo} | Num: #{numero} | Tipo: #{tipo}")

        {:ok, nueva_compra}
      else
        AzarSa.Logger.registrar_log("Compra [#{documento}]", "NEGADO - Usuario no existe")
        {:error, "No se encontró un usuario con el documento proporcionado."}
      end
    end
  end
end
