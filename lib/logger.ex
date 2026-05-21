defmodule AzarSa.Logger do
  @moduledoc """
  Módulo encargado de registrar los eventos y operaciones del sistema en una bitácora física y en la consola.
  """

  @doc """
  Registra una operación en la ruta específicada (por defecto 'data/bitacora.txt') y la muestra en consola.
  Retorna :ok o {:error, razon} enc aso de fallo.
  """

  def registrar_log(solicitud, resultado, ruta \\ "data/bitacora.txt") do
    fecha_hora = obtener_fecha_hora()
    # Línea que se utilizará para insertar en la bitácora y mostrar en la consola.
    linea = "#{fecha_hora} - Solicitud: #{solicitud} - Resultado: #{resultado}\n"

    # Se muestra en la pantalla
    IO.puts("LOG: #{String.trim(linea)}")

    # Se guarda en el archivo físico
    case File.write(ruta, linea, [:append]) do
      :ok ->
        :ok

      {:error, razon} ->
        IO.puts("Se presentó un error al escribir en la bitácora: #{razon}")
        {:error, razon}
    end
  end

  # Función para formatear la fecha y hora actual en un formato legible. Solo se utilizará en este módulo.
  defp obtener_fecha_hora do
    {{y, m, d}, {h, min, seg}} = :calendar.local_time()
    # Aseguramos ceros a la izquierda para que se vea ordenado (ej: 05/09/2026 08:05:01)
    fecha = "#{pad(d)}/#{pad(m)}/#{y}"
    hora = "#{pad(h)}:#{pad(min)}:#{pad(seg)}"
    "#{fecha} #{hora}"
  end

  defp pad(numero) do
    numero
    |> Integer.to_string()
    |> String.pad_leading(2, "0")
  end
end
