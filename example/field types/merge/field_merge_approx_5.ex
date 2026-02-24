@spec id(%{optional(atom()) => integer(), required(:b) => binary()}) :: any()
def id(a) when is_map(a), do: a
