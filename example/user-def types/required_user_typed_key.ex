defmodule RequiredUserTypedKey do
  # The map key `:name` is sourced from a user-defined type, so during
  # user-type replacement the field's key changes from {:user_type, :key_t}
  # to {:atom, :name}. The field is declared `required`, and must stay
  # required after replacement — it must NOT be wrapped in if_set().
  @type key_t :: :name

  @spec f(integer()) :: %{required(key_t()) => binary(), optional(:age) => integer()}
  def f(x), do: %{name: "a", age: x}
end
