@spec id(%{atom() => integer(), :a => binary()}) :: any()
def id(a) when is_map(a), do: a
