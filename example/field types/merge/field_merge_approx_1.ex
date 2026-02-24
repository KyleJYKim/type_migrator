@spec id(%{1..10 => integer(), 10 => binary()}) :: any()
def id(a) when is_map(a), do: a
