defmodule AzarSa.AdminSorteosTest do
  use ExUnit.Case

  alias AzarSa.AdminSorteos
  alias AzarSa.Storage

  @prueba_usuarios "data/dummy_usuarios.json"
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

  describe "Funciones de análisis financiero y clientes/4" do
    # Se crea el bloque setup que se ejecutará antes de cada pruieba de este bloque, esto con el fin de crear el archivo dummy necesario.
    setup do
      # Se prepara el archivo dummy de los sorteos.
      sorteos = [
        %{
          "id" => "S-001",
          "premios" => [
            # Total de premios: $70.000
            %{"valor" => 50_000},
            %{"valor" => 20_000}
          ]
        }
      ]

      # Se guarda en un nuevo archivo dummy el sorteo previamente creado.
      Storage.guardar_json(@prueba_sorteos, sorteos)

      # Se prepara un archivo de usuairos Dummy
      usuarios = %{
        "usuarios" => [
          %{
            "nombre" => "Pedro",
            "compras" => [
              %{"id_sorteo" => "S-001", "valor_pagado" => 20_000},
              %{"id_sorteo" => "S-001", "valor_pagado" => 20_000}
            ]
          },
          %{
            "nombre" => "Pablo",
            "compras" => [
              %{"id_sorteo" => "S-001", "valor_pagado" => 60_000},
              %{"id_sorteo" => "S-002", "valor_pagado" => 15_000}
            ]
          },
          %{
            "nombre" => "Carmen",
            "compras" => [
              %{"id_sorteo" => "S-002", "valor_pagado" => 30_000}
            ]
          }
        ]
      }

      # Se guarda el archivo de usuarios en la ruta dummy.
      Storage.guardar_json(@prueba_usuarios, usuarios)

      # Aseguramos que después de cada test los archivos se borren.
      on_exit(fn ->
        File.rm(@prueba_sorteos)
        File.rm(@prueba_usuarios)
      end)

      :ok
    end

    test "consultar_ingresos suma correctamente el valor de los billetes" do
      # La suma total para el sorteo "S-001" es 100.000
      assert AdminSorteos.consultar_ingresos("S-001", @prueba_usuarios) == 100_000
      # La suma total para el sorteo "S-002" es 45.000
      assert AdminSorteos.consultar_ingresos("S-002", @prueba_usuarios) == 45_000
      # Prueba con un sorteo que no tiene compras
      assert AdminSorteos.consultar_ingresos("S-000", @prueba_usuarios)
    end

    test "listar_clientes_por_sorteo devuelve solo los nombres de los compradores correctos" do
      # Se obtiene la lista de clientes, en este caso para el sorteo "S-001".
      clientes_sorteo1 = AdminSorteos.listar_clientes_por_sorteo("S-001", @prueba_usuarios)

      assert length(clientes_sorteo1) == 2
      assert Enum.member?(clientes_sorteo1, "Pedro")
      assert Enum.member?(clientes_sorteo1, "Pablo")

      # Carmen no hace parte del sorteo "S-001", por lo que se usa 'refute' esperando obtener false.
      refute Enum.member?(clientes_sorteo1, "Carmen")
    end

    test "balance_sorteo calcula la rentabilidad cruzando datos de ambos archivos" do
      # El sorteo "S-001" recaudó 100.000 y sus premios cuestan 70.000. Balance = +30.000. Se obtiene el balance.
      resultado = AdminSorteos.balance_sorteo("S-001", @prueba_sorteos, @prueba_usuarios)

      # Se compara cada uno de los datos obtenidos.
      assert resultado["id_sorteo"] == "S-001"
      assert resultado["ingresos"] == 100_000
      assert resultado["costo_premios"] == 70_000
      assert resultado["balance_neto"] == 30_000
    end

    test "balance_sorteo devuelve error si el sorteo no existe" do
      assert {:error, "Sorteo no encontrado"} ==
               AdminSorteos.balance_sorteo("S-XYZ", @prueba_sorteos, @prueba_usuarios)
    end
  end


  describe "Gestión de premios Admin/3" do
    setup do
      # Se crea el sorteo S-001 con un premio inicial
      sorteos = [
        %{
          "id" => "S-001",
          "nombre" => "Sorteo Test",
          "premios" => [%{"nombre" => "Premio Base", "valor" => 10_000}]
        }
      ]
      Storage.guardar_json(@prueba_sorteos, sorteos)

      # 2. Escenario de Usuarios: Sin compras inicialmente
      Storage.guardar_json(@prueba_usuarios, %{"usuarios" => []})

      on_exit(fn ->
        File.rm(@prueba_sorteos)
        File.rm(@prueba_usuarios)
      end)

      :ok
    end

    test "agregar_premio inserta un nuevo premio en el sorteo correcto" do
      nuevo_premio= %{"nombre" => "Premio Mayor", "valor" => 500_000}
      AdminSorteos.agregar_premio("S-001", nuevo_premio, @prueba_sorteos)

      premios= AdminSorteos.listar_premios("S-001", @prueba_sorteos)
      # Se verifica que el nuevo premio se haya agregado correctamente al sorteo S-001.
      assert Enum.any?(premios, fn p-> p["nombre"] == "Premio Mayor" and p["valor"] == 500_000 end)
    end


    test "eliminar_premio eliminar el premio si no hay clientes asociados al sorteo" do
      #Se intenta eliminar el premio base de un sorteo sin ventas.
      assert {:ok, "Premio eliminado exitosamente"} == AdminSorteos.eliminar_premio("S-001", "Premio Base", @prueba_sorteos, @prueba_usuarios)

      #Lista los premios
      premios= AdminSorteos.listar_premios("S-001", @prueba_sorteos)
      #A través del refute, esperando un false como respuesta, se verifica que el premio ya no esté en la lista de premios del sorteo S-001.
      refute Enum.any?(premios, fn p -> p["nombre"] == "Premio Base" end)
    end

    test "eliminar_premio no eliminar el premio si hay clientes asociados al sorteo" do
      #Primero se crea y guarda un usuario con compra para el sorteo S-001.
      usuarios_con_venta = %{
        "usuarios" => [
          %{"nombre" => "Juan", "compras" => [%{"id_sorteo" => "S-001", "valor_pagado" => 5_000}]}
        ]
      }
      Storage.guardar_json(@prueba_usuarios, usuarios_con_venta)

      #Se intenta eliminar el premio.
      assert{{:error, "No se puede eliminar el premio porque hay clientes participando en el sorteo"} == AdminSorteos.eliminar_premio("S-001", "Premio Base", @prueba_sorteos, @prueba_usuarios)}

      #Se verifica que el premio siga en la lista de premios del sorteo S-001
      premios= AdminSorteos.listar_premios("S-001", @prueba_sorteos)
      assert Enum.any?(premios, fn p -> p["nombre"] == "Premio Base" end)
    end
  end
end
