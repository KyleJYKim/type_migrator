@spec id(pos_integer()) :: pos_integer()
def id(a) when is_integer(a) and a > 0, do: a
