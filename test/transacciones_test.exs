defmodule AzarSa.TransaccionesTest do
  use ExUnit.Case, async: false

  alias AzarSa.Transacciones
  alias AzarSa.Storage

  @prueba_usuarios "data/dummy_usuarios_trx.json"
  @prueba_sorteos "data/dummy_sorteos_trx.json"

  setup do
    #Se prepara los Sorteos Dummy
    sorteos = [
      %{"id" => "S-001", "nombre" => "Sorteo Activo", "estado" => "activo"},
      %{"id" => "S-002", "nombre" => "Sorteo Jugado", "estado" => "jugado"}
    ]
    Storage.guardar_json(@prueba_sorteos, sorteos)

    #Se prepara también un usuario Dummy
    usuarios = %{
      "usuarios" => [
        %{
          "documento" => "12345",
          "nombre" => "Jugador de Prueba",
          "compras" => []
        }
      ]
    }
    Storage.guardar_json(@prueba_usuarios, usuarios)

    #Al terminar, se eliminan ambos archivos dummy para no afectar el entorno real de la app.
    on_exit(fn ->
      File.rm(@prueba_usuarios)
      File.rm(@prueba_sorteos)
    end)

    :ok
  end

  describe "consultar_sorteos_disponibles" do

    test "Retorna únicamente los sorteos que NO están jugados" do
      disponibles = Transacciones.consultar_sorteos_disponibles(@prueba_sorteos)

      # Solo debería traer 1 sorteo (el S-001)
      assert length(disponibles) == 1
      assert Enum.at(disponibles, 0)["id"] == "S-001"

      # Nos aseguramos de que el S-002 (jugado) no esté en la lista
      refute Enum.any?(disponibles, fn s -> s["id"] == "S-002" end)
    end

  end

  describe "comprar_billete" do

    test "Procesa exitosamente la compra si el usuario existe y el sorteo está activo" do
      resultado = Transacciones.comprar_billete(
        "12345", "S-001", 88, "completo", 50000,
        @prueba_usuarios, @prueba_sorteos
      )

      assert {:ok, nueva_compra} = resultado
      assert nueva_compra["id_sorteo"] == "S-001"
      assert nueva_compra["numero_billete"] == 88

      # Verificamos que se haya guardado físicamente en el perfil del usuario dummy
      datos_guardados = Storage.leer_json(@prueba_usuarios)
      usuario_actualizado = Enum.find(datos_guardados["usuarios"], fn u -> u["documento"] == "12345" end)

      assert length(usuario_actualizado["compras"]) == 1
    end

    test "Bloquea la compra y devuelve error si el sorteo ya se jugó o no existe" do
      # Intentamos comprar en el S-002 que tiene estado "jugado"
      resultado = Transacciones.comprar_billete(
        "12345", "S-002", 15, "fraccion", 10000,
        @prueba_usuarios, @prueba_sorteos
      )

      assert {:error, "El sorteo no está disponible o ya fue jugado."} = resultado
    end

    test "Bloquea la compra si el documento del usuario no existe en la base de datos" do
      # Usamos un documento "999" que no creamos en el setup
      resultado = Transacciones.comprar_billete(
        "999", "S-001", 10, "completo", 50000,
        @prueba_usuarios, @prueba_sorteos
      )

      assert {:error, "No se encontró un usuario con el documento proporcionado."} = resultado
    end

  end
end
