defmodule Ex1 do
  # TypeSpec multi-clause exhaustiveness: compile warning, dialyzer error
  # @spec id_exhaustive(integer) :: integer()
  # @spec id_exhaustive(float) :: float()
  # @spec id_exhaustive(binary) :: binary()
  # def id_exhaustive(x) when is_integer(x), do: x + 1
  # def id_exhaustive(x) when is_float(x), do: x + 1
  # def id_exhaustive(x) when is_binary(x), do: x


  # TypeSpec multi-clause redundancy check: compile warning, dialyzer pass
  @spec id_redundancy(integer | float) :: float()
  @spec id_redundancy(float) :: float()
  @spec id_redundancy(float) :: float()
  def id_redundancy(x) when is_integer(x) or is_float(x), do: x + 1.0
  def id_redundancy(x) when is_float(x), do: x + 1
  def id_redundancy(x) when is_float(x), do: x + 1.0


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

  # left-most is ALWAYS predominant to the following fields with subtype keys and thus the value types are ignored!
  @spec id_records4(%{required(:a) => binary(), required(atom()) => integer()}) :: map()
  def id_records4(x), do: x
  @spec id_records5(%{required(atom()) => integer(), optional(atom()) => binary()}) :: map()
  def id_records5(x), do: x
  @spec id_records6(%{optional(atom()) => binary(), required(atom()) => integer()}) :: map()
  def id_records6(x), do: x
  @spec id_records7(%{optional(:a) => binary(), optional(atom()) => integer()}) :: map()
  def id_records7(x), do: x

  #@spec id_records8(%{required(:a) => binary(), optional(atom()) => integer()}) :: map()
  @spec id_records8(%{required(atom()) => integer(), required(:a) => binary()}) :: map()
  def id_records8(x), do: x

  # @spec id_records9(%{optional((...->atom())) => integer()}) :: map()
  # def id_records9(x), do: x

  @spec id_records10(%{none() => integer()}) :: integer()
  def id_records10(x) when is_map_key(x, {:a}), do: Map.get(x, {:a})

  # Whatever function return type is, it is taken as ...->any()
  # @spec id_fun((...->atom())) :: fun()
  # def id_fun(x), do: x

  @spec id_bin(bitstring())::binary()
  def id_bin(b), do: b

  @spec id_tuple({%Ex1.Some{a: integer()}, binary()}) :: t when t: tuple()
  def id_tuple(tpl) when is_tuple(tpl), do: tpl

  defmodule In do
    # @spec id_exhaustive() :: any()
    # def id_exhaustive(), do: Ex1.id_exhaustive(:a)
    """
      # Compiler warning:
      code block contains unused literal
      "
      The function call will not succeed.
      Ex1.id_exhaustive(:a) will never return since the success typing is:
        (binary() | number()) :: binary() | number()
      and the contract is
      Contract head:
        (integer()) :: integer()
      Contract head:
        (float()) :: float()
      Contract head:
        (binary()) :: binary()
      "
      (remove the literal or assign it to _ to avoid warnings)

      # Dialyzer error:
      The function call will not succeed.

      Ex1.id_exhaustive(:a)

      will never return since the success typing is:
      (binary() | number()) :: binary() | number()

      and the contract is
      Contract head:
      (integer()) :: integer()

      Contract head:
      (float()) :: float()

      Contract head:
      (binary()) :: binary()
    """

    #@spec id_redundancy() :: any()
    #def id_redundancy(), do: Ex1.id_redundancy()
    """
    """

    #@spec id_records() :: %{required(:atom) => integer(), optional(atom()) => any()}
    #def id_records1(), do: Ex1.id_records1(%{:a => 1, :b => :r})
    #def id_records2(), do: Ex1.id_records2(%{:a => 1, :b => :r})

    #def id_records3(), do: Ex1.id_records3(%{:a => 1, :c => :r})
    #def id_records3(), do: Ex1.id_records3(%{:a => 1, :b => 1, :c => :r})

    #def id_records4(), do: Ex1.id_records4(%{:a => "s"})
    #def id_records5(), do: Ex1.id_records5(%{:c => 8, :b => "d"})
    #def id_records6(), do: Ex1.id_records6(%{:c => "d", :b => "d"})
    #def id_records7(), do: Ex1.id_records7(%{:a => 1})

    #def id_records8(), do: Ex1.id_records8(%{:a => 1})
    def id_records9(), do: Ex1.id_records9(%{fn x -> "a" end => :a})
    #def id_records10(), do: Ex1.id_records10(%{nil => 1})

    def id_fun(), do: Ex1.id_fun(fn x -> <<97>> end)

    @spec fun(1) :: 2
    def fun(x) when x == 1, do: x+1
    def id_bin(), do: Ex1.id_bin(<<1::3>>)

    def id_tuple(), do: Ex1.id_tuple({1,"d"})

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
      b: term()
    }

  end
end
