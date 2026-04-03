defmodule Ex4 do
  alias Ex4.Types, as: Tp
  # alias Ex2, as: Types

  defmodule Types do
    defstruct [:atom, :binary, integer: 0, float: 0.0]
    @type t :: %Types{integer: integer(), float: float(), atom: atom(), binary: binary()}
    @type t_in_t :: t
  end

  # $ %Types{:integer => integer(), :float => float(), :atom => atom(), :binary => binary()} -> %Types{:integer => integer(), :float => float(), :atom => atom(), :binary => binary()}
  @spec id_struct(Tp.t()) :: Tp.t_in_t
  def id_struct(x) when is_struct(x) and x.__struct__ == Types, do: x

  # @spec id_tuple({atom(), term()}) :: tuple()
  # def id_tuple(x) when is_tuple(x), do: x

  # @spec id_string(String.t()) :: String.t()
  # def id_string(x) when is_binary(x), do: x

  # @spec id_access(Access.t()) :: Access.t()
  # def id_access(x), do: x
end
