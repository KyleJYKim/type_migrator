@spec id(%{1..10 => integer(), 10..20 => binary()}) :: any()
def id(a) when is_map(a), do: a
