@spec id(%{optional(:a | :b) => integer(), :b => binary()}) :: any()
def id(a) when is_map(a), do: a
