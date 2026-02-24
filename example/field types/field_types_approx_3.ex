@spec id(%{optional(:a | :b | binary() | atom()) => integer()}) :: any()
def id(a) when is_map(a), do: a
