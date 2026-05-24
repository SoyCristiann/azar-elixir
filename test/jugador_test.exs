defmodule AzarSa.JugadorTest do
  use ExUnit.Case, async: false

  alias AzarSa.Jugador
  alias AzarSa.Storage

  @prueba_usuarios "data/dummy_jugador_usuarios.json"
  @prueba_sorteos "data/dummy_jugador_sorteos.json"

  setup do
    #Agrega "num_fracciones" a los sorteos de prueba
    sorteos = %{
      "sorteos" => [
        %{
          "id" => "S-001",
          "estado" => "pendiente",
          "total_billetes" => 5,
          "num_fracciones" => 10 # <-- Requisito
        },
        %{
          "id" => "S-002",
          "estado" => "jugado",
          "total_billetes" => 5,
          "num_fracciones" => 10
        }
      ]
    }

    #Agrega el "tipo" de compra (completo o fraccion)
    usuarios = %{
      "usuarios" => [
        %{
          "documento" => "123",
          "compras" => [
            %{"id_sorteo" => "S-001", "numero_billete" => 2, "tipo" => "completo", "valor_pagado" => 10_000},
            %{"id_sorteo" => "S-002", "numero_billete" => 1, "tipo" => "completo", "valor_pagado" => 15_000}
          ],
          "premios_ganados" => [
            %{"nombre_premio" => "Premio Menor", "valor" => 50_000}
          ],
          "notificaciones" => [
            "¡Felicidades, ganaste!"
          ]
        }
      ]
    }

    Storage.guardar_json(@prueba_sorteos, sorteos)
    Storage.guardar_json(@prueba_usuarios, usuarios)

    on_exit(fn ->
      File.rm(@prueba_sorteos)
      File.rm(@prueba_usuarios)
    end)

    :ok
  end

  describe "consultar_historial/2" do
    test "devuelve la lista de compras y la suma total de lo gastado" do
      assert {:ok, resultado} = Jugador.consultar_historial("123", @prueba_usuarios)

      assert length(resultado.compras) == 2
      assert resultado.total_gastado == 25_000
    end

    test "devuelve error si el usuario no existe" do
      assert {:error, "Usuario no encontrado"} == Jugador.consultar_historial("999", @prueba_usuarios)
    end
  end

  describe "consultar_balance/2" do
    test "calcula correctamente la diferencia entre premios y gastos" do
      assert {:ok, balance} = Jugador.consultar_balance("123", @prueba_usuarios)

      assert balance.gastado == 25_000
      assert balance.ganado == 50_000
      assert balance.balance_neto == 25_000
    end
  end

  describe "ver_notificaciones_y_premios/2" do
    test "devuelve los premios y notificaciones del usuario" do
      assert {:ok, info} = Jugador.ver_notificaciones_y_premios("123", @prueba_usuarios)

      assert length(info.premios) == 1
      assert length(info.notificaciones) == 1
      assert hd(info.notificaciones) == "¡Felicidades, ganaste!"
    end
  end

  describe "consultar_numeros_disponibles/3" do
    test "devuelve la estructura diferenciada de billetes completos y fracciones" do
      #Evalua el formato de respuesta (Mapa)
      # El usuario "123" compró el billete #2 de forma "completa".
      assert {:ok, disponibles} = Jugador.consultar_numeros_disponibles("S-001", @prueba_sorteos, @prueba_usuarios)

      # El billete 2 ya no debe estar disponible ni en completos ni en fracciones
      assert disponibles.billetes_completos == [1, 3, 4, 5]
      assert disponibles.fracciones == [1, 3, 4, 5]

      refute Enum.member?(disponibles.billetes_completos, 2)
      refute Enum.member?(disponibles.fracciones, 2)
    end

    test "devuelve error si el sorteo no existe" do
      assert {:error, "Sorteo no encontrado"} == Jugador.consultar_numeros_disponibles("S-XYZ", @prueba_sorteos, @prueba_usuarios)
    end
  end

  describe "devolver_compra/5" do
    test "permite devolver la compra y eliminarla del historial si el sorteo está pendiente" do
      assert {:ok, "Compra devuelta exitosamente. Dinero reembolsado."} ==
               Jugador.devolver_compra("123", "S-001", 2, @prueba_usuarios, @prueba_sorteos)

      {:ok, historial} = Jugador.consultar_historial("123", @prueba_usuarios)
      assert length(historial.compras) == 1
      assert historial.total_gastado == 15_000
    end

    test "deniega la devolución si el sorteo ya fue jugado" do
      assert {:error, "No se puede devolver la compra. El sorteo ya fue jugado o no existe."} ==
               Jugador.devolver_compra("123", "S-002", 1, @prueba_usuarios, @prueba_sorteos)
    end

    test "deniega la devolución si el billete no corresponde a ese usuario" do
      assert {:error, "No se encontró el billete asociado a este usuario en el sorteo indicado."} ==
               Jugador.devolver_compra("123", "S-001", 5, @prueba_usuarios, @prueba_sorteos)
    end
  end
end
