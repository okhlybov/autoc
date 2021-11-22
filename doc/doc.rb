require 'autoc'
require 'autoc/vector'
require 'autoc/hash_map'

def type(x, brief)
  AutoC::Synthetic.new(x,
    default_create: "#{x}Create",
    copy: "#{x}Copy",
    hash_code: "#{x}HashCode",
    equal: "#{x}Equal",
    compare: "#{x}Compare",
    interface: %$
      /**
        @brief #{brief}
      */
      typedef struct {int _; /**< @private */} #{x};
      #define #{x}Create(self)
      #define #{x}Copy(self, source)
      #define #{x}HashCode(self) 0
      #define #{x}Equal(lt, rt) 0
      #define #{x}Compare(lt,rt) 0
    $
  )
end

T = type(:T, 'A generic value type')
K = type(:K, 'A generic hashable value type')

AutoC::Module.render(:doc) do |m|
  m << AutoC::Vector.new(:Vector, T)
  m << AutoC::HashMap.new(:HashMap, K, T)
  m << AutoC::Code.new(definitions: %$int main(int a, char**b) {}$)
end