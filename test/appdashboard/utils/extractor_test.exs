defmodule AppDashboard.Utils.ExtractorTest do
  use ExUnit.Case, async: true

  alias AppDashboard.Utils.Extractor

  test "jsonpath" do
    input = %{"x" => "val", "y" => "val2"}

    test_extraction(
      %{
        "jsonpath" => %{
          "key" => "$"
        }
      },
      input,
      %{"key" => input}
    )
  end

  test "template" do
    input = %{"x" => "val", "y" => "val2"}

    test_extraction(
      %{
        "template" => %{
          "key" => "{{ data.x }}_{{ data.y }}"
        }
      },
      input,
      %{"key" => "val_val2"}
    )
  end

  test "template with context" do
    input = %{"x" => "val", "y" => "val2"}

    test_extraction(
      %{
        "template" => %{
          "key" => "{{ data.x }}_{{ data.y }}_{{ ctx }}"
        }
      },
      input,
      %{"key" => "val_val2_val3"},
      %{"ctx" => "val3"}
    )
  end

  test "template after jsonpath" do
    input = %{"x" => "val", "y" => "val2"}

    test_extraction(
      %{
        "jsonpath" => %{
          "json" => "$.x"
        },
        "template" => %{
          "key" => "{{ extracted.json }}_{{ data.y }}"
        }
      },
      input,
      %{"key" => "val_val2", "json" => "val"}
    )
  end

  defp test_extraction(config, input, expected, context \\ %{}) do
    compiled = Extractor.create_config(config)

    extracted = Extractor.extract(input, compiled, context)

    assert extracted == expected
  end

end
