defmodule Ex1 do
  alias String, as: Str

  @type t_atom :: atom()
  @type t_atom(a) :: {a :: :a, a}

  # TypeSpec multi-clause exhaustiveness: compile warning, dialyzer error
  # @spec id_exhaustive(integer) :: integer()
  # @spec id_exhaustive(float) :: float()
  # @spec id_exhaustive(binary) :: binary()
  # def id_exhaustive(x) when is_integer(x), do: x + 1
  # def id_exhaustive(x) when is_float(x), do: x + 1
  # def id_exhaustive(x) when is_binary(x), do: x

  # TypeSpec multi-clause redundancy check: compile warning, dialyzer pass
  @spec id_redundancy(integer | float) :: float()
  # @spec id_redundancy(float) :: float()
  def id_redundancy(x) when is_integer(x) or is_float(x), do: x + 1.0
  # def id_redundancy(x) when is_float(x), do: x + 1.0

  # Optional: order matters, following functions show different results
  # left-most overwrites the following fields if it's a supertype
  @spec id_records1(%{optional(atom()) => atom(), optional(:a) => integer()}) :: map()
  def id_records1(x), do: x
  # left-most adds up to the following fields if it's a subtype
  @spec id_records2(%{optional(:a) => integer(), optional(atom()) => atom()}) :: map()
  def id_records2(x), do: x

  # absent optional to be required
  @spec id_records3(%{optional(:a) => integer(), optional(:b) => integer()}) :: map()
  def id_records3(x), do: x

  # left-most is ALWAYS predominant to the following fields
  @spec id_records4(%{required(:a) => binary(), required(atom()) => integer()}) :: map()
  def id_records4(x), do: x
  @spec id_records5(%{required(atom()) => integer(), optional(atom()) => binary()}) :: map()
  def id_records5(x), do: x
  @spec id_records6(%{optional(atom()) => binary(), required(:a) => integer()}) :: map()
  def id_records6(x), do: x
  @spec id_records7(%{optional(:a) => binary(), optional(atom()) => integer()}) :: map()
  def id_records7(x), do: x

  @spec id_records8(%{required(:a | :b) => integer(), optional(atom()) => binary()}) :: map()
  # @spec id_records8(%{optional(atom()) => integer(), required(:a) => binary()}) :: map()
  def id_records8(x), do: x

  # @spec id_records9(%{optional((...->atom())) => integer()}) :: map()
  # def id_records9(x), do: x

  @spec id_records10(%{none() => integer()}) :: integer()
  def id_records10(x) when is_map_key(x, {:a}), do: Map.get(x, {:a})

  @spec id_records11(%{required(:a | :b) => float(), integer() => integer()}) :: map()
  def id_records11(x) when is_map(x), do: x

  @spec id_records12(%{(1..3) => integer(), (4..5) => float(), integer() => binary()}) :: map()
  def id_records12(x) when is_map(x), do: x

  @spec id_records13(%{
          nonempty_list(binary()) => binary(),
          nonempty_maybe_improper_list(binary(), []) => integer()
        }) :: map()
  def id_records13(x) when is_map(x), do: x

  @spec id_records14(%{required(:a | integer()) => integer()}) :: map()
  def id_records14(x), do: x

  @spec id_records15(%{required(:a | :b) => integer(), :c => float()}) :: map()
  def id_records15(x), do: x

  @spec id_records16(%{list(integer()) => integer()}) :: map()
  def id_records16(x), do: x

  # @spec id_records20(%{required(:b) => integer()}) :: map()
  @spec id_records20(%{optional(:b) => integer(), :b => binary()}) :: map()
  def id_records20(x), do: x
  # @spec id_records21(%{optional(atom()) => integer()}) :: map()
  @spec id_records21(%{optional(atom()) => integer(), required(:b) => binary()}) :: map()
  def id_records21(x), do: x
  @spec id_records22(%{optional(atom()) => integer(), optional(:b) => binary()}) :: map()
  def id_records22(x), do: x
  @spec id_records23(%{optional(:b) => integer(), required(:b) => binary()}) :: map()
  def id_records23(x), do: x
  @spec id_records24(%{optional(:b) => integer(), optional(atom()) => binary()}) :: map()
  def id_records24(x), do: x
  @spec id_records25(%{optional(:a | :b) => integer(), optional(atom()) => binary()}) :: map()
  def id_records25(x), do: x
  @spec id_records26(%{required(:a | :b) => integer(), optional(atom()) => binary()}) :: map()
  def id_records26(x), do: x

  @spec id_records30(%{optional(1) => integer(), 1 => binary()}) :: map()
  def id_records30(x), do: x
  @spec id_records31(%{optional(integer()) => integer(), required(1) => binary()}) :: map()
  def id_records31(x), do: x
  @spec id_records32(%{optional(integer()) => integer(), optional(1) => binary()}) :: map()
  def id_records32(x), do: x
  @spec id_records33(%{optional(1) => integer(), required(1) => binary()}) :: map()
  def id_records33(x), do: x
  @spec id_records34(%{optional(1) => integer(), optional(integer()) => binary()}) :: map()
  def id_records34(x), do: x
  @spec id_records35(%{optional(1 | 2) => integer(), optional(integer()) => binary()}) :: map()
  def id_records35(x), do: x
  @spec id_records36(%{required(1 | 2) => integer(), optional(integer()) => binary()}) :: map()
  def id_records36(x), do: x

  @spec id_records40(%{optional(1..2) => integer(), <<_::8>> => binary()}) :: map()
  def id_records40(x), do: x

  @spec id_records41(%{optional(any()) => any()}) :: map()
  def id_records41(x), do: x

  @spec id_records42(%{optional(atom()) => any(), :a => integer()}) :: map()
  def id_records42(x) when is_map(x), do: x

  # Whatever function return type is, it is taken as ...->any()
  # @spec id_fun((...->atom())) :: fun()
  # def id_fun(x), do: x

  @spec id_fun2(int :: integer()) :: (integer() -> integer())
  def id_fun2(f), do: f

  @spec id_bin(<<_::15>>) :: binary()
  def id_bin(<<a::8, b::7>>), do: <<a, b>>

  @spec id_tuple({atom(), 1..10, binary()}) :: t when t: tuple()
  @spec id_tuple({%Ex1.Some{a: integer()}, binary()}) :: t when t: tuple()
  def id_tuple(tpl) when is_tuple(tpl), do: tpl

  @spec id_list(list(integer())) :: list(integer())
  def id_list(lst) when is_list(lst), do: lst

  @spec id_type1(Ex2.value()) :: Ex2.Types.t()
  def id_type1(x), do: x

  @spec id_type2(Ex2.access_fun(map, current_value :: term)) ::
          Ex2.access_fun(data2 :: map, current_value :: term)
  def id_type2(x), do: x

  # the name of type parameter has no effect whatsoever; only the name of type variable and its arity matter
  @spec id_type3(t_atom(a :: :b)) :: t_atom(a :: :b)
  def id_type3(x), do: x

  @spec id_type4(Str.t()) :: Str.t()
  def id_type4(x), do: x

  @spec id_type5({atom(), atom()}) :: {atom(), atom()}
  def id_type5(x), do: x

  defmodule In do
    # @spec id_exhaustive() :: any()
    # def id_exhaustive(), do: Ex1.id_exhaustive(:a)

    # @spec id_redundancy() :: any()
    # def id_redundancy(), do: Ex1.id_redundancy()

    # @spec id_records() :: %{required(:atom) => integer(), optional(atom()) => any()}
    # def id_records1(), do: Ex1.id_records1(%{:a => 1, :b => :r})
    # def id_records2(), do: Ex1.id_records2(%{:a => 1, :b => :r})

    # def id_records3(), do: Ex1.id_records3(%{:a => 1, :c => :r})
    # def id_records3(), do: Ex1.id_records3(%{:a => 1, :b => 1, :c => :r})

    # def id_records4(), do: Ex1.id_records4(%{:a => "s"})
    # def id_records5(), do: Ex1.id_records5(%{:c => 8, :b => "d"})
    def id_records6(), do: Ex1.id_records6(%{:c => "d", :a => "1"})
    # def id_records7(), do: Ex1.id_records7(%{:a => 1})

    def id_records8(), do: Ex1.id_records8(%{:c => "a"})
    # def id_records9(), do: Ex1.id_records9(%{fn x -> "a" end => :a})
    # def id_records10(), do: Ex1.id_records10(%{nil => 1})
    # def id_records11(), do: Ex1.id_records11(%{2 => 1, 6 => 1.0, 5 => "s"})
    def id_records12(), do: Ex1.id_records12(%{2 => 2, 4 => 3.8})
    def id_records13(), do: Ex1.id_records13(%{["a"] => "a"})
    def id_records14(), do: Ex1.id_records14(%{})
    def id_records15(), do: Ex1.id_records15(%{:c => 1.1})
    def id_records16(), do: Ex1.id_records16(%{[1] => 1})

    def id_records20(), do: Ex1.id_records20(%{:b => 1})
    def id_records21(), do: Ex1.id_records21(%{})
    def id_records22(), do: Ex1.id_records22(%{})
    def id_records23(), do: Ex1.id_records23(%{:b => 1})
    def id_records24(), do: Ex1.id_records24(%{:b => 1})
    def id_records25(), do: Ex1.id_records25(%{:a => 1, :b => 2, :c => "3"})
    def id_records26(), do: Ex1.id_records26(%{:a => 1, :b => 2, :c => "3"})

    def id_records30(), do: Ex1.id_records30(%{1 => 1})
    def id_records31(), do: Ex1.id_records31(%{})
    def id_records32(), do: Ex1.id_records32(%{})
    def id_records33(), do: Ex1.id_records33(%{1 => 1})
    def id_records34(), do: Ex1.id_records34(%{1 => 1})
    def id_records35(), do: Ex1.id_records35(%{1 => 1, 2 => 2, 3 => "3"})
    def id_records36(), do: Ex1.id_records36(%{1 => 1, 2 => 2, 3 => "3"})

    def id_records41(), do: Ex1.id_records41(%{:a => :a})

    def id_records42(), do: Ex1.id_records42(%{:a => :a})

    # def id_fun(), do: Ex1.id_fun(fn x -> <<97>> end)

    @spec fun(1) :: 2
    def fun(x) when x == 1, do: x + 1
    @spec id_bin() :: <<_::16>>
    def id_bin(), do: Ex1.id_bin(<<97::size(8), 98::size(7)>>)

    def id_tuple(), do: Ex1.id_tuple({:a, 1, "q"})

    def id_list(), do: Ex1.id_list([1])

    def id_type2(), do: Ex1.id_type2(fn :get, x, f -> x |> f.() end)

    def id_type3(), do: Ex1.id_type3({:a, :b})

    def id_type4(), do: Ex1.id_type4("string")

    # def id_type5(), do: Ex1.id_type5({1, 2})
  end

  # @spec weak_identity(integer()) :: integer()
  # def weak_identity(x), do: x

  # @spec strong_identity(integer()) :: integer()
  # def strong_identity(x) when is_integer(x), do: x

  # @spec inc({<<_::_*8>>, %{required(:one) => integer(), binary() => integer()}}) :: integer()
  # def inc({:a, tail}), do: (tail |> Map.get(:one)) + 1

  defmodule Some do
    defstruct [:a, :b]

    @type t :: %Some{
            a: integer(),
            b: Ex2.t()
          }
  end
end
