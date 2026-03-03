defmodule Migrator.TypespecInfo do
  alias Migrator.TypespecInfo

  defstruct [
    name: "",
    inputs: [""],
    output: "",
    guards: [""]
  ]

  @type t :: %TypespecInfo{
    name: binary(),
    inputs: list(binary()),
    output: binary(),
    guards: list(binary())
  }
end
