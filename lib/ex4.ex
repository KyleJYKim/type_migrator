defmodule Ex4 do
  alias Ex4.Types, as: Tp
  # alias Ex2, as: Types

  defmodule Types do
    defstruct [:atom, :binary, integer: 0, float: 0.0]
    @type t :: %Types{integer: integer(), float: float(), atom: atom(), binary: binary()}
    @type t_in_t :: t
  end

  @spec id_struct(Tp.t()) :: Tp.t_in_t()
  def id_struct(x) when is_struct(x) and x.__struct__ == :Types, do: x

  @spec add(integer() | binary()) :: integer()
  # @assert_type_form ((integer() or binary()) -> integer())
  def add(x) do
    x + 1
  end

  @spec get_age(list(%{atom() => binary()})) :: integer()
  # @assert_type_form (list(%{:age => binary()}) and not empty_list() -> integer())
  def get_age(person) do
    hd(person).age + 1
  end

  @spec apply_fun((integer() -> integer()), any()) :: integer()
  # @assert_type_form ((integer() -> integer()), term() -> integer())
  def apply_fun(f, x) do
    f.(x)
  end

  @spec id_tuple({atom(), term()}) :: tuple()
  def id_tuple(x) when is_tuple(x), do: x

  @spec id_string(String.t()) :: String.t()
  def id_string(x) when is_binary(x), do: x

  @spec id_access(Access.t()) :: Access.t()
  def id_access(x), do: x

  @spec id_keyword(keyword()) :: keyword((keyword() -> boolean))
  def id_keyword(k), do: k

  @spec id_stringt(String.t()) :: String.t()
  def id_stringt(t), do: t
end
