@spec id(%{required(atom()) => integer()}) :: map()
def id(a) when is_map(a), do: a
