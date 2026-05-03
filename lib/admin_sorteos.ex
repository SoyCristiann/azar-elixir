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
  Lee el archivo JASON y devuelve la liusta de todos los sorteos.
  Si el archivo no existe o hay un error, devuelve una lista vacía.
  """

  def listar_sorteos(ruta \\ @archivo_sorteos) do
    Storage.leer_json(ruta)
  end

  @doc """
  Recibe un mapa con los datos del nuevo sorteo y lo guarda en el JSON.
  Valida que no exista ya un sorteo con el mismo ID.
  """
  def crear_sorteo(nuevo_sorteo, ruta \\ @archivo_sorteos) do
    sorteos_actuales = listar_sorteos(ruta)

    # Se verifica que el ID no exista previamente. Ingresa al mapa de sorteos_actuales y verifica si el ID concide con el nuevo.
    if Enum.any?(sorteos_actuales, fn sorteo -> sorteo["id"] == nuevo_sorteo["id"] end) do
      {:error, "Ya existe un sorteo con el ID: #{nuevo_sorteo["id"]}"}
    else
      # De lo contrario se agrega el nuevo sorteo a la lista en la cabeza de la misma.
      sorteos_actualizados = [nuevo_sorteo | sorteos_actuales]

      case Storage.guardar_json(ruta, sorteos_actualizados) do
        :ok -> {:ok, "Sorteo creado exitosamente"}
        error -> error
      end
    end
  end

  @doc """
  Elimina el sorteo por su ID.
  Aplica la la siguiente regla: No se puede eliminar si ya tiene premios asociados.
  """

  def eliminar_sorteo(id_sorteo, ruta \\ @archivo_sorteos) do
    sorteos_actuales = listar_sorteos(ruta)
    sorteo = Enum.find(sorteos_actuales, fn sorteo -> sorteo["id"] == id_sorteo end)

    case sorteo do
      nil ->
        {:error, "El sorteo con ID #{id_sorteo} no existe."}

      sorteo_encontrado ->
        # Se busca si tiene premios. Los premios vienen en una lista bajo la llave "premios"
        premios = Map.get(sorteo_encontrado, "premios", [])

        if Enum.empty?(premios) do
          # Si no tiene premios asociados, se filtra la lista para quitar el sorteo.
          sorteos_actualizados =
            Enum.reject(sorteos_actuales, fn sorteo -> sorteo["id"] == id_sorteo end)

          Storage.guardar_json(ruta, sorteos_actualizados)
          {:ok, "Sorteo eliminado exitosamente"}
        else
          # Se cumple la restricción, no se puede eliminar.
          {:error, "No se puedse eliminar el sorteo porque ya tiene premios asociados"}
        end
    end
  end

  @doc """
  Calcula el total de ingresos recaudados para un sorteo en específico.
  Busca en el archivo de usuarios todas las compras asociadas al ID del sorteo.
  u= Un usuario individual.
  acum= acumulador.
  """
  def consultar_ingresos(id_sorteo, ruta_usuarios \\ @archivo_usuarios) do
    # Se carga la estructura de los usuarios
    data = Storage.leer_json(ruta_usuarios)
    usuarios = Map.get(data, "usuarios", [])

    # Se extraen todas las compras de todos los usuarios
    todas_las_compras = Enum.flat_map(usuarios, fn u -> Map.get(u, "compras", []) end)

    # Se filtra el ID del sorteo y se suma el vlor pagado al total (acum)
    todas_las_compras
    |> Enum.filter(fn compra -> compra["id_sorteo"] == id_sorteo end)
    |> Enum.reduce(0, fn compra, acum -> acum + compra["valor_pagado"] end)
  end

  @doc """
  Devuelve una lista con el nombre de los clientes que han participado en un sorteo.
  c= Una compra individual.
  u= Un usuario individual.
  """
  def listar_clientes_por_sorteo(id_sorteo, ruta_usuarios \\ @archivo_usuarios) do
    data = Storage.leer_json(ruta_usuarios)
    usuarios = Map.get(data, "usuarios", [])

    usuarios
    |> Enum.filter(fn u ->
      compras = Map.get(u, "compras", [])
      Enum.any?(compras, fn c -> c["id_sorteo"] == id_sorteo end)
    end)
    # Se transforma cada mapa de usuario obtenido en un String unicamente con el nombre.
    |> Enum.map(fn usuario -> usuario["nombre"] end)
  end

  @doc """
  Calcula el balance total (ingresos - valor de premios) de un sorteo.
  p= Un premio individual.
  acum= acumulador.
  s= Un sorteo individual.
  """
  def balance_sorteo(
        id_sorteo,
        ruta_sorteos \\ @archivo_sorteos,
        ruta_usuarios \\ @archivo_usuarios
      ) do
    # Primero se obtienen los ingresos.
    ingresos = consultar_ingresos(id_sorteo, ruta_usuarios)

    # Se obtiene el valor total de los premios por sorteo
    sorteos = listar_sorteos(ruta_sorteos)
    sorteo = Enum.find(sorteos, fn s -> s["id"] == id_sorteo end)

    case sorteo do
      nil ->
        {:error, "Sorteo no encontrado"}

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

  # Admin premios
  @doc """
  Lista todos los premios configurados para un sorteo específico.
  """
  def listar_premios(id_sorteo, ruta_sorteos \\ @archivo_sorteos) do
    # Primero listamos todos los sorteos
    sorteos = listar_sorteos(ruta_sorteos)
    # Buscamos dentro de la lista de sorteos el que coincida con el id de sorteo solicitado.
    sorteo = Enum.find(sorteos, fn s -> s["id"] == id_sorteo end)

    case sorteo do
      nil -> {:error, "Sorteo no encontrado"}
      # Se extrae la lista de premios del sorteo encotnrado.
      s -> Map.get(s, "premios", [])
    end
  end

  @doc """
  Agrega un nuevo premio a la lista de premios de un sorteo.
  """

  def agregar_premio(id_sorteo, nuevo_premio, ruta_sorteos \\ @archivo_sorteos) do
    # Listamos todos los sorteos.
    sorteos = listar_sorteos(ruta_sorteos)

    # En la variable sorteos_actualizados se guardarán los sorteos anteriores + el nuevo sorteo siempre que el id coincida.
    sorteos_actualizados =
      Enum.map(sorteos, fn s ->
        if s["id"] == id_sorteo do
          # Se extraen los premios actuales para poder agregar el nuevo premio en el siguiente paso.
          premios_actuales = Map.get(s, "premios", [])
          # Se agrega el nuevo premio a la lista
          Map.put(s, "premios", [nuevo_premio | premios_actuales])
        else
          # De lo contrario los demás sorteos pasan iguales.
          s
        end
      end)

    Storage.guardar_json(ruta_sorteos, sorteos_actualizados)
  end

  @doc """
  Elimina un premio por su nombre, siempre y cuando el sorteo no tenga ventas.
  """
  def eliminar_premio(
        id_sorteo,
        nombre_premio,
        ruta_sorteos \\ @archivo_sorteos,
        ruta_usuarios \\ @archivo_usuarios
      ) do
    # Se obtiene la lista de usuarios
    data_usuarios = Storage.leer_json(ruta_usuarios)
    usuarios = Map.get(data_usuarios, "usuarios", [])

    # Se verifica si existe algún cliente para el sorteo. Extrae las compras del usuario y luego revisa si en esas compras alguna coincide con el id del sorteo.
    tiene_clientes =
      Enum.any?(usuarios, fn u ->
        compras = Map.get(u, "compras", [])
        Enum.any?(compras, fn c -> c["id_sorteo"] == id_sorteo end)
      end)

    #Verifica que si tiene clientes, entonces no se puede eliminar el premio. De lo contrario, se procede a eliminarlo.
    if tiene_clientes do
      {:error, "No se puede eliminar el premio porque hay clientes participando en el sorteo"}
    else
      # Si no hay clientes, entonces se procede a eliminar el premio. Se listan primero los sorteos.
      sorteos = listar_sorteos(ruta_sorteos)

      # sorteos_actualizados guardará los sorteos nuevos cuando se elimine el premio requerido.
      sorteos_actualizados =
        Enum.map(sorteos, fn s ->
          if s["id"] == id_sorteo do
            #Usando rejects, se filtra la lista de premios para eliminar el premio que coincida con el nombre del premio a eliminar.
            premios_filtrados =
              Enum.reject(s["premios"], fn p -> p["nombre"] == nombre_premio end)
            # Se actualiza el sorteo con la nueva lista de premios filtrada.
            Map.put(s, "premios", premios_filtrados)
          else
            # De lo contrario, los demás sorteos pasan igual.
            s
          end
        end)

      Storage.guardar_json(ruta_sorteos, sorteos_actualizados)
      {:ok, "Premio eliminado exitosamente"}
    end
  end
end
