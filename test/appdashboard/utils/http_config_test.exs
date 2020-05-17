defmodule AppDashboard.Utils.HTTPConfigTest do
  use ExUnit.Case, async: true

  alias AppDashboard.Utils.HTTPConfig

  describe "headers/1" do
    test "default auth" do
      config = HTTPConfig.create_config(%{})

      refute List.keymember?(HTTPConfig.headers(config), "authorization", 0)
    end

    test "none auth" do
      config = HTTPConfig.create_config(%{
        "auth_type" => "none"
      })

      refute List.keymember?(HTTPConfig.headers(config), "authorization", 0)
    end

    test "basic auth" do
      config = HTTPConfig.create_config(%{
        "auth_type" => "basic",
        "basic_user" => "user",
        "basic_pwd" => "pwd"
      })

      expected_value = "Basic " <> Base.encode64("user:pwd")

      assert List.keyfind(HTTPConfig.headers(config), "authorization", 0) == {"authorization", expected_value}
    end

    test "bearer auth" do
      config = HTTPConfig.create_config(%{
        "auth_type" => "bearer",
        "bearer" => "jwt"
      })

      expected_value = "Bearer jwt"

      assert List.keyfind(HTTPConfig.headers(config), "authorization", 0) == {"authorization", expected_value}
    end

    test "additional headers" do
      config = HTTPConfig.create_config(%{
        "extra_headers" => %{"x-test" => "value"}
      })

      assert List.keyfind(HTTPConfig.headers(config), "x-test", 0) == {"x-test", "value"}
    end

    test "additional headers replace auth" do
      config = HTTPConfig.create_config(%{
        "auth_type" => "bearer",
        "bearer" => "jwt",
        "extra_headers" => %{"authorization" => "AWS4-HMAC-SHA256 test"}
      })

      assert List.keyfind(HTTPConfig.headers(config), "authorization", 0) == {"authorization", "AWS4-HMAC-SHA256 test"}
    end
  end

  describe "transport_opts/1" do
    test "no tls" do
      config = HTTPConfig.create_config(%{
        "tls_enabled" => false
      })

      assert length(HTTPConfig.transport_opts(config)) == 0
    end

    test "insecure tls" do
      config = HTTPConfig.create_config(%{
        "tls_enabled" => true,
        "tls_insecure" => true
      })

      opts = HTTPConfig.transport_opts(config)

      assert Keyword.fetch!(opts, :verify) == :verify_none
    end

    test "default tls" do
      config = HTTPConfig.create_config(%{
        "tls_enabled" => true
      })

      opts = HTTPConfig.transport_opts(config)

      assert Keyword.fetch!(opts, :verify) == :verify_peer
      assert Keyword.has_key?(opts, :cacertfile)
      assert Keyword.has_key?(opts, :depth)
    end

    test "custom ca tls" do
      config = HTTPConfig.create_config(%{
        "tls_enabled" => true,
        "tls_cacert_file" => "/etc/custom-ca.pem"
      })

      opts = HTTPConfig.transport_opts(config)

      assert Keyword.fetch!(opts, :verify) == :verify_peer
      assert Keyword.fetch!(opts, :cacertfile) == "/etc/custom-ca.pem"
      assert Keyword.has_key?(opts, :depth)
    end

    test "client auth tls" do
      config = HTTPConfig.create_config(%{
        "tls_enabled" => true,
        "tls_clientcert_file" => "/etc/client-cert.pem",
        "tls_clientkey_file" => "/etc/client-key.pem"
      })

      opts = HTTPConfig.transport_opts(config)

      assert Keyword.fetch!(opts, :cert_pem) == "/etc/client-cert.pem"
      assert Keyword.fetch!(opts, :key_pem) == "/etc/client-key.pem"
    end
  end

end
