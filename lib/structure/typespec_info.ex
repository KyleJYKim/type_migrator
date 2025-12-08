defmodule Structure.TypespecInfo do
  alias Structure.TypespecInfo

  defstruct [
    name: "",
    input: [],
    output: ""

  ]

  @type t :: %TypespecInfo{
    name: binary(),
    input: list(binary()),
    output: binary()
  }
end
