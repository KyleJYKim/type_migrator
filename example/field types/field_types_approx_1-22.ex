@spec id(%{(atom(), integer() -> atom()) => integer()}) :: any()
def id(a) when is_map(a), do: a
