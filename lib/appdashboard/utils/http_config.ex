defmodule AppDashboard.Utils.HTTPConfig do
  require Logger

  alias AppDashboard.Utils.HTTPConfig

  defstruct headers: %{}, transport_opts: []

  def create_config(http_config) do
    %HTTPConfig{}
    |> populate_auth(http_config)
    |> populate_headers(http_config)
    |> populate_tls(http_config)
  end

  def headers(%HTTPConfig{headers: headers}) do
    Map.to_list(headers)
  end

  def transport_opts(%HTTPConfig{transport_opts: transport_opts}) do
    transport_opts
  end

  defp populate_auth(output, %{"auth_type" => "bearer"} = config) do
    populate_auth_bearer(output, config)
  end

  defp populate_auth(output, %{"auth_type" => "basic"} = config) do
    populate_auth_basic(output, config)
  end

  defp populate_auth(output, _), do: output

  defp populate_auth_bearer(output, %{"bearer_file" => file}) do
    case File.read(file) do
      {:ok, value} ->
        populate_auth_bearer(output, %{"bearer" => value})

      {:error, error} ->
        Logger.warn("Could not read bearer token #{file}: #{inspect(error)}")
        output
    end
  end

  defp populate_auth_bearer(output, %{"bearer" => value}) do
    %HTTPConfig{output | headers: Map.put(output.headers, "authorization", "Bearer " <> value)}
  end

  defp populate_auth_bearer(output, _), do: output

  defp populate_auth_basic(output, %{"basic_user" => user, "basic_pwd_file" => file})
       when is_binary(user) and is_binary(file) do

    case File.read(file) do
      {:ok, value} ->
        populate_auth_basic(output, %{"basic_user" => user, "basic_pwd" => value})

      {:error, error} ->
        Logger.warn("Could not read basic password #{file}: #{inspect(error)}")
        output
    end
  end

  defp populate_auth_basic(output, %{"basic_user" => user, "basic_pwd" => pwd})
       when is_binary(user) and is_binary(pwd) do
    value = Base.encode64(user <> ":" <> pwd)

    %HTTPConfig{output | headers: Map.put(output.headers, "authorization", "Basic " <> value)}
  end

  defp populate_auth_basic(output, _), do: output

  defp populate_headers(output, %{"extra_headers" => headers}) when is_map(headers) do
    %HTTPConfig{output | headers: Map.merge(output.headers, headers)}
  end

  defp populate_headers(output, _), do: output

  defp populate_tls(output, %{"tls_enabled" => true} = http_config) do
    transport_opts =
      [{:depth, 5}]
      |> populate_server_auth(http_config)
      |> populate_client_auth(http_config)

    %HTTPConfig{output | transport_opts: transport_opts}
  end

  defp populate_tls(output, _), do: output

  defp populate_server_auth(opts, %{"tls_insecure" => true}) do
    [{:verify, :verify_none} | opts]
  end

  defp populate_server_auth(opts, %{"tls_cacert_file" => file}) when is_binary(file) do
    [{:verify, :verify_peer} | [{:cacertfile, file} | opts]]
  end

  defp populate_server_auth(opts, _http) do
    [{:verify, :verify_peer} | [{:cacertfile, CAStore.file_path()} | opts]]
  end

  defp populate_client_auth(opts, %{"tls_clientcert_file" => cert, "tls_clientkey_file" => key})
       when is_binary(cert) and is_binary(key) do
    [{:cert_pem, cert} | [{:key_pem, key} | opts]]
  end

  defp populate_client_auth(opts, _http), do: opts

end
