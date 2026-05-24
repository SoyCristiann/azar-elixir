defmodule AzarSa.Logger do
  @moduledoc """
  Módulo encargado de registrar los eventos y operaciones del sistema en una bitácora física y en la consola.
  """

  def registrar_log(solicitud, resultado, ruta \\ "data/bitacora.txt") do
    fecha_hora = obtener_fecha_hora()
    linea = "#{fecha_hora} - Solicitud: #{solicitud} - Resultado: #{resultado}\n"

    #Mostrar en consola
    IO.puts("LOG: #{String.trim(linea)}")

    #Asegurar que el directorio exista antes de escribir
    directorio = Path.dirname(ruta)
    File.mkdir_p!(directorio)

    #Guardar en el archivo
    case File.write(ruta, linea, [:append]) do
      :ok ->
        :ok

      {:error, razon} ->
        IO.puts("Se presentó un error al escribir en la bitácora: #{razon}")
        {:error, razon}
    end
  end

  defp obtener_fecha_hora do
    {{y, m, d}, {h, min, seg}} = :calendar.local_time()
    "#{pad(d)}/#{pad(m)}/#{y} #{pad(h)}:#{pad(min)}:#{pad(seg)}"
  end

  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(2, "0")
end
