@spec id(%{optional(atom()) => integer()}) :: map()
def id(a) when is_map(a), do: a
