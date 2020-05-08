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
    %HTTPConfig{output | headers: Map.put(output.headers, "Authorization", "Bearer " <> value)}
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

    %HTTPConfig{output | headers: Map.put(output.headers, "Authorization", "Basic " <> value)}
  end

  defp populate_auth_basic(output, _), do: output

  defp populate_headers(output, %{"extra_headers" => headers}) when is_map(headers) do
    %HTTPConfig{output | headers: Map.merge(output.headers, headers)}
  end

  defp populate_headers(output, _), do: output

  defp populate_tls(output, http_config) do
    %HTTPConfig{output | transport_opts: do_populate_tls([], http_config)}
  end

  defp do_populate_tls(opts, %{"tls_insecure" => true} = http_config) do
    do_populate_tls([{:verify, :verify_none} | opts], Map.drop(http_config, ["tls_insecure"]))
  end

  defp do_populate_tls(opts, %{"tls_cacert_file" => file} = http_config) when is_binary(file) do
    do_populate_tls([{:cacertfile, file} | opts], Map.drop(http_config, ["tls_cacert_file"]))
  end

  defp do_populate_tls(opts, %{"tls_clientcert_file" => file} = http_config)
       when is_binary(file) do
    do_populate_tls([{:cert_pem, file} | opts], Map.drop(http_config, ["tls_clientcert_file"]))
  end

  defp do_populate_tls(opts, %{"tls_clientkey_file" => file} = http_config)
       when is_binary(file) do
    do_populate_tls([{:key_pem, file} | opts], Map.drop(http_config, ["tls_clientkey_file"]))
  end

  defp do_populate_tls(opts, _), do: opts
end
