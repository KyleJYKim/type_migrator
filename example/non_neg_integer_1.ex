@spec id(non_neg_integer()) :: non_neg_integer()
def id(a) when is_integer(a) and a >= 0, do: a
