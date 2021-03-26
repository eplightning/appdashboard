defmodule AppDashboard.Utils.DockerRegistry do
  require Logger

  def parse_image(url, default_hostname \\ "registry-1.docker.io", default_tag \\ "latest") do
    parsed = Regex.named_captures(~r/^(?:(?<registry>[^\/]+)\/)?(?<name>[^:@]+)((?::(?<tag>.+))|(?:@(?<digest>.+)))?$/, url)

    case parsed do
      %{} -> {:ok, do_parse(parsed, default_hostname, default_tag)}
      _ -> {:error, "Invalid docker image URL"}
    end
  end

  def extract_config_digest(manifest_response) do
    case get_in(manifest_response, ["config", "digest"]) do
      digest when is_binary(digest) -> {:ok, digest}
      _ -> {:error, "Could not retrieve config digest from manifest"}
    end
  end

  def manifest_url({_, hostname, name, tag}) do
    "https://#{hostname}/v2/#{name}/manifests/#{tag}"
  end

  def blob_url({_, hostname, name, _}, blob) do
    "https://#{hostname}/v2/#{name}/blobs/#{blob}"
  end

  defp do_parse(%{"name" => name} = map, default_hostname, default_tag) do
    hostname = case map do
      %{"registry" => registry} when registry != "" -> registry
      _ -> default_hostname
    end

    case map do
      %{"tag" => tag} when tag != "" -> {:tag, hostname, name, tag}
      %{"digest" => digest} when digest != "" -> {:digest, hostname, name, digest}
      _ -> {:tag, hostname, name, default_tag}
    end
  end
end
