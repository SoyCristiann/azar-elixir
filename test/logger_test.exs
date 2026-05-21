defmodule AzarSa.LoggerTest do
  use ExUnit.Case
  alias AzarSa.Logger

  @ruta_prueba "data/bitacora_test.txt"

  test "registrar_log anexa las líneas correctamente" do
    # 1. Se limpia cualquier rastro previo
    File.rm(@ruta_prueba)

    # 2. Simular dos peticiones distintas
    assert Logger.registrar_log("Compra billete 001", "Aprobado", @ruta_prueba) == :ok
    assert Logger.registrar_log("Consulta saldo", "Exitoso", @ruta_prueba) == :ok

    # 3. Leer todo el archivo creado
    {:ok, contenido} = File.read(@ruta_prueba)

    # 4. Verificar que ambos registros estén presentes
    assert String.contains?(contenido, "Compra billete 001")
    assert String.contains?(contenido, "Consulta saldo")

    # 5. Dejar nuevamente el entorno limpio el entorno limpio
    File.rm(@ruta_prueba)
  end
end
