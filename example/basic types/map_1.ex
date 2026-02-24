@spec id(%{pid() => integer(), atom() => binary()}) :: %{pid() => integer(), atom() => binary()}
def id(a) when is_map(a), do: a
