@spec id((integer() -> integer())) :: (integer() -> integer())
def id(a) when is_function(a), do: a
