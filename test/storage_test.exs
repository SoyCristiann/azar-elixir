defmodule AzarSa.StorageTest do
  use ExUnit.Case
  alias AzarSa.Storage

  @ruta_prueba "data/test_temp.json"

  test "guardar_json crea un archivo correctamente" do
    datos = %{"test" => "Prueba de JSON"}

    # Ejecutar la función y verificar que devuelva el atom :ok.
    assert Storage.guardar_json(@ruta_prueba, datos) == :ok

    # Revisar que el archivo se haya creado en la ruta correcta.
    assert File.exists?(@ruta_prueba)

    # Se elimina el archivo después de la prueba.
    File.rm(@ruta_prueba)
  end

  test "leer_json retorna una lista vacía si el archivo no existe" do
    assert Storage.leer_json("data/archivo_fantasma.json") == []
  end

  test "leer_json lanza un error si el JSON está mal formado" do
    ruta_corrupta = "data/corrupto.json"
    # Creamos un archivo con un JSON inválido (le falta cerrar el corchete)
    File.write!(ruta_corrupta, "{ \"id\": 1 ")

    # Como en el storage se utilizó Jason.decode!, se espera un Jason.DecodeError como respuesta.
    assert_raise Jason.DecodeError, fn ->
      Storage.leer_json(ruta_corrupta)
    end

    # Se elimina el archivo después de la prueba.
    File.rm(ruta_corrupta)
  end
end
