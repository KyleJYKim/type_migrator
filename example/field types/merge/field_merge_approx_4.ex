@spec id(%{optional(atom()) => integer(), optional(:b) => binary()}) :: any()
def id(a) when is_map(a), do: a
