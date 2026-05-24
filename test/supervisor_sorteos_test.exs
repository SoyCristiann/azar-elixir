defmodule AzarSa.SupervisorSorteosTest do
  use ExUnit.Case, async: false
  alias AzarSa.SupervisorSorteos
  #alias AzarSa.ServidorSorteo

  test "El supervisor reinicia automáticamente un servidor si este muere" do
    #Se inicia el supervisor
    {:ok, sup_pid} = SupervisorSorteos.start_link()

    #Se obtiene el PID del servidor del sorteo_001
    pid_original = GenServer.whereis({:global, "Sorteo-sorteo_001"})
    assert is_pid(pid_original)

    #Se mata al servidor hijo
    Process.exit(pid_original, :kill)

    #Espera explicita para que el supervisor actúe
    Process.sleep(300)

    #Verificar que ahora exista un nuevo proceso con el mismo nombre
    pid_nuevo = GenServer.whereis({:global, "Sorteo-sorteo_001"})

    assert is_pid(pid_nuevo)
    assert pid_nuevo != pid_original # ¡Es un proceso nuevo!

    #Limpieza al final: Se mata al supervisor
    Process.exit(sup_pid, :kill)
  end
end
