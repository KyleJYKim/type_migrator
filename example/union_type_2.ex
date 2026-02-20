@spec id(integer()) :: integer() | float()
def id(a) when is_integer(a), do: (if a > 0, do: a, else: a * 1.1)
