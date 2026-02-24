@spec id(pid()) :: pid()
def id(a) when is_pid(a), do: a
