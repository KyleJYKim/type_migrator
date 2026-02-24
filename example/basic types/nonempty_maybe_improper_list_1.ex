
@spec id(nonempty_maybe_improper_list(integer(), [])) :: nonempty_maybe_improper_list(integer(), [])
def id(a) when is_list(a), do: a
