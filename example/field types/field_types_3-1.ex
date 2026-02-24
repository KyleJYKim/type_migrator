@spec id(%{optional(:a) => integer()}) :: map()
def id(a) when is_map(a), do: a
