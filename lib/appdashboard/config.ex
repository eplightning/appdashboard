defmodule AppDashboard.Config do

  defstruct environments: %{}, applications: %{}, templates: %{}, sources: %{}, autodiscovery: %{}, instances: %{}

  defmodule Environment do
    defstruct id: "", name: "", variables: %{}
  end

  defmodule Application do
    defstruct id: "", name: "", variables: %{}
  end

  defmodule Template do
    defstruct id: "", template: ""
  end

  defmodule Autodiscovery do
    defstruct id: "", name: "", type: "", source: "", config: %{}
  end

  defmodule Source do
    defstruct id: "", name: "", type: "", config: %{}
  end

  defmodule Instance do
    defstruct environment: "", application: "", template: "", variables: %{}, data: %{}, extractors: %{}, providers: %{}

    defmodule Provider do
      defstruct id: "", name: "", type: "", source: "", config: %{}
    end
  end

end
