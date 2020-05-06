defmodule AppDashboard.DataPlane.Provider do
  @type data :: map
  @type provider_config :: %AppDashboard.Config.Instance.Provider{}
  @type source_config :: %AppDashboard.Config.Source{} | :none
  @type instance_pid :: pid
  @type provider_pid :: pid
  @type refresh_after :: timeout

  @callback start_provider(provider_config, source_config, instance_pid) ::
              {:ok, provider_pid} | {:error, any}
  @callback update_data(provider_pid, data) :: {:ok, data, refresh_after} | {:error, any}

  @spec refresh_instance(instance_pid) :: :ok
  def refresh_instance(addr) do
    GenServer.cast(addr, :refresh)
  end
end
