defmodule Ex4 do

  defmodule Types do
    defstruct [:atom, :binary, integer: 0, float: 0.0]
    @type t :: %Types{integer: integer(), float: float(), atom: atom(), binary: binary()}
    @type t_in_t :: t
  end

  # $ %Types{:integer => integer(), :float => float(), :atom => atom(), :binary => binary()} -> %Types{:integer => integer(), :float => float(), :atom => atom(), :binary => binary()}
  @spec id_struct(Types.t()) :: Types.t_in_t
  def id_struct(x) when is_struct(x) and x.__struct__ == Types, do: x

  # $ {atom(), term()} -> tuple()
  @spec id_tuple({atom(), term()}) :: tuple()
  def id_tuple(x) when is_tuple(x), do: x

  # $ binary() -> binary()
  @spec id_string(String.t()) :: String.t()
  def id_string(x) when is_binary(x), do: x

  # $ empty_list() or non_empty_list({atom(), term()}, empty_list()) or %__struct_top__{:__struct__ => atom(), atom() => if_set(term())} or open_map() or nil or term() -> empty_list() or non_empty_list({atom(), term()}, empty_list()) or %__struct_top__{:__struct__ => atom(), atom() => if_set(term())} or open_map() or nil or term()
  @spec id_access(Access.t()) :: Access.t()
  def id_access(x), do: x
end
