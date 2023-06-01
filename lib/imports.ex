defmodule YamlToJsonnet.Imports do
  require Logger

  def imports("ServiceAccount"),
    do:
      """
      serviceAccount = k.core.v1.serviceAccount
      """
      |> String.trim()

  def imports("RoleBinding"),
    do:
      """
      roleBinding = k.rbac.v1.roleBinding,
      subject = k.rbac.v1.subject
      """
      |> String.trim()

  def imports(kind) do
    Logger.error("Imports for kind #{kind} are not defined")
    ""
  end
end
