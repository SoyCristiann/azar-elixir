defmodule AzarSa.FinanzasTest do
  use ExUnit.Case, async: false

  alias AzarSa.Finanzas
  alias AzarSa.Storage

  @prueba_usuarios "data/dummy_usuarios_fin.json"
  @prueba_sorteos "data/dummy_sorteos_fin.json"

  setup do
    #Se crea Un sorteo con premios definidos
    sorteos = [
      %{
        "id" => "S-001",
        "premios" => [
          %{"nombre" => "Premio Mayor", "valor" => 50000},
          %{"nombre" => "Premio Secundario", "valor" => 20000}
        ]
      }
    ]
    Storage.guardar_json(@prueba_sorteos, sorteos)

    #Se crea un usuario con compras y premios ganados
    usuarios = %{
      "usuarios" => [
        %{
          "documento" => "12345",
          "nombre" => "Cristian",
          "compras" => [
            %{"id_sorteo" => "S-001", "valor_pagado" => 20000},
            %{"id_sorteo" => "S-001", "valor_pagado" => 30000}
          ],
          "premios_ganados" => [
            %{"id_sorteo" => "S-001", "nombre_premio" => "Premio Secundario", "valor" => 20000}
          ]
        }
      ]
    }
    Storage.guardar_json(@prueba_usuarios, usuarios)

    on_exit(fn ->
      File.rm(@prueba_usuarios)
      File.rm(@prueba_sorteos)
    end)

    :ok
  end

  describe "calcular_balance_sorteo" do
    test "Calcula correctamente los ingresos, costos y balance neto" do
      # Ingresos: 20k + 30k = 50k
      # Costos (Premios): 50k + 20k = 70k
      # Balance: 50k - 70k = -20k

      resultado = Finanzas.calcular_balance_sorteo("S-001", @prueba_sorteos, @prueba_usuarios)

      assert resultado["ingresos"] == 50000
      assert resultado["costo_premios"] == 70000
      assert resultado["balance_neto"] == -20000
    end

    test "Retorna error si el sorteo no existe" do
      assert {:error, "Sorteo no encontrado"} ==
             Finanzas.calcular_balance_sorteo("S-999", @prueba_sorteos, @prueba_usuarios)
    end
  end

  describe "balance_personal" do
    test "Calcula correctamente el balance individual del usuario" do
      # Gastado: 20k + 30k = 50k
      # Ganado: 20k
      # Balance: 20k - 50k = -30k

      resultado = Finanzas.balance_personal("12345", @prueba_usuarios)

      assert resultado["nombre"] == "Cristian"
      assert resultado["total_gastado"] == 50000
      assert resultado["total_ganado"] == 20000
      assert resultado["balance"] == -30000
    end

    test "Retorna error si el usuario no existe" do
      assert {:error, "Usuario no encontrado"} == Finanzas.balance_personal("00000", @prueba_usuarios)
    end
  end
end
