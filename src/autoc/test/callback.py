import autoc.core
from autoc.module import Code
from autoc.callback import Callback


unary = Callback("unary_op", result="int", parameters={"x": "int"})


helpers = Code(interface="""
  AUTOC_STATIC_INLINE int callback_double(int x) { return x*2; }
  AUTOC_STATIC_INLINE int callback_negate(int x) { return -x; }
""", dependencies=(autoc.core._linkage_code,))
