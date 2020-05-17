defmodule AppDashboard.ConfigPlane.DiffTest do

  use ExUnit.Case, async: true

  alias AppDashboard.ConfigPlane.Diff
  alias AppDashboard.Config

  describe "calculate_config_diff/2" do
    test "detects instance changes" do
      old = %Config{
        instances: %{
          {"env_old", "app_old"} => %Config.Instance{
            environment: "env_old",
            application: "app_old",
            template: "template_old"
          },
          {"env_common", "app_common"} => %Config.Instance{
            environment: "env_common",
            application: "app_common",
            template: "template_old"
          },
          {"env_common", "app_common2"} => %Config.Instance{
            environment: "env_common",
            application: "app_common2",
            template: "template_old",
            providers: %{
              "provider" => %Config.Instance.Provider{
                id: "provider",
                source: "source"
              }
            }
          }
        }
      }

      new = %Config{
        instances: %{
          {"env_common", "app_common"} => %Config.Instance{
            environment: "env_common",
            application: "app_common",
            template: "template_new"
          },
          {"env_new", "app_new"} => %Config.Instance{
            environment: "env_new",
            application: "app_new",
            template: "template_new"
          },
          {"env_common", "app_common2"} => %Config.Instance{
            environment: "env_common",
            application: "app_common2",
            template: "template_old",
            providers: %{
              "provider" => %Config.Instance.Provider{
                id: "provider",
                source: "source"
              }
            }
          }
        }
      }

      diff = Diff.calculate_config_diff(old, new)

      assert length(diff) == 4
      assert :config_changed in diff
      assert {:instance_added, {"env_new", "app_new"}} in diff
      assert {:instance_removed, {"env_old", "app_old"}} in diff
      assert {:instance_changed, {"env_common", "app_common"}} in diff
    end

    test "detects source changes" do
      old = %Config{
        instances: %{
          {"env_common", "app_common2"} => %Config.Instance{
            environment: "env_common",
            application: "app_common2",
            template: "template_old",
            providers: %{
              "provider" => %Config.Instance.Provider{
                id: "provider",
                source: "source"
              }
            }
          }
        },
        sources: %{
          "source" => %Config.Source{
            id: "source",
            name: "Source name",
            config: %{
              "var" => "a"
            }
          }
        }
      }

      new = %Config{
        instances: %{
          {"env_common", "app_common2"} => %Config.Instance{
            environment: "env_common",
            application: "app_common2",
            template: "template_old",
            providers: %{
              "provider" => %Config.Instance.Provider{
                id: "provider",
                source: "source"
              }
            }
          }
        },
        sources: %{
          "source" => %Config.Source{
            id: "source",
            name: "Source name",
            config: %{
              "var" => "b"
            }
          }
        }
      }

      diff = Diff.calculate_config_diff(old, new)

      assert length(diff) == 2
      assert :config_changed in diff
      assert {:instance_changed, {"env_common", "app_common2"}} in diff
    end
  end

  describe "calculate_discovery_diff/2" do
    test "detects discovery changes" do
      old = %{
        "old" => %Config.Subset.Discovery{
          discovery: %Config.Discovery{
            id: "old",
            name: "Old discovery"
          }
        },
        "common" => %Config.Subset.Discovery{
          discovery: %Config.Discovery{
            id: "common",
            name: "Common discovery",
            config: %{"var" => "old"}
          }
        },
        "common2" => %Config.Subset.Discovery{
          discovery: %Config.Discovery{
            id: "common2",
            name: "Common discovery 2",
            source: "source"
          },
          source: %Config.Source{
            id: "source",
            config: %{"var" => "old"}
          }
        }
      }

      new = %{
        "new" => %Config.Subset.Discovery{
          discovery: %Config.Discovery{
            id: "new",
            name: "New discovery"
          }
        },
        "common" => %Config.Subset.Discovery{
          discovery: %Config.Discovery{
            id: "common",
            name: "Common discovery",
            config: %{"var" => "new"}
          }
        },
        "common2" => %Config.Subset.Discovery{
          discovery: %Config.Discovery{
            id: "common2",
            name: "Common discovery 2",
            source: "source"
          },
          source: %Config.Source{
            id: "source",
            config: %{"var" => "new"}
          }
        }
      }

      diff = Diff.calculate_discovery_diff(old, new)

      assert length(diff) == 4
      assert {:discovery_removed, "old"} in diff
      assert {:discovery_added, "new"} in diff
      assert {:discovery_changed, "common"} in diff
      assert {:discovery_changed, "common2"} in diff
    end
  end
end
