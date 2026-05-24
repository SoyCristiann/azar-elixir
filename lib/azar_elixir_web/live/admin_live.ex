defmodule AzarElixirWeb.AdminLive do
  use AzarElixirWeb, :live_view
  alias AzarSa.AdminSorteos

  def mount(_params, _session, socket) do
    {:ok, cargar_datos(socket)}
  end

  defp cargar_datos(socket) do
    sorteos = AdminSorteos.listar_sorteos()
    assign(socket, sorteos: sorteos, detalle_sorteo: nil, finanzas: nil, clientes: nil, editando_id: nil)
  end

  defp cargar_auditoria(socket, id) do
    finanzas =
      case AdminSorteos.balance_sorteo(id) do
        %{balance_neto: _} = bal -> bal
        _ -> nil
      end

    clientes = AdminSorteos.listar_clientes_por_sorteo(id)
    assign(socket, detalle_sorteo: id, finanzas: finanzas, clientes: clientes)
  end

  # ==========================================
  # MANEJADORES DE EVENTOS (CRUD SORTEOS)
  # ==========================================

  def handle_event("actualizar_fecha", %{"fecha" => nueva_fecha}, socket) do
    case AdminSorteos.actualizar_fecha_sistema(nueva_fecha) do
      {:ok, msg} -> {:noreply, socket |> put_flash(:info, msg) |> cargar_datos()}
      {:error, msg} -> {:noreply, put_flash(socket, :error, msg)}
    end
  end

  def handle_event("ver_detalles", %{"id" => id}, socket) do
    {:noreply, cargar_auditoria(socket, id)}
  end

  # NUEVO EVENTO: EJECUTAR SORTEO MANUALMENTE
  def handle_event("ejecutar_manual", %{"id" => id}, socket) do
    case AdminSorteos.ejecutar_sorteo_manual(id) do
      {:ok, msg} ->
        socket =
          socket
          |> put_flash(:info, msg)
          |> cargar_datos()

        # Si el usuario estaba viendo la auditoría de ese mismo sorteo, la refrescamos para mostrar ganadores
        socket = if socket.assigns.detalle_sorteo == id, do: cargar_auditoria(socket, id), else: socket

        {:noreply, socket}
      {:error, msg} ->
        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  def handle_event("crear_sorteo", %{"nombre" => nom, "fecha" => fec, "total_billetes" => tb, "num_fracciones" => nf, "valor_billete" => vb}, socket) do
    {total_b, _} = Integer.parse(tb)
    {num_f, _} = Integer.parse(nf)
    {valor_b, _} = Integer.parse(vb)

    nuevo_sorteo = %{
      "id" => "sorteo_#{:os.system_time(:millisecond)}",
      "nombre" => nom,
      "estado" => "pendiente",
      "fecha" => fec,
      "total_billetes" => total_b,
      "num_fracciones" => num_f,
      "valor_billete" => valor_b,
      "premios" => [],
      "ganadores" => []
    }

    case AdminSorteos.crear_sorteo(nuevo_sorteo) do
      {:ok, msg} -> {:noreply, socket |> put_flash(:info, msg) |> cargar_datos()}
      {:error, msg} -> {:noreply, socket |> put_flash(:error, msg)}
    end
  end

  def handle_event("eliminar_sorteo", %{"id" => id}, socket) do
    case AdminSorteos.eliminar_sorteo(id) do
      {:ok, msg} ->
        socket = if socket.assigns.detalle_sorteo == id, do: assign(socket, detalle_sorteo: nil, finanzas: nil, clientes: nil), else: socket
        {:noreply, socket |> put_flash(:info, msg) |> cargar_datos()}
      {:error, msg} ->
        {:noreply, socket |> put_flash(:error, msg)}
    end
  end

  def handle_event("activar_edicion", %{"id" => id}, socket) do
    {:noreply, assign(socket, editando_id: id)}
  end

  def handle_event("cancelar_edicion", _params, socket) do
    {:noreply, assign(socket, editando_id: nil)}
  end

  def handle_event("guardar_fecha", %{"sorteo_id" => id, "nueva_fecha" => nueva_fecha}, socket) do
    resultado = AdminSorteos.modificar_fecha_sorteo(id, nueva_fecha)
    case resultado do
      {:ok, msg} ->
        {:noreply, socket |> put_flash(:info, msg) |> assign(editando_id: nil) |> cargar_datos()}
      _ ->
        {:noreply, put_flash(socket, :error, "Error al modificar fecha")}
    end
  end

  # ==========================================
  # MANEJADORES DE EVENTOS (CRUD PREMIOS)
  # ==========================================

  def handle_event("agregar_premio", %{"nombre_premio" => nombre, "valor_premio" => valor}, socket) do
    id_sorteo = socket.assigns.detalle_sorteo
    {valor_int, _} = Integer.parse(valor)
    nuevo_premio = %{"nombre" => nombre, "valor" => valor_int}

    AdminSorteos.agregar_premio(id_sorteo, nuevo_premio)

    socket =
      socket
      |> put_flash(:info, "Premio '#{nombre}' agregado correctamente.")
      |> cargar_datos()
      |> cargar_auditoria(id_sorteo)

    {:noreply, socket}
  end

  def handle_event("eliminar_premio", %{"nombre" => nombre_premio}, socket) do
    id_sorteo = socket.assigns.detalle_sorteo

    case AdminSorteos.eliminar_premio(id_sorteo, nombre_premio) do
      {:ok, msg} ->
        socket =
          socket
          |> put_flash(:info, msg)
          |> cargar_datos()
          |> cargar_auditoria(id_sorteo)
        {:noreply, socket}

      {:error, msg} ->
        {:noreply, put_flash(socket, :error, msg)}
    end
  end

  # ==========================================
  # RENDERIZADO DE LA VISTA
  # ==========================================

  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto mt-5 p-6 bg-white text-gray-900 shadow-xl rounded-lg border border-gray-300">
      <h1 class="text-3xl font-black text-gray-900 mb-6 border-b border-gray-300 pb-4">
        Panel de Administración
      </h1>

      <%= if Phoenix.Flash.get(@flash, :info) do %>
        <div class="bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded mb-6 font-bold shadow-sm cursor-pointer" phx-click="lv:clear-flash" phx-value-key="info">
          {Phoenix.Flash.get(@flash, :info)}
        </div>
      <% end %>

      <%= if Phoenix.Flash.get(@flash, :error) do %>
        <div class="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded mb-6 shadow-sm flex items-center cursor-pointer" phx-click="lv:clear-flash" phx-value-key="error">
          <svg class="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path></svg>
          <span class="font-bold">¡Operación Bloqueada!</span>&nbsp; {Phoenix.Flash.get(@flash, :error)}
        </div>
      <% end %>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <div class="bg-gray-100 p-5 rounded-lg border border-gray-300">
          <h2 class="text-xl font-bold text-gray-800 mb-3">Registrar Sorteo</h2>
          <form phx-submit="crear_sorteo" class="grid grid-cols-2 gap-3">
            <div class="col-span-2">
              <input type="text" name="nombre" placeholder="Nombre del Sorteo" required class="w-full p-2 border border-gray-400 rounded bg-white text-sm" />
            </div>
            <div>
              <label class="block text-xs font-bold text-gray-700">Fecha de Juego:</label>
              <input type="date" name="fecha" required class="w-full p-2 border border-gray-400 rounded bg-white text-sm" />
            </div>
            <div>
              <label class="block text-xs font-bold text-gray-700">Valor Billete ($):</label>
              <input type="number" name="valor_billete" min="1000" placeholder="Ej: 50000" required class="w-full p-2 border border-gray-400 rounded bg-white text-sm" />
            </div>
            <div>
              <label class="block text-xs font-bold text-gray-700">Total Billetes:</label>
              <input type="number" name="total_billetes" min="10" placeholder="Ej: 100" required class="w-full p-2 border border-gray-400 rounded bg-white text-sm" />
            </div>
            <div>
              <label class="block text-xs font-bold text-gray-700">Num. Fracciones:</label>
              <input type="number" name="num_fracciones" min="1" max="10" placeholder="Ej: 4" required class="w-full p-2 border border-gray-400 rounded bg-white text-sm" />
            </div>
            <div class="col-span-2 mt-2">
              <button type="submit" class="w-full bg-green-600 hover:bg-green-700 text-white font-bold p-2 rounded shadow">
                Crear Sorteo Oficial
              </button>
            </div>
          </form>
        </div>

        <div class="bg-gray-100 p-5 rounded-lg border border-gray-300 flex flex-col justify-center">
          <h2 class="text-xl font-bold text-gray-800 mb-3">Simulador Temporal del Sistema</h2>
          <form phx-submit="actualizar_fecha" class="flex flex-col gap-4">
            <div>
              <label class="block text-sm font-bold text-gray-700">Avanzar fecha del sistema a:</label>
              <input type="date" name="fecha" required class="w-full p-2 border border-gray-400 rounded bg-white font-medium" />
            </div>
            <button type="submit" data-confirm="¿Ejecutar todos los sorteos pendientes hasta esta fecha de forma masiva?" class="bg-blue-600 hover:bg-blue-700 text-white font-bold px-6 py-2 rounded shadow">
              Ejecutar Sorteos Programados Masivamente
            </button>
          </form>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div class="lg:col-span-2 overflow-x-auto rounded-lg border border-gray-300 shadow-sm">
          <table class="min-w-full bg-white text-left text-sm border-collapse">
            <thead class="bg-gray-800 text-white">
              <tr>
                <th class="py-2 px-3 font-bold">Sorteo</th>
                <th class="py-2 px-3 font-bold text-center">Estado</th>
                <th class="py-2 px-3 font-bold">Ganadores (DNI/Premio/N°)</th>
                <th class="py-2 px-3 font-bold text-center">Acciones</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <%= for sorteo <- @sorteos do %>
                <tr class="hover:bg-gray-50">
                  <td class="py-2 px-3">
                    <span class="font-bold">{sorteo["nombre"]}</span>
                    <br />

                    <%= if @editando_id == sorteo["id"] do %>
                      <form phx-submit="guardar_fecha" class="mt-1 flex items-center gap-1">
                        <input type="hidden" name="sorteo_id" value={sorteo["id"]} />
                        <input type="date" name="nueva_fecha" value={Map.get(sorteo, "fecha")} required class="p-1 border border-gray-400 text-xs rounded bg-white text-gray-900" />
                        <button type="submit" class="bg-green-600 text-white text-[10px] px-2 py-1 rounded font-bold">OK</button>
                        <button type="button" phx-click="cancelar_edicion" class="bg-gray-400 text-white text-[10px] px-2 py-1 rounded font-bold">X</button>
                      </form>
                    <% else %>
                      <span class="text-xs text-gray-500">
                        ID: {sorteo["id"]} | Fecha: {Map.get(sorteo, "fecha", "N/A")}
                        <button phx-click="activar_edicion" phx-value-id={sorteo["id"]} class="text-blue-600 ml-1 underline text-[10px] font-bold">Editar</button>
                      </span>
                    <% end %>
                  </td>
                  <td class="py-2 px-3 text-center">
                    <span class={"px-2 py-1 rounded text-xs font-black text-white " <> if(sorteo["estado"] == "jugado", do: "bg-red-600", else: "bg-green-600")}>
                      {String.upcase(sorteo["estado"] || "pendiente")}
                    </span>
                  </td>
                  <td class="py-2 px-3 text-xs text-gray-700">
                    <%= if sorteo["estado"] == "jugado" do %>
                      <%= for ganador <- Map.get(sorteo, "ganadores", []) do %>
                        <div class="mb-1 p-1 bg-blue-50 border border-blue-100">
                          <span class="font-bold">Doc:</span> {ganador["documento"]}<br />
                          <span class="font-bold text-blue-800">N° Ganador: {ganador["numero"]}</span>
                          <br />
                          <span class="text-[10px] uppercase">{ganador["premio"]}</span>
                        </div>
                      <% end %>
                    <% else %>
                      <span class="italic text-gray-400">Sorteo activo</span>
                    <% end %>
                  </td>
                  <td class="py-2 px-3 text-center flex flex-col gap-1 items-center">
                    <button phx-click="ver_detalles" phx-value-id={sorteo["id"]} class="w-full bg-gray-200 hover:bg-gray-300 text-gray-800 text-xs font-bold py-1 px-2 rounded border border-gray-400">
                      Auditoría
                    </button>

                    <%= if sorteo["estado"] == "pendiente" do %>
                      <button phx-click="ejecutar_manual"
                              phx-value-id={sorteo["id"]}
                              data-confirm={"¿Desea jugar el sorteo '#{sorteo["nombre"]}' INMEDIATAMENTE y notificar a los ganadores?"}
                              class="w-full bg-amber-500 hover:bg-amber-600 text-white text-xs font-bold py-1 px-2 rounded border border-amber-600">
                        Ejecutar Ahora
                      </button>
                    <% end %>

                    <%= if Enum.empty?(Map.get(sorteo, "premios", [])) do %>
                      <button phx-click="eliminar_sorteo"
                              phx-value-id={sorteo["id"]}
                              data-confirm="¿Está totalmente seguro de eliminar este sorteo? Esta acción es irreversible."
                              class="w-full bg-red-100 hover:bg-red-200 text-red-700 text-xs font-bold py-1 px-2 rounded border border-red-300">
                        Eliminar
                      </button>
                    <% else %>
                      <button type="button"
                              onclick="alert('ACCIÓN DENEGADA:\n\nNo es posible eliminar este sorteo porque ya tiene premios asociados en el sistema.\n\nPara eliminarlo, primero debe ir a la gestión de premios y dejar la lista de premios vacía.');"
                              class="w-full bg-red-50 hover:bg-red-100 text-red-500 text-xs font-bold py-1 px-2 rounded border border-red-200 cursor-not-allowed opacity-80">
                        Eliminar
                      </button>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <div class="lg:col-span-1 bg-gray-50 border border-gray-300 p-4 rounded-lg shadow-inner">
          <h2 class="text-lg font-black border-b border-gray-300 pb-2 mb-4">Auditoría de Sorteo</h2>
          <%= if is_nil(@detalle_sorteo) do %>
            <p class="text-sm text-gray-500 text-center mt-10">
              Seleccione un sorteo de la tabla para ver sus detalles, finanzas y premios.
            </p>
          <% else %>
            <% sorteo_actual = Enum.find(@sorteos, fn s -> s["id"] == @detalle_sorteo end) %>
            <h3 class="font-bold text-blue-800 mb-2">ID: {@detalle_sorteo}</h3>

            <div class="bg-white p-2 border border-gray-300 mb-4 text-xs">
              <h4 class="font-bold text-gray-800">Números Ganadores:</h4>
              <ul class="list-disc pl-5">
                <%= for n <- Map.get(sorteo_actual, "numeros_ganadores", []) do %>
                  <li>Premio {n["premio"]}: {n["numero"]}</li>
                <% end %>
              </ul>
            </div>

            <div class="bg-white p-3 rounded border border-gray-300 mb-4 text-sm">
              <h4 class="font-bold text-gray-800 mb-2 border-b pb-1">Plan de Premios</h4>
              <%= if sorteo_actual["estado"] == "jugado" do %>
                <p class="text-xs text-orange-600 font-bold mb-2">Sorteo cerrado. Edición de premios bloqueada.</p>
              <% else %>
                <form phx-submit="agregar_premio" class="flex gap-2 mb-3">
                  <input type="text" name="nombre_premio" placeholder="Ej: Carro 0KM" required class="w-1/2 p-1 border border-gray-400 rounded text-xs" />
                  <input type="number" name="valor_premio" placeholder="Valor $" min="1000" required class="w-1/3 p-1 border border-gray-400 rounded text-xs" />
                  <button type="submit" class="w-1/6 bg-blue-600 text-white rounded text-xs font-bold hover:bg-blue-700">+</button>
                </form>
              <% end %>

              <ul class="space-y-1">
                <%= for premio <- Map.get(sorteo_actual, "premios", []) do %>
                  <li class="flex justify-between items-center bg-gray-50 p-1.5 border rounded text-xs">
                    <span><strong>{premio["nombre"]}</strong>: ${premio["valor"]}</span>
                    <%= if sorteo_actual["estado"] != "jugado" do %>
                      <button phx-click="eliminar_premio" phx-value-nombre={premio["nombre"]} data-confirm={"¿Seguro que desea eliminar el premio '#{premio["nombre"]}'?"} class="text-red-600 hover:text-red-800 font-black px-2">X</button>
                    <% end %>
                  </li>
                <% end %>
                <%= if Enum.empty?(Map.get(sorteo_actual, "premios", [])) do %>
                  <li class="text-xs text-gray-500 italic text-center py-2">No hay premios configurados.</li>
                <% end %>
              </ul>
            </div>

            <div class="bg-white p-3 rounded border border-gray-300 mb-4 text-sm">
              <h4 class="font-bold text-gray-800 mb-2">Finanzas</h4>
              <%= if @finanzas do %>
                <div class="flex justify-between"><span class="text-gray-600">Ingresos:</span><span class="font-bold text-green-700">$<%= @finanzas.ingresos %></span></div>
                <div class="flex justify-between"><span class="text-gray-600">Costos (Premios):</span><span class="font-bold text-red-700">-$<%= @finanzas.costo_premios %></span></div>
                <div class="flex justify-between mt-2 pt-2 border-t font-black">
                  <span>Balance Neto:</span>
                  <span class={if(@finanzas.balance_neto < 0, do: "text-red-600", else: "text-green-600")}>$<%= @finanzas.balance_neto %></span>
                </div>
              <% else %>
                <p class="text-gray-500 italic text-xs">No hay ventas registradas.</p>
              <% end %>
            </div>

            <div class="bg-white p-3 rounded border border-gray-300 text-sm h-48 overflow-y-auto">
              <h4 class="font-bold text-gray-800 mb-2">Clientes Participantes</h4>
              <%= if is_nil(@clientes) or (Enum.empty?(@clientes.completos) and Enum.empty?(@clientes.fracciones)) do %>
                <p class="text-gray-500 italic">No hay ventas registradas.</p>
              <% else %>
                <div class="mb-3">
                  <h5 class="font-bold text-blue-700 bg-blue-50 px-2 rounded">Billetes Completos</h5>
                  <ul class="list-disc pl-5 mt-1 text-gray-700 text-xs">
                    <%= for nombre <- @clientes.completos do %><li>{nombre}</li><% end %>
                  </ul>
                </div>
                <div>
                  <h5 class="font-bold text-purple-700 bg-purple-50 px-2 rounded">Fracciones</h5>
                  <ul class="list-disc pl-5 mt-1 text-gray-700 text-xs">
                    <%= for nombre <- @clientes.fracciones do %><li>{nombre}</li><% end %>
                  </ul>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
