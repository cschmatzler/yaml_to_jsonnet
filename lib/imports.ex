defmodule YamlToJsonnet.Imports do
  require Logger

  @imports %{
    "configMap" => "k.core.v1.configMap",
    "container" => "k.core.v1.container",
    "containerPort" => "k.core.v1.containerPort",
    "envVar" => "k.core.v1.envVar",
    "secretReference" => "k.core.v1.secretReference",
    "serviceAccount" => "k.core.v1.serviceAccount",
    "volume" => "k.core.v1.volume",
    "volumeMount" => "k.core.v1.volumeMount",
    "deployment" => "k.apps.v1.deployment",
    "roleBinding" => "k.rbac.v1.roleBinding",
    "subject" => "k.rbac.v1.subject"
  }

  def imports(imports) when is_list(imports) do
    imports
    |> Enum.map(fn import -> "#{import} = #{Map.get(@imports, import)}" end)
    |> Enum.join(",\n")
  end
end
