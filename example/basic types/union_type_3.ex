@spec id(integer() | float()) :: integer() | float()
def id(a) when is_integer(a) or is_float(a), do: a
