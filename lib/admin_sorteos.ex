defmodule AzarSa.AdminSorteos do
  @moduledoc """
  Módulo encargado de la administración operativa y financiera de los sorteos en el sistema AzarSa.

  Proporciona las funcionalidades principales para gestionar el ciclo de vida de los sorteos
  y realizar auditorías de los datos almacenados en los archivos JSON.

  ## Responsabilidades principales:
  * **Gestión de Sorteos:** Listado, creación segura (evitando duplicados) y eliminación
    de sorteos (aplicando reglas de negocio: no eliminar si ya hay premios configurados).
  * **Análisis Financiero:** Cálculo de ingresos totales generados por la venta de billetes
    de un sorteo específico.
  * **Auditoría de Clientes:** Identificación rápida de los usuarios que han participado en un sorteo.
  * **Balances y Cuadres:** Generación del balance neto (Ingresos totales - Costo de los premios)
    para determinar la rentabilidad del sorteo.
  """

  # Utilizamos alias para acceder de forma más fácil al módulo.
  alias AzarSa.Storage
  # Se define el atributo del módulo para acceder a la ruta de sorteos, similar a una constante.
  @archivo_sorteos "data/sorteos.json"
  @archivo_usuarios "data/usuarios.json"

  # Para recordar:
  # Lambdas: fn argumentos -> cuerpo_de_la_funcion end
  # Se agrega \\ para utilizar @archivo_sorteos o @archivo_usuarios como un parámetro opcional en caso de no pasar la ruta. Especificamente para las pruebas.
  #
  # --- ESTRUCTURAS DE ENUM UTILIZADAS ---
  #
  # 1. Enum.any?(enumerable, fn elemento -> condicion end)
  #    -> Devuelve `true` si AL MENOS UN elemento cumple la condición. De lo contrario, `false`.
  #
  # 2. Enum.find(enumerable, fn elemento -> condicion end)
  #    -> Devuelve el PRIMER elemento completo que cumpla la condición. Si no hay, devuelve `nil`.
  #
  # 3. Enum.empty?(enumerable)
  #    -> Devuelve `true` si la lista está vacía ([]). Si tiene elementos, devuelve `false`.
  #
  # 4. Enum.reject(enumerable, fn elemento -> condicion end)
  #    -> Lo opuesto a filter. Devuelve una lista ELIMINANDO los elementos que cumplan la condición.
  #
  # 5. Enum.flat_map(enumerable, fn elemento -> extraer_lista end)
  #    -> Recorre el enumerable, extrae listas anidadas y las "aplana" en una sola lista continua.
  #
  # 6. Enum.filter(enumerable, fn elemento -> condicion end)
  #    -> Actúa como un colador. Devuelve una lista SOLO con los elementos que cumplan la condición.
  #
  # 7. Enum.reduce(enumerable, valor_inicial, fn elemento, acumulador -> operacion end)
  #    -> Recorre la lista arrastrando un "acumulador". Ideal para sumar totales o consolidar datos.
  #
  # 8. Enum.map(enumerable, fn elemento -> transformacion end)
  #    -> Transforma cada elemento de la lista original y devuelve una nueva lista del mismo tamaño con los cambios.

  @doc """
  Lee el archivo JSON, extrae la lista de sorteos y los devuelve ordenados por fecha.
  """
  def listar_sorteos(ruta \\ @archivo_sorteos) do
    datos = Storage.leer_json(ruta)
    sorteos = Map.get(datos, "sorteos", [])

    Enum.sort_by(sorteos, fn sorteo ->
      # Protección: Si no hay fecha en los datos de prueba, usamos una por defecto
      fecha_str = Map.get(sorteo, "fecha", "2000-01-01")
      case Date.from_iso8601(fecha_str) do
        {:ok, fecha} -> fecha
        _error -> Date.utc_today()
      end
    end, {:desc, Date})
  end

  def crear_sorteo(nuevo_sorteo, ruta \\ @archivo_sorteos) do
    sorteos_actuales = listar_sorteos(ruta)

    if Enum.any?(sorteos_actuales, fn sorteo -> sorteo["id"] == nuevo_sorteo["id"] end) do
      {:error, "Ya existe un sorteo con el ID: #{nuevo_sorteo["id"]}"}
    else
      sorteos_actualizados = [nuevo_sorteo | sorteos_actuales]

      # CORRECCIÓN: Guardar siempre respetando la raíz "sorteos"
      case Storage.guardar_json(ruta, %{"sorteos" => sorteos_actualizados}) do
        :ok -> {:ok, "Sorteo creado exitosamente"}
        error -> error
      end
    end
  end

  def eliminar_sorteo(id_sorteo, ruta \\ @archivo_sorteos) do
    sorteos_actuales = listar_sorteos(ruta)
    sorteo = Enum.find(sorteos_actuales, fn sorteo -> sorteo["id"] == id_sorteo end)

    case sorteo do
      nil ->
        {:error, "El sorteo con ID #{id_sorteo} no existe."}

      sorteo_encontrado ->
        premios = Map.get(sorteo_encontrado, "premios", [])

        if Enum.empty?(premios) do
          sorteos_actualizados = Enum.reject(sorteos_actuales, fn sorteo -> sorteo["id"] == id_sorteo end)

          # CORRECCIÓN: Guardar siempre respetando la raíz "sorteos"
          Storage.guardar_json(ruta, %{"sorteos" => sorteos_actualizados})
          {:ok, "Sorteo eliminado exitosamente"}
        else
          {:error, "No se puedse eliminar el sorteo porque ya tiene premios asociados"}
        end
    end
  end

  def consultar_ingresos(id_sorteo, ruta_usuarios \\ @archivo_usuarios) do
    data = Storage.leer_json(ruta_usuarios)
    usuarios = Map.get(data, "usuarios", [])
    todas_las_compras = Enum.flat_map(usuarios, fn u -> Map.get(u, "compras", []) end)

    todas_las_compras
    |> Enum.filter(fn compra -> compra["id_sorteo"] == id_sorteo end)
    |> Enum.reduce(0, fn compra, acum -> acum + compra["valor_pagado"] end)
  end

  def listar_clientes_por_sorteo(id_sorteo, ruta_usuarios \\ @archivo_usuarios) do
    data = Storage.leer_json(ruta_usuarios)
    usuarios = Map.get(data, "usuarios", [])

    #Agrupa a los usuarios según el tipo de compra ("completo" o "fraccion")
    Enum.reduce(usuarios, %{completos: [], fracciones: []}, fn usuario, acc ->
      compras = Map.get(usuario, "compras", [])
      compras_del_sorteo = Enum.filter(compras, fn c -> c["id_sorteo"] == id_sorteo end)

      if Enum.empty?(compras_del_sorteo) do
        acc
      else
        #Verifica qué tipo de billetes compró este usuario
        compro_completo? = Enum.any?(compras_del_sorteo, fn c -> Map.get(c, "tipo", "completo") == "completo" end)
        compro_fraccion? = Enum.any?(compras_del_sorteo, fn c -> Map.get(c, "tipo") == "fraccion" end)

        nombre = usuario["nombre"]

        acc_1 = if compro_completo?, do: Map.update!(acc, :completos, fn lista -> [nombre | lista] end), else: acc
        acc_2 = if compro_fraccion?, do: Map.update!(acc_1, :fracciones, fn lista -> [nombre | lista] end), else: acc_1

        acc_2
      end
    end)
    |> Map.update!(:completos, &Enum.uniq/1)
    |> Map.update!(:fracciones, &Enum.uniq/1)
  end

  def balance_sorteo(id_sorteo, ruta_sorteos \\ @archivo_sorteos, ruta_usuarios \\ @archivo_usuarios) do
    ingresos = consultar_ingresos(id_sorteo, ruta_usuarios)
    sorteos = listar_sorteos(ruta_sorteos)
    sorteo = Enum.find(sorteos, fn s -> s["id"] == id_sorteo end)

    case sorteo do
      nil -> {:error, "Sorteo no encontrado"}
      s ->
        premios = Map.get(s, "premios", [])
        total_premios = Enum.reduce(premios, 0, fn p, acum -> acum + p["valor"] end)

        %{
          "id_sorteo" => id_sorteo,
          "ingresos" => ingresos,
          "costo_premios" => total_premios,
          "balance_neto" => ingresos - total_premios
        }
    end
  end

  def listar_premios(id_sorteo, ruta_sorteos \\ @archivo_sorteos) do
    sorteos = listar_sorteos(ruta_sorteos)
    sorteo = Enum.find(sorteos, fn s -> s["id"] == id_sorteo end)

    case sorteo do
      nil -> {:error, "Sorteo no encontrado"}
      s -> Map.get(s, "premios", [])
    end
  end

  def agregar_premio(id_sorteo, nuevo_premio, ruta_sorteos \\ @archivo_sorteos) do
    sorteos = listar_sorteos(ruta_sorteos)

    sorteos_actualizados =
      Enum.map(sorteos, fn s ->
        if s["id"] == id_sorteo do
          premios_actuales = Map.get(s, "premios", [])
          Map.put(s, "premios", [nuevo_premio | premios_actuales])
        else
          s
        end
      end)

    # CORRECCIÓN: Guardar siempre respetando la raíz "sorteos"
    Storage.guardar_json(ruta_sorteos, %{"sorteos" => sorteos_actualizados})
  end

  def eliminar_premio(id_sorteo, nombre_premio, ruta_sorteos \\ @archivo_sorteos, ruta_usuarios \\ @archivo_usuarios) do
    data_usuarios = Storage.leer_json(ruta_usuarios)
    usuarios = Map.get(data_usuarios, "usuarios", [])

    tiene_clientes =
      Enum.any?(usuarios, fn u ->
        compras = Map.get(u, "compras", [])
        Enum.any?(compras, fn c -> c["id_sorteo"] == id_sorteo end)
      end)

    if tiene_clientes do
      {:error, "No se puede eliminar el premio porque hay clientes participando en el sorteo"}
    else
      sorteos = listar_sorteos(ruta_sorteos)

      sorteos_actualizados =
        Enum.map(sorteos, fn s ->
          if s["id"] == id_sorteo do
            premios_filtrados = Enum.reject(s["premios"], fn p -> p["nombre"] == nombre_premio end)
            Map.put(s, "premios", premios_filtrados)
          else
            s
          end
        end)

      # CORRECCIÓN: Guardar siempre respetando la raíz "sorteos"
      Storage.guardar_json(ruta_sorteos, %{"sorteos" => sorteos_actualizados})
      {:ok, "Premio eliminado exitosamente"}
    end
  end

  # ==========================================
  # MOTOR DE JUEGO: ACTUALIZACIÓN DE FECHA
  # ==========================================
  def actualizar_fecha_sistema(nueva_fecha_str, ruta_sorteos \\ @archivo_sorteos, ruta_usuarios \\ @archivo_usuarios) do
    case Date.from_iso8601(nueva_fecha_str) do
      {:ok, nueva_fecha} ->
        data_sorteos = Storage.leer_json(ruta_sorteos)
        sorteos = Map.get(data_sorteos, "sorteos", [])

        data_usuarios = Storage.leer_json(ruta_usuarios)
        usuarios = Map.get(data_usuarios, "usuarios", [])

        {sorteos_a_jugar, sorteos_restantes} = Enum.split_with(sorteos, fn s ->
          s["estado"] == "pendiente" && tiene_fecha_vencida?(Map.get(s, "fecha", "2000-01-01"), nueva_fecha)
        end)

        if Enum.empty?(sorteos_a_jugar) do
          {:ok, "Fecha actualizada a #{nueva_fecha_str}. No se encontraron sorteos programados para jugar."}
        else
          {sorteos_jugados, usuarios_actualizados} =
            Enum.reduce(sorteos_a_jugar, {[], usuarios}, fn sorteo, {sorteos_acc, usuarios_acc} ->
              {sorteo_actualizado, nuevos_usuarios} = jugar_sorteo(sorteo, usuarios_acc, nueva_fecha_str)
              {sorteos_acc ++ [sorteo_actualizado], nuevos_usuarios}
            end)

          data_sorteos_final = Map.put(data_sorteos, "sorteos", sorteos_restantes ++ sorteos_jugados)
          data_usuarios_final = Map.put(data_usuarios, "usuarios", usuarios_actualizados)

          Storage.guardar_json(ruta_sorteos, data_sorteos_final)
          Storage.guardar_json(ruta_usuarios, data_usuarios_final)

          {:ok, "Éxito: Se avanzó la fecha a #{nueva_fecha_str} y se ejecutaron #{length(sorteos_a_jugar)} sorteo(s)."}
        end

      {:error, _reason} ->
        {:error, "Formato de fecha inválido. Debe utilizar el formato AAAA-MM-DD (Ej: 2026-05-22)."}
    end
  end

  defp tiene_fecha_vencida?(fecha_sorteo_str, nueva_fecha) do
    case Date.from_iso8601(fecha_sorteo_str) do
      {:ok, f_sorteo} -> Date.compare(f_sorteo, nueva_fecha) != :gt
      _error -> false
    end
  end

  defp jugar_sorteo(sorteo, usuarios, nueva_fecha_str) do
    sorteo_id = sorteo["id"]
    # Protección si no tiene la llave
    total_billetes = Map.get(sorteo, "total_billetes", 100)
    premios = Map.get(sorteo, "premios", [])

    {ganadores_sorteo, usuarios_actualizados} =
      Enum.reduce(premios, {[], usuarios}, fn premio, {ganadores_acc, u_acc} ->
        numero_ganador = :rand.uniform(total_billetes)

        {nuevos_ganadores, usuarios_modificados} =
          evaluar_compradores(sorteo_id, numero_ganador, premio, nueva_fecha_str, Map.get(sorteo, "nombre", "Sorteo"), u_acc)

        {ganadores_acc ++ nuevos_ganadores, usuarios_modificados}
      end)

    sorteo_actualizado =
      sorteo
      |> Map.put("estado", "jugado")
      |> Map.put("ganadores", ganadores_sorteo)

    {sorteo_actualizado, usuarios_actualizados}
  end

  defp evaluar_compradores(sorteo_id, numero_ganador, premio, fecha_str, nombre_sorteo, usuarios) do
    Enum.reduce(usuarios, {[], []}, fn usuario, {ganadores_list, usuarios_list} ->
      compras = Map.get(usuario, "compras", [])

      gano? = Enum.any?(compras, fn c ->
        c["id_sorteo"] == sorteo_id && c["numero_billete"] == numero_ganador
      end)

      if gano? do
        registro_ganador = %{
          "documento" => Map.get(usuario, "documento", "Desconocido"),
          "premio" => premio["nombre"],
          "numero" => numero_ganador
        }

        premio_usuario = %{
          "id_sorteo" => sorteo_id,
          "nombre_premio" => premio["nombre"],
          "valor" => premio["valor"],
          "fecha" => fecha_str
        }

        notificacion = "¡Felicidades! Tu número #{numero_ganador} ganó el premio '#{premio["nombre"]}' en el #{nombre_sorteo}."

        usuario_actualizado =
          usuario
          |> Map.update("premios_ganados", [premio_usuario], fn pg -> pg ++ [premio_usuario] end)
          |> Map.update("notificaciones", [notificacion], fn n -> n ++ [notificacion] end)

        {ganadores_list ++ [registro_ganador], usuarios_list ++ [usuario_actualizado]}
      else
        {ganadores_list, usuarios_list ++ [usuario]}
      end
    end)
  end
end
