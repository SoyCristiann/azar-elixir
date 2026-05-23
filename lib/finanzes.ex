defmodule AzarSa.Finanzas do
  @doc """
  Calcula el balance neto de un sorteo específico.
  Balance = Total Ingresos (ventas) - Total Costos (premios).
  """
  def calcular_balance_sorteo(id_sorteo, ruta_sorteos, ruta_usuarios) do
    # Obtener datos básicos
    sorteos = AzarSa.Storage.leer_json(ruta_sorteos)
    sorteo = Enum.find(sorteos, fn s -> s["id"] == id_sorteo end)

    if sorteo do
      # Calcular Ingresos sumando las compras de todos los usuarios para este sorteo
      ingresos = calcular_ingresos(id_sorteo, ruta_usuarios)

      # Calcula Costos sumando todos los premios del sorteo
      premios = Map.get(sorteo, "premios", [])
      costo_premios = Enum.reduce(premios, 0, fn p, acc -> acc + Map.get(p, "valor", 0) end)

      # Resultado final
      %{
        "id_sorteo" => id_sorteo,
        "ingresos" => ingresos,
        "costo_premios" => costo_premios,
        "balance_neto" => ingresos - costo_premios
      }
    else
      {:error, "Sorteo no encontrado"}
    end
  end

  # Función para sumar ingresos
  defp calcular_ingresos(id_sorteo, ruta_usuarios) do
    datos = AzarSa.Storage.leer_json(ruta_usuarios)
    usuarios = Map.get(datos, "usuarios", [])

    Enum.reduce(usuarios, 0, fn usuario, acc_total ->
      compras_usuario = Map.get(usuario, "compras", [])
      # Se suman solo las compras que coinciden con el id_sorteo
      suma_usuario =
        compras_usuario
        |> Enum.filter(fn c -> c["id_sorteo"] == id_sorteo end)
        |> Enum.reduce(0, fn c, acc -> acc + Map.get(c, "valor_pagado", 0) end)

      acc_total + suma_usuario
    end)
  end

  @doc """
  Calcula el balance personal de un usuario (lo que ha gastado vs lo que ha ganado).
  """
  def balance_personal(documento, ruta_usuarios) do
    datos = AzarSa.Storage.leer_json(ruta_usuarios)
    usuario = Enum.find(datos["usuarios"], fn u -> u["documento"] == documento end)

    if usuario do
      compras = Map.get(usuario, "compras", [])
      premios = Map.get(usuario, "premios_ganados", [])
      total_gastado =Enum.reduce(compras, 0, fn c, acc -> acc + Map.get(c, "valor_pagado", 0) end)
      total_ganado = Enum.reduce(premios, 0, fn p, acc -> acc + Map.get(p, "valor", 0) end)

      %{
        "nombre" => usuario["nombre"],
        "total_gastado" => total_gastado,
        "total_ganado" => total_ganado,
        "balance" => total_ganado - total_gastado
      }
    else
      {:error, "Usuario no encontrado"}
    end
  end
end
