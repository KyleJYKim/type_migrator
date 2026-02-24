@spec id(%{optional(atom()) => integer(), optional(binary()) => float()}) :: any()
def id(a) when is_map(a), do: a
