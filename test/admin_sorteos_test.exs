defmodule AzarSa.AdminSorteosTest do
  use ExUnit.Case

  alias AzarSa.AdminSorteos
  alias AzarSa.Storage

  @prueba_sorteos "data/dummy_sorteos.json"

  describe "crear_sorteo/2" do
    test "Crear un sorteo exitosamente si el ID es nuevo" do
      # Se crea un archivo nuevo y limpio.
      Storage.guardar_json(@prueba_sorteos, [])

      # Creación del nuevo sorteo
      nuevo_sorteo = %{"id" => "S-001", "nombre" => "Sorteo Extra", "premios" => []}

      # Se verifica si el sorteo recién creado se guarda de forma correcta
      assert {:ok, "Sorteo creado exitosamente"} ==
               AdminSorteos.crear_sorteo(nuevo_sorteo, @prueba_sorteos)

      # Se obtiene la lista de sorteos y se confirma el guardado.
      sorteos_guardados = AdminSorteos.listar_sorteos(@prueba_sorteos)
      assert Enum.any?(sorteos_guardados, fn sorteo -> sorteo["id"] == "S-001" end)

      # Se elimina el archivo al finalizar.
      File.rm(@prueba_sorteos)
    end

    test "Falla y devuelve error si el ID ya existe" do
      # Se crea un archivo nuevo y limpio.
      Storage.guardar_json(@prueba_sorteos, [])

      # Creación del nuevo sorteo
      nuevo_sorteo = %{"id" => "S-001", "nombre" => "Sorteo Extra", "premios" => []}

      # Se agrega el sorteo que se acaba de crear.
      AdminSorteos.crear_sorteo(nuevo_sorteo, @prueba_sorteos)

      # Se crea el sorteo duplicado.
      sorteo_duplicado = %{"id" => "S-001", "nombre" => "Sorteo Extra", "premios" => []}

      assert {:error, "Ya existe un sorteo con el ID: S-001"} ==
               AdminSorteos.crear_sorteo(sorteo_duplicado, @prueba_sorteos)

      # Se elimina el archivo al finalizar.
      File.rm(@prueba_sorteos)
    end
  end

  describe "eliminar_sorteo/2" do
    test "Elimina el sorteo exitosamente si no tiene premios asociados" do
      # Se crea un archivo nuevo y limpio.
      Storage.guardar_json(@prueba_sorteos, [])
      # Creación del nuevo sorteo
      nuevo_sorteo = %{"id" => "S-001", "nombre" => "Sorteo Extra", "premios" => []}
      # Se agrega el sorteo que se acaba de crear.
      AdminSorteos.crear_sorteo(nuevo_sorteo, @prueba_sorteos)

      # Se eliminar el sorteo creado previamente
      assert {:ok, "Sorteo eliminado exitosamente"} ==
               AdminSorteos.eliminar_sorteo("S-001", @prueba_sorteos)

      # Verificar que la lista de sorteos de prueba haya quedado vacía.
      assert AdminSorteos.listar_sorteos(@prueba_sorteos) == []

      # Se elimina el archivo al finalizar.
      File.rm(@prueba_sorteos)
    end

    test "Falla y devuelve un error si intenta eliminar un sorteo que ya tiene premios" do
      # Se crea un archivo nuevo y limpio.
      Storage.guardar_json(@prueba_sorteos, [])

      sorteo_con_premios = %{
        "id" => "S-001",
        "nombre" => "Sorteo Especial",
        "premios" => [%{"nombre" => "Premio Mayor", "valor" => 1_000_000}]
      }

      AdminSorteos.crear_sorteo(sorteo_con_premios, @prueba_sorteos)
      # Verifica que al intentar eliminar el sorteo, responda con la tupla correcta.
      assert {:error, "No se puedse eliminar el sorteo porque ya tiene premios asociados"} ==
               AdminSorteos.eliminar_sorteo("S-001", @prueba_sorteos)

      # Se elimina el archivo al finalizar.
      File.rm(@prueba_sorteos)
    end
  end
end
