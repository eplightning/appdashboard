defmodule AppDashboard.Config do

  defstruct environments: %{}, applications: %{}, templates: %{}, sources: %{}, discovery: %{}, instances: %{}

  defmodule Environment do
    @derive Jason.Encoder
    defstruct id: "", name: "", variables: %{}, order: 0
  end

  defmodule Application do
    @derive Jason.Encoder
    defstruct id: "", name: "", variables: %{}
  end

  defmodule Template do
    defstruct id: "", template: ""
  end

  defmodule Discovery do
    defstruct id: "", name: "", type: "", source: "", config: %{}
  end

  defmodule Source do
    defstruct id: "", name: "", type: "", config: %{}
  end

  defmodule Instance do
    defstruct environment: "", application: "", template: "", variables: %{}, data: %{}, extractors: %{}, providers: %{}

    defmodule Provider do
      defstruct id: "", name: "", type: "", source: "", order: 0, config: %{}
    end
  end

end
