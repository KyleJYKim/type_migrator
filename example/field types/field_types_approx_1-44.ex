@spec id(%{%{required(atom()) => atom()} => integer()}) :: any()
def id(a) when is_map(a), do: a
