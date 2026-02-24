@spec id_shuffle({integer(), atom(), binary()}) :: {integer(), binary(), atom()}
def id_shuffle({x, y, z}) when is_integer(x) and is_atom(y), is_binary(z), do: {x, z, y}
