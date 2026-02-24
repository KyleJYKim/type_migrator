@spec id(%{%SomeStruct{} => integer()}) :: any()
def id(a) when is_map(a), do: a
