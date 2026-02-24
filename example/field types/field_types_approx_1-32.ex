@spec id(%{1..1_000 => integer()}) :: any()
def id(a) when is_map(a), do: a
