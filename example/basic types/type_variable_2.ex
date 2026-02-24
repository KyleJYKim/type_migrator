@spec id(a) :: b when a: integer(), b: binary()
def id(a) when is_integer(a), do: a |> Integer.to_string()
