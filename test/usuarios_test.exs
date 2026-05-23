defmodule AzarSa.UsuariosTest do
  use ExUnit.Case, async: false

  alias AzarSa.Usuarios
  alias AzarSa.Storage

  @prueba_usuarios "data/dummy_usuarios.json"

  setup do
    # 1. Se crea un archivo nuevo y limpio específico para el test.
    Storage.guardar_json(@prueba_usuarios, %{"usuarios" => []})

    # 2. Se asegura su eliminación total al finalizar, sin tocar el archivo real de la app.
    #on_exit(fn ->
     # File.rm(@prueba_usuarios)
    #end)

    :ok
  end

  describe "Registro de Usuarios" do
    test "registrar_usuario/5 guarda un usuario exitosamente en el JSON dummy" do
      resultado = Usuarios.registrar_usuario("12345", "Cristian", "qa_pass", "1111", @prueba_usuarios)

      assert {:ok, usuario} = resultado
      assert usuario["documento"] == "12345"
      assert usuario["compras"] == []

      # Verificamos la lectura sobre el archivo dummy
      datos_guardados = Storage.leer_json(@prueba_usuarios)
      assert length(datos_guardados["usuarios"]) == 1
    end

    test "registrar_usuario/5 bloquea el registro si el documento ya existe" do
      Usuarios.registrar_usuario("9999", "Original", "pass1", "0000", @prueba_usuarios)
      resultado = Usuarios.registrar_usuario("9999", "Copia", "pass2", "1111", @prueba_usuarios)

      assert {:error, "El usuario con documento 9999 ya se encuentra registrado."} = resultado
    end
  end

  describe "Autenticación (Login)" do
    test "autenticar/3 permite el acceso con credenciales correctas" do
      Usuarios.registrar_usuario("777", "Marisol", "secreto", "4590", @prueba_usuarios)
      resultado = Usuarios.autenticar("777", "secreto", @prueba_usuarios)

      assert {:ok, usuario} = resultado
      assert usuario["documento"] == "777"
    end

    test "autenticar/3 niega el acceso con contraseña incorrecta" do
      Usuarios.registrar_usuario("888", "Jugador", "correcta", "4590", @prueba_usuarios)
      resultado = Usuarios.autenticar("888", "falsa", @prueba_usuarios)

      assert {:error, "Documento o contraseña incorrectos"} = resultado
    end
  end
end
