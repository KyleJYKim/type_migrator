@spec id(%{<<_::8>> => integer()}) :: any()
def id(a) when is_map(a), do: a
