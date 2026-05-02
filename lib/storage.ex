defmodule AzarSa.Storage do
  @moduledoc """
  Módulo encargado de leer y escribir archivos JSON.
  """
  @doc """
    Función que lee un archivo en formato JSON y lo decodifica en un mapa retornándolo para ser utilizado.
    ## Parámetros
    - ruta: Es la ruta del archivo JSON que se va a leer.

    ## Ejemplos
    - iex> AzarSa.Storage.leer_json("data/sorteos.json")
  """
  def leer_json(ruta) do
    case File.read(ruta) do
      {:ok, contenido_texto} ->
        #Se utiliza la librería JASON para decodificar convertir el archivo en un mapa.
        Jason.decode!(contenido_texto)

      {:error, _razon} ->
        #IO.puts("Se presento un error al leer el archivo JSON: #{razon}")
        # Se devuelve la lista vacía.
        []
    end
  end

  @doc """
    Función que guarda un archivo en formato JSON en una ruta indicada. Retorna la confirmación :ok o {:error, detalle_error}

    ## Parámetros
      - ruta: Ruta donde se va a guardar el archivo JSON.
      - mapa_nuevos_datos: Es el mapa con la nueva información que se convertira en un archivo JSON y será guardado en la ruta indicada.

    ##Ejemplos
      - iex> AzarSa.Storage.guardar_json("data/nuevo_archivo.json", mapa_datos)
  """
  def guardar_json(ruta, mapa_nuevos_datos) do
    #Se utiliza la librería JASON para convertir el mapa en un archivo JSON con estilo.
    texto_json= Jason.encode!(mapa_nuevos_datos, pretty: true)

    #Se procede a escribir en el archivo JSON y se evalúa si fue exitoso o no
    case File.write(ruta, texto_json) do
      :ok ->
        #IO.puts("El archivo '#{ruta}' se creó de forma correcta.")
        :ok

      {:error, razon} ->
        {:error, razon}
        #IO.puts("Se presentó un error al crear el archivo '#{ruta}': #{razon}")
    end

  end

end
