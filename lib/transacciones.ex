defmodule AzarSa.Transacciones do
  require Logger

  @ruta_usuarios "data/usuarios.json"
  @ruta_sorteos "data/sorteos.json"

  @doc """
  Consulta en el archivo JSON los sorteos disponibles.
  Filtra los sorteos que no tengan el estado ugado.
  """
  def consultar_sorteos_disponibles(ruta_sorteos \\ @ruta_sorteos) do
  datos = AzarSa.Storage.leer_json(ruta_sorteos)
  #Si es mapa, busca la llave "sorteos". Si es lista, úsala directamente (para test ok).
  sorteos = case datos do
    %{"sorteos" => lista} -> lista
    lista when is_list(lista) -> lista
    _ -> []
  end

  Enum.filter(sorteos, fn sorteo ->
    Map.get(sorteo, "estado", "activo") != "jugado"
  end)
end

  @doc """
  Registra la compra de un billete o fracción en el perfil del usuario.
  Valida que el sorteo esté disponible y que el número tenga inventario.
  """
  def comprar_billete(documento, id_sorteo, numero, tipo, valor_pagado, ruta_usuarios \\ @ruta_usuarios, ruta_sorteos \\ @ruta_sorteos) do
    Logger.info("📝 [LÓGICA DEL SORTEO] Procesando compra para el sorteo #{id_sorteo}. Gestionando información en los archivos JSON: #{ruta_usuarios} y #{ruta_sorteos}")
    #Validar que el sorteo esté disponible para la venta
    sorteos_activos = consultar_sorteos_disponibles(ruta_sorteos)
    sorteo_valido? = Enum.any?(sorteos_activos, fn s -> s["id"] == id_sorteo end)

    if not sorteo_valido? do
      AzarSa.Logger.registrar_log("Compra [#{documento}]", "NEGADO - Sorteo #{id_sorteo} no disponible")
      {:error, "El sorteo no está disponible o ya fue jugado."}
    else
      #Valida sobre venta y disponibilidad del número
      case AzarSa.Jugador.consultar_numeros_disponibles(id_sorteo, ruta_sorteos, ruta_usuarios) do
        {:ok, disponibles} ->
          puede_comprar? =
            if tipo == "completo" do
              Enum.member?(disponibles.billetes_completos, numero)
            else
              Enum.member?(disponibles.fracciones, numero)
            end

          if not puede_comprar? do
            AzarSa.Logger.registrar_log("Compra [#{documento}]", "NEGADO - Billete #{numero} (#{tipo}) agotado")
            {:error, "El número #{numero} no está disponible para compra como #{tipo}."}
          else
            #Procede con la transacción: registra la compra en el perfil del usuario y actualiza el inventario del sorteo
            datos_usuarios = AzarSa.Storage.leer_json(ruta_usuarios)
            usuarios = Map.get(datos_usuarios, "usuarios", [])
            index_usuario = Enum.find_index(usuarios, fn u -> u["documento"] == documento end)

            if index_usuario do
              nueva_compra = %{
                "id_sorteo" => id_sorteo,
                "numero_billete" => numero,
                "tipo" => tipo,
                "valor_pagado" => valor_pagado
              }

              usuario_actual = Enum.at(usuarios, index_usuario)
              compras_actualizadas = usuario_actual["compras"] ++ [nueva_compra]
              usuario_actualizado = Map.put(usuario_actual, "compras", compras_actualizadas)
              usuarios_nuevos = List.replace_at(usuarios, index_usuario, usuario_actualizado)

              AzarSa.Storage.guardar_json(ruta_usuarios, %{"usuarios" => usuarios_nuevos})
              AzarSa.Logger.registrar_log("Compra [#{documento}]", "OK - Sorteo: #{id_sorteo} | Num: #{numero} | Tipo: #{tipo}")

              {:ok, nueva_compra}
            else
              AzarSa.Logger.registrar_log("Compra [#{documento}]", "NEGADO - Usuario no existe")
              {:error, "No se encontró un usuario con el documento proporcionado."}
            end
          end

        {:error, razon} ->
          {:error, razon} # Error propagado desde la consulta de disponibilidad
      end
    end
  end
end
