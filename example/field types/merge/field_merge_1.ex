@spec id(%{atom() => integer(), atom() => binary()}) :: any()
def id(a) when is_map(a), do: a
