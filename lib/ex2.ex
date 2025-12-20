defmodule Ex2 do

  @spec id1(integer()) :: integer()
  @spec id1(float()) :: float()
  def id1(x), do: x

  @spec id2(atom()) :: v when v: atom()
  def id2(x), do: x

  defmodule In do

    @spec id1(<<_::8, _::_*8>>) :: <<_::_*8>>
    def id1(x) when is_binary(x), do: x

    @spec fun_t(a) :: b when a: integer(), b: binary()
    @spec fun_t(a) :: b when a: float(), b: binary()
    def fun_t(x) when is_integer(x), do: Integer.to_string(x)
    def fun_t(x) when is_float(x), do: Float.to_string(x)
  end
end
