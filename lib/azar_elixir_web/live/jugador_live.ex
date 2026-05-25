defmodule AzarElixirWeb.JugadorLive do
  use AzarElixirWeb, :live_view

  # Ajuste: Quitamos TransaccionesServer
  alias AzarSa.{Transacciones, Jugador, Usuarios, Storage}

  def mount(_params, _session, socket) do
    {:ok, assign(socket, usuario: nil, sorteos_activos: [], balance: nil, historial: nil, notificaciones: [], premios: [], modo: :login, todas_las_compras: [])}
  end

  defp calcular_estado_numero(numero, id_sorteo, sorteo, compras_totales) do
    compras = Enum.filter(compras_totales, &(&1["id_sorteo"] == id_sorteo && &1["numero_billete"] == numero))

    cond do
      Enum.any?(compras, &(&1["tipo"] == "completo")) ->
        "Ocupado (Completo)"
      Enum.empty?(compras) ->
        "Disponible"
      true ->
        ocupadas = Enum.count(compras)
        max = Map.get(sorteo, "num_fracciones", 1)
        if ocupadas < max do
          "Ocupado (Fracciones: #{ocupadas}/#{max})"
        else
          "Ocupado (Sin cupos)"
        end
    end
  end

  defp obtener_color_css(numero, id_sorteo, sorteo, compras_totales) do
    estado = calcular_estado_numero(numero, id_sorteo, sorteo, compras_totales)
    cond do
      estado == "Disponible" -> "bg-green-300"
      String.contains?(estado, "Fracciones") -> "bg-yellow-300"
      true -> "bg-red-300"
    end
  end

  def handle_event("cambiar_modo", %{"modo" => modo}, socket) do
    {:noreply, assign(socket, :modo, String.to_atom(modo))}
  end

  def handle_event("logout", _params, socket) do
    socket =
      socket
      |> put_flash(:info, "Sesión cerrada correctamente.")
      |> assign(usuario: nil, sorteos_activos: [], balance: nil, historial: nil, notificaciones: [], premios: [], modo: :login, todas_las_compras: [])
    {:noreply, socket}
  end

  def handle_event("login", %{"documento" => doc, "password" => pass}, socket) do
    datos_globales = Storage.leer_json("data/usuarios.json")
    lista_u = Map.get(datos_globales, "usuarios", [])
    usuario_existente = Enum.find(lista_u, fn u -> u["documento"] == doc end)

    cond do
      is_nil(usuario_existente) ->
        {:noreply, put_flash(socket, :error, "El documento ingresado no corresponde a ningún usuario.")}
      not Map.has_key?(usuario_existente, "password") ->
        usuario_legacy = Map.put(usuario_existente, "password", pass)
        {:noreply, socket |> assign(:usuario, usuario_legacy) |> cargar_datos_jugador(doc)}
      true ->
        case Usuarios.autenticar(doc, pass) do
          {:ok, u} -> {:noreply, socket |> assign(:usuario, u) |> cargar_datos_jugador(doc)}
          {:error, msg} -> {:noreply, put_flash(socket, :error, msg)}
        end
    end
  end

  def handle_event("registro", %{"documento" => doc, "nombre" => nombre, "password" => pass, "tarjeta" => tarjeta}, socket) do
    case Usuarios.registrar_usuario(doc, nombre, pass, tarjeta) do
      {:ok, u} -> {:noreply, socket |> put_flash(:info, "¡Registro exitoso!") |> assign(:usuario, u) |> cargar_datos_jugador(doc)}
      {:error, msg} -> {:noreply, put_flash(socket, :error, msg)}
    end
  end

  def handle_event("comprar", %{"id_sorteo" => id, "numero" => num, "tipo" => tipo}, socket) do
    doc = socket.assigns.usuario["documento"]
    {numero_int, _} = Integer.parse(num)
    valor = if tipo == "completo", do: 20000, else: 5000

    #Llamamos a SorteoServer pasándole el 'id' primero
    case AzarSa.SorteoServer.comprar(id, doc, numero_int, tipo, valor) do
      {:ok, _} -> {:noreply, socket |> put_flash(:info, "Transacción aprobada.") |> cargar_datos_jugador(doc)}
      {:error, msg} -> {:noreply, put_flash(socket, :error, msg)}
    end
  end

  def handle_event("devolver", %{"sorteo" => id, "numero" => num}, socket) do
    doc = socket.assigns.usuario["documento"]
    {numero_int, _} = Integer.parse(num)

    case Jugador.devolver_compra(doc, id, numero_int) do
      {:ok, msg} -> {:noreply, socket |> put_flash(:info, msg) |> cargar_datos_jugador(doc)}
      {:error, msg} -> {:noreply, put_flash(socket, :error, msg)}
    end
  end

  defp cargar_datos_jugador(socket, documento) do
    sorteos = Transacciones.consultar_sorteos_disponibles()
    {:ok, bal} = Jugador.consultar_balance(documento)
    {:ok, hist} = Jugador.consultar_historial(documento)
    {:ok, notif} = Jugador.ver_notificaciones_y_premios(documento)

    datos_usuarios = Storage.leer_json("data/usuarios.json")
    usuario_fresco = Enum.find(Map.get(datos_usuarios, "usuarios", []), fn u -> u["documento"] == documento end)

    todas_las_compras = Enum.flat_map(Map.get(datos_usuarios, "usuarios", []), &Map.get(&1, "compras", []))

    assign(socket,
      usuario: usuario_fresco,
      sorteos_activos: sorteos,
      balance: bal,
      historial: hist,
      notificaciones: notif.notificaciones,
      premios: notif.premios,
      todas_las_compras: todas_las_compras
    )
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto mt-5 p-6 bg-white text-gray-900 shadow-xl rounded-lg border border-gray-300">
      <%= if is_nil(@usuario) do %>
        <h1 class="text-3xl font-black text-center mb-6 text-gray-900">Portal de Apuestas - Jugadores</h1>
        <div class="max-w-md mx-auto bg-gray-100 p-6 rounded border border-gray-300 shadow-sm">
          <%= if @modo == :login do %>
            <h2 class="text-xl font-bold mb-4 text-center">Identificación</h2>
            <form phx-submit="login" class="space-y-4">
              <input type="text" name="documento" required placeholder="Documento" class="w-full p-2 border border-gray-400 rounded bg-white" />
              <input type="password" name="password" required placeholder="Contraseña" class="w-full p-2 border border-gray-400 rounded bg-white" />
              <button type="submit" class="w-full bg-green-600 text-white p-2 rounded font-bold">Ingresar</button>
            </form>
            <p class="text-center text-sm mt-4">¿Nuevo? <a href="#" phx-click="cambiar_modo" phx-value-modo="registro" class="text-blue-600 font-bold underline">Regístrate</a></p>
          <% else %>
            <h2 class="text-xl font-bold mb-4 text-center">Registro</h2>
            <form phx-submit="registro" class="space-y-3">
              <input type="text" name="nombre" required placeholder="Nombre" class="w-full p-2 border border-gray-400 rounded bg-white" />
              <input type="text" name="documento" required placeholder="Documento" class="w-full p-2 border border-gray-400 rounded bg-white" />
              <input type="text" name="tarjeta" required placeholder="Tarjeta (Simulada)" class="w-full p-2 border border-gray-400 rounded bg-white" />
              <input type="password" name="password" required placeholder="Contraseña" class="w-full p-2 border border-gray-400 rounded bg-white" />
              <button type="submit" class="w-full bg-blue-600 text-white p-2 rounded font-bold">Registrarme</button>
            </form>
            <p class="text-center text-sm mt-4">¿Ya tienes cuenta? <a href="#" phx-click="cambiar_modo" phx-value-modo="login" class="text-blue-600 font-bold underline">Inicia Sesión</a></p>
          <% end %>
        </div>
      <% else %>
        <% info_flash = Phoenix.Flash.get(@flash, :info) %>
        <% error_flash = Phoenix.Flash.get(@flash, :error) %>

        <%= if info_flash do %>
            <div class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-6 font-bold cursor-pointer" phx-click="lv:clear-flash" phx-value-key="info"><%= info_flash %></div>
        <% end %>
        <%= if error_flash do %>
            <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6 font-bold cursor-pointer" phx-click="lv:clear-flash" phx-value-key="error"><%= error_flash %></div>
        <% end %>

        <div class="flex justify-between items-center mb-6 border-b border-gray-300 pb-4">
          <div>
            <h1 class="text-2xl font-black">Usuario: <%= @usuario["nombre"] %></h1>
            <p class="text-xs text-gray-500">Documento: <%= @usuario["documento"] %></p>
            <button phx-click="logout" class="mt-2 bg-red-600 text-white text-xs font-bold px-3 py-1 rounded shadow">Cerrar Sesión</button>
          </div>
          <div class="bg-gray-100 p-3 rounded border border-gray-300 text-sm">
            <div class="flex justify-between gap-8"><span class="text-gray-600">Total Premios:</span><span class="text-green-700 font-bold">$<%= @balance.ganado %></span></div>
            <div class="flex justify-between gap-8 border-b pb-1 mb-1"><span class="text-gray-600">Total Invertido:</span><span class="text-red-700 font-bold">-$<%= @balance.gastado %></span></div>
            <div class="flex justify-between gap-8 text-base"><span class="font-black">Balance Neto:</span><span class={"font-black " <> if(@balance.balance_neto < 0, do: "text-red-600", else: "text-green-600")}>$<%= @balance.balance_neto %></span></div>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="col-span-1">
            <h2 class="text-lg font-bold mb-4 bg-blue-100 p-2 rounded">Comprar Billetes</h2>

            <div class="grid grid-cols-3 gap-1 mb-4 text-[9px] text-center">
              <div class="bg-green-300 p-1 border">Disponible</div>
              <div class="bg-yellow-300 p-1 border">Parcial</div>
              <div class="bg-red-300 p-1 border">Agotado</div>
            </div>

            <%= for sorteo <- @sorteos_activos do %>
              <div class="bg-blue-50 p-4 border border-blue-300 rounded mb-4">
                <h3 class="font-black text-blue-900"><%= sorteo["nombre"] %></h3>
                <p class="text-xs text-blue-700 mb-2">Sorteo ID: <%= sorteo["id"] %></p>
                <form phx-submit="comprar" class="flex flex-col gap-2">
                  <input type="hidden" name="id_sorteo" value={sorteo["id"]} />
                  <div class="flex gap-2">
                    <input type="number" name="numero" required min="1" max={Map.get(sorteo, "total_billetes", 100)} class="p-2 border border-gray-400 rounded w-1/2 bg-white" placeholder="N°" />
                    <select name="tipo" class="p-2 border border-gray-400 rounded w-1/2 bg-white text-sm">
                      <option value="completo">Completo</option>
                      <option value="fraccion">Fracción</option>
                    </select>
                  </div>
                  <button type="submit" data-confirm="¿Confirmar compra?" class="bg-blue-600 hover:bg-blue-700 text-white p-2 rounded font-bold text-sm">Comprar</button>
                </form>

                <div class="mt-3 text-[10px] text-gray-700">
                    <p class="font-bold border-b border-gray-300 mb-1">Verificación rápida:</p>
                    <div class="grid grid-cols-5 gap-1">
                      <%= for n <- 1..Map.get(sorteo, "total_billetes", 100) do %>
                        <div class={"p-1 border text-center text-[8px] " <> obtener_color_css(n, sorteo["id"], sorteo, @todas_las_compras)}>
                          {n}
                        </div>
                      <% end %>
                    </div>
                </div>
              </div>
            <% end %>
          </div>

          <div class="col-span-1">
            <div class="flex justify-between items-center mb-4 bg-gray-200 p-2 rounded">
                <h2 class="text-lg font-bold">Mis Apuestas</h2>
                <span class="text-xs font-bold">Gastado: $<%= Enum.sum(Enum.map(@historial.compras, &(&1["valor_pagado"]))) %></span>
            </div>
            <div class="bg-gray-50 p-4 rounded border border-gray-300 h-96 overflow-y-auto">
              <%= if Enum.empty?(@historial.compras) do %>
                <p class="text-gray-500 text-center mt-10 font-bold">Sin transacciones.</p>
              <% else %>
                <ul class="space-y-3">
                  <%= for compra <- @historial.compras do %>
                    <li class="p-3 border border-gray-300 bg-white rounded shadow-sm">
                      <div class="flex justify-between items-center mb-2">
                        <span class="font-bold"><%= compra["id_sorteo"] %></span>
                        <span class="text-red-600 font-bold">-$<%= compra["valor_pagado"] %></span>
                      </div>
                      <div class="flex justify-between items-center text-xs text-gray-600">
                        <span>N° <%= compra["numero_billete"] %> (<%= compra["tipo"] %>)</span>
                        <%= if Enum.any?(@sorteos_activos, &(&1["id"] == compra["id_sorteo"])) do %>
                          <button phx-click="devolver" phx-value-sorteo={compra["id_sorteo"]} phx-value-numero={compra["numero_billete"]} data-confirm="¿Seguro?" class="text-red-600 underline font-bold hover:text-red-800">Devolver</button>
                        <% end %>
                      </div>
                    </li>
                  <% end %>
                </ul>
              <% end %>
            </div>
          </div>

          <div class="col-span-1">
            <h2 class="text-lg font-bold mb-4 bg-green-100 p-2 rounded">Bandeja & Premios</h2>
            <div class="space-y-4">
              <div class="bg-green-50 p-4 rounded border border-green-300 h-48 overflow-y-auto">
                <h3 class="font-bold text-green-900 border-b border-green-200 pb-1 mb-2">Premios Ganados</h3>
                <%= if Enum.empty?(@premios) do %>
                  <p class="text-gray-500 text-sm">Sin premios aún.</p>
                <% else %>
                  <ul class="space-y-2 text-sm">
                    <%= for p <- @premios do %>
                      <li class="p-2 bg-white rounded border border-green-200"><span class="font-bold"><%= p["nombre_premio"] %></span><br/>Ganancia: $<%= p["valor"] %></li>
                    <% end %>
                  </ul>
                <% end %>
              </div>
              <div class="bg-yellow-50 p-4 rounded border border-yellow-300 h-48 overflow-y-auto">
                <h3 class="font-bold text-yellow-900 border-b border-yellow-200 pb-1 mb-2">Notificaciones</h3>
                <%= if Enum.empty?(@notificaciones) do %>
                  <p class="text-gray-500 text-sm">Sin notificaciones.</p>
                <% else %>
                  <ul class="list-disc pl-4 space-y-1 text-sm text-gray-800">
                    <%= for msg <- Enum.reverse(@notificaciones) do %>
                      <li><%= msg %></li>
                    <% end %>
                  </ul>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
