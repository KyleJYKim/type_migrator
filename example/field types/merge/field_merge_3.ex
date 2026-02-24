@spec id(%{atom() => integer(), binary() => integer()}) :: any()
def id(a) when is_map(a), do: a
