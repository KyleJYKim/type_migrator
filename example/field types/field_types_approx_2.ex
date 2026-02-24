@spec id(%{optional(:a | :b | binary()) => integer()}) :: any()
def id(a) when is_map(a), do: a
