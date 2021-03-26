defmodule AppDashboard.Utils.DockerRegistryTest do
  use ExUnit.Case, async: true

  alias AppDashboard.Utils.DockerRegistry

  describe "parse_image/3" do
    test "just name" do
      parsed = DockerRegistry.parse_image("image")

      assert parsed == {:ok, {:tag, "registry-1.docker.io", "image", "latest"}}
    end

    test "name and tag" do
      parsed = DockerRegistry.parse_image("image:v1.2.3")

      assert parsed == {:ok, {:tag, "registry-1.docker.io", "image", "v1.2.3"}}
    end

    test "registry, name and tag" do
      parsed = DockerRegistry.parse_image("some-registry.com/path/image:v1.2.3")

      assert parsed == {:ok, {:tag, "some-registry.com", "path/image", "v1.2.3"}}
    end

    test "registry and name" do
      parsed = DockerRegistry.parse_image("some-registry.com/path/image")

      assert parsed == {:ok, {:tag, "some-registry.com", "path/image", "latest"}}
    end

    test "name and digest" do
      parsed = DockerRegistry.parse_image("image@sha256:abc")

      assert parsed == {:ok, {:digest, "registry-1.docker.io", "image", "sha256:abc"}}
    end

    test "registry, name and digest" do
      parsed = DockerRegistry.parse_image("some-registry.com/path/image@sha256:abc")

      assert parsed == {:ok, {:digest, "some-registry.com", "path/image", "sha256:abc"}}
    end

    test "returns errors when empty" do
      parsed = DockerRegistry.parse_image("")

      assert parsed == {:error, "Invalid docker image URL"}
    end
  end

  describe "manifest_url/1" do
    test "generates correct v2 URL" do
      {:ok, parsed} = DockerRegistry.parse_image("some-registry.com/path/image")
      url = DockerRegistry.manifest_url(parsed)

      assert url == "https://some-registry.com/v2/path/image/manifests/latest"
    end
  end

  describe "blob_url/1" do
    test "generates correct v2 URL" do
      {:ok, parsed} = DockerRegistry.parse_image("some-registry.com/path/image")
      url = DockerRegistry.blob_url(parsed, "sha256:abcd")

      assert url == "https://some-registry.com/v2/path/image/blobs/sha256:abcd"
    end
  end

  describe "extract_config_digest/1" do
    test "extracts valid config digest" do
      response = %{
        "config" => %{
          "mediaType" => "application/vnd.docker.container.image.v1+json",
          "size" => 8178,
          "digest" => "sha256:40df6707a8de73756b35ec420f621910f4d3ac9517d642213a82d2efc5fd610a",
        }
      }

      digest = DockerRegistry.extract_config_digest(response)

      assert digest == {:ok, "sha256:40df6707a8de73756b35ec420f621910f4d3ac9517d642213a82d2efc5fd610a"}
    end

    test "returns error when could not be found" do
      response = %{}

      digest = DockerRegistry.extract_config_digest(response)

      assert digest == {:error, "Could not retrieve config digest from manifest"}
    end
  end
end
