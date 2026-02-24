@spec id(%{:a => integer()}) :: map()
def id(a) when is_map(a), do: a
