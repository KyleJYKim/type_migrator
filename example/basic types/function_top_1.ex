@spec id((... -> any())) :: (... -> any())
def id(a) when is_function(a), do: a
