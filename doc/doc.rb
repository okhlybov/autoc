require 'autoc'
require 'autoc/vector'
require 'autoc/hash_map'

def type(x, brief)
  AutoC::Synthetic.new(x,
    default_create: "#{x}Create",
    copy: "#{x}Copy",
    code: "#{x}Code",
    equal: "#{x}Equal",
    interface: %$
      /**
        @brief #{brief}
      */
      typedef struct {int _; /**< @private */} #{x};
      #define #{x}Create(self)
      #define #{x}Copy(self, source)
      #define #{x}Code(self) 0
      #define #{x}Equal(lt, rt) 0
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