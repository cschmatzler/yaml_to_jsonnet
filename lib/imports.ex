defmodule YamlToJsonnet.Imports do
  require Logger

  @imports %{
    "affinity" => "k.core.v1.affinity",
    "configMap" => "k.core.v1.configMap",
    "container" => "k.core.v1.container",
    "containerPort" => "k.core.v1.containerPort",
    "daemonSet" => "k.apps.v1.daemonSet",
    "deployment" => "k.apps.v1.deployment",
    "envVar" => "k.core.v1.envVar",
    "nodeSelectorTerm" => "k.core.v1.nodeSelectorTerm",
    "roleBinding" => "k.rbac.v1.roleBinding",
    "secretReference" => "k.core.v1.secretReference",
    "serviceAccount" => "k.core.v1.serviceAccount",
    "storageClass" => "k.storage.v1.storageClass",
    "subject" => "k.rbac.v1.subject",
    "toleration" => "k.core.v1.toleration",
    "volume" => "k.core.v1.volume",
    "volumeMount" => "k.core.v1.volumeMount",
  }

  def imports(imports) when is_list(imports) do
    imports
    |> Enum.map(fn import -> "#{import} = #{Map.get(@imports, import)}" end)
    |> Enum.join(",\n")
  end
end
