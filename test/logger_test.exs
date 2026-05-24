defmodule AzarSa.LoggerTest do
  use ExUnit.Case, async: false
  alias AzarSa.Logger

  @ruta_prueba "data/bitacora_test.txt"

  test "registrar_log anexa las líneas correctamente" do
    #Se limpia cualquier rastro previo
    File.rm(@ruta_prueba)

    #Simular dos peticiones distintas
    assert Logger.registrar_log("Compra billete 001", "Aprobado", @ruta_prueba) == :ok
    assert Logger.registrar_log("Consulta saldo", "Exitoso", @ruta_prueba) == :ok

    #Leer todo el archivo creado
    {:ok, contenido} = File.read(@ruta_prueba)

    #Verificar que ambos registros estén presentes
    assert String.contains?(contenido, "Compra billete 001")
    assert String.contains?(contenido, "Consulta saldo")

    #Dejar nuevamente el entorno limpio el entorno limpio
    File.rm(@ruta_prueba)
  end

  test "registrar_log retorna un error controlado si la ruta es inválida" do
      ruta_invalida = "/root/archivo_prohibido.txt"

      resultado = AzarSa.Logger.registrar_log("Prueba", "Error", ruta_invalida)

      assert resultado == {:error, :eacces} or resultado == {:error, :enoent}
    end
end
