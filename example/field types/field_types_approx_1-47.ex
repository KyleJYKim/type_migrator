@spec id(%{%SomeStruct{a: atom()} => integer()}) :: any()
def id(a) when is_map(a), do: a
