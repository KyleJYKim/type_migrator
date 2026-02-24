@spec id(%{required(:a | :b) => integer(), optional(atom()) => binary()}) :: any()
def id(a) when is_map(a), do: a
