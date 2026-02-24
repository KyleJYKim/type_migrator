@spec id(%{true => integer()}) :: any()
def id(a) when is_map(a), do: a
