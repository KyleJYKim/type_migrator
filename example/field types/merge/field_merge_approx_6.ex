@spec id(%{optional(:a) => integer(), optional(atom()) => binary()}) :: any()
def id(a) when is_map(a), do: a
