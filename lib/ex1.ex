defmodule Ex1 do
  @spec weak_identity(integer()) :: integer()
  def weak_identity(x), do: x

  @spec strong_identity(integer()) :: integer()
  def strong_identity(x) when is_integer(x), do: x

  @spec inc({<<_::_*8>>, %{required(:one) => integer(), binary() => integer()}}) :: integer()
  def inc({:a, tail}), do: (tail |> Map.get(:one)) + 1

  @spec id({any()}) :: {any()}
  def id(ts), do: ts

  defmodule In do
    @spec inc() :: integer()
    def inc(), do: Ex1.inc({:"#{<<97::1*8>>}", %{:one => 1, "two" => 2, 3 => 3, 4 => 4}})

    @spec id([a: integer()]) :: {b} when a: b, b: a
    def id(ts), do: Ex1.id(ts)
  end

  defmodule Some do
    defstruct [:name, :age]
  end
end
