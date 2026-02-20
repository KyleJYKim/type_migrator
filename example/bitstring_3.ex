@spec id(<<_::_*4>>) :: <<_::_*4>>
def id(a) when is_bitstring(a), do: a
