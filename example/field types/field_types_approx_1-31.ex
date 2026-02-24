@spec id(%{1 => integer()}) :: any()
def id(a) when is_map(a), do: a
