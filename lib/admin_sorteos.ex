defmodule AzarSa.AdminSorteos do
  alias AzarSa.Storage #Utilizamos alias para acceder de forma más fácil al módulo.
  @archivo "data/sorteos.json" #Se define el atributo del módulo para acceder a la ruta de sorteos, similar a una constante.

  #Para recordar:
  #Lambdas: fn argumentos -> cuerpo_de_la_funcion end
  #Se agrega \\ para utilizar @archivo como un parámetro opcional en caso de no pasar la ruta. Especificamente para las pruebas.

  @doc """
  Lee el archivo JASON y devuelve la liusta de todos los sorteos.
  Si el archivo no existe o hay un error, devuelve una lista vacía.
  """

  def listar_sorteos(ruta \\ @archivo) do
    Storage.leer_json(ruta)
  end

  @doc """
  Recibe un mapa con los datos del nuevo sorteo y lo guarda en el JSON.
  Valida que no exista ya un sorteo con el mismo ID.
  """
  def crear_sorteo(nuevo_sorteo, ruta \\ @archivo) do
    sorteos_actuales= listar_sorteos(ruta)
    #Se verifica que el ID no exista previamente. Ingresa al mapa de sorteos_actuales y verifica si el ID concide con el nuevo.
    if Enum.any?(sorteos_actuales, fn sorteo-> sorteo["id"] == nuevo_sorteo["id"] end) do
      {:error, "Ya existe un sorteo con el ID: #{nuevo_sorteo["id"]}"}
    else
      #De lo contrario se agrega el nuevo sorteo a la lista en la cabeza de la misma.
      sorteos_actualizados= [nuevo_sorteo | sorteos_actuales]
      case Storage.guardar_json(ruta, sorteos_actualizados) do
        :ok -> {:ok, "Sorteo creado exitosamente"}
        error -> error
      end
    end
  end


  @doc"""
  Elimina el sorteo por su ID.
  Aplica la la siguiente regla: No se puede eliminar si ya tiene premios asociados.
  """

  def eliminar_sorteo(id_sorteo, ruta \\ @archivo) do
    sorteos_actuales= listar_sorteos(ruta)
    sorteo= Enum.find(sorteos_actuales, fn sorteo-> sorteo["id"] == id_sorteo end)

    case sorteo do
      nil ->
        {:error, "El sorteo con ID #{id_sorteo} no existe."}

      sorteo_encontrado ->
        # Se busca si tiene premios. Los premios vienen en una lista bajo la llave "premios"
        premios= Map.get(sorteo_encontrado, "premios", [])
        if Enum.empty?(premios) do
          #Si no tiene premios asociados, se filtra la lista para quitar el sorteo.
          sorteos_actualizados= Enum.reject(sorteos_actuales, fn sorteo-> sorteo["id"] == id_sorteo end)
          Storage.guardar_json(ruta, sorteos_actualizados)
          {:ok, "Sorteo eliminado exitosamente"}

          else
          #Se cumple la restricción, no se puede eliminar.
          {:error, "No se puedse eliminar el sorteo porque ya tiene premios asociados"}
        end
    end
  end
end
