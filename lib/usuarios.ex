defmodule AzarSa.Usuarios do
  @archivo "data/usuarios.json"

  def registrar_usuario(documento, nombre, password, tarjeta, ruta \\ @archivo) do
    datos = leer_datos(ruta)
    usuarios_actuales = Map.get(datos, "usuarios", [])

    existe? = Enum.any?(usuarios_actuales, fn u -> u["documento"] == documento end)

    if existe? do
      AzarSa.Logger.registrar_log("Registro Usuario [#{documento}]", "NEGADO - Documento duplicado")
      {:error, "El usuario con documento #{documento} ya se encuentra registrado."}
    else
      nuevo_usuario = %{
        "documento" => documento,
        "nombre" => nombre,
        "password" => password,
        "tarjeta" => tarjeta,
        "compras" => [],
        "notificaciones" => []
      }

      usuarios_actualizados = usuarios_actuales ++ [nuevo_usuario]
      nuevo_estado = %{"usuarios" => usuarios_actualizados}

      AzarSa.Storage.guardar_json(ruta, nuevo_estado)
      AzarSa.Logger.registrar_log("Registro Usuario [#{documento}]", "OK - Registrado exitosamente")

      {:ok, nuevo_usuario}
    end
  end

  def autenticar(documento, password, ruta \\ @archivo) do
    datos = leer_datos(ruta)
    usuarios = Map.get(datos, "usuarios", [])

    usuario = Enum.find(usuarios, fn u -> u["documento"] == documento and u["password"] == password end)

    if usuario do
      AzarSa.Logger.registrar_log("Login [#{documento}]", "OK")
      {:ok, usuario}
    else
      AzarSa.Logger.registrar_log("Login [#{documento}]", "NEGADO - Credenciales inválidas")
      {:error, "Documento o contraseña incorrectos"}
    end
  end

  defp leer_datos(ruta) do
    case AzarSa.Storage.leer_json(ruta) do
      [] -> %{"usuarios" => []}
      %{"usuarios" => _} = datos -> datos
      _ -> %{"usuarios" => []}
    end
  end
end
