require 'singleton'
require 'autoc/std'
require 'autoc/module'
require 'autoc/composite'


module AutoC::Random


  # Class representing global random seed state
  class Seed

    include Singleton

    include AutoC::Entity

    def initialize
      references << AutoC::Random.seeder
      dependencies << DEFINITIONS << AutoC::Module::DEFINITIONS << AutoC::STD::ASSERT_H
    end

    def render_interface(stream)
      super
      stream << %{
        #ifndef AUTOC_SEED
          #define _AUTOC_RANDOMIZE_SEED /* when defined the seed is initialized with a random value */
          #define AUTOC_SEED _autoc_seed
          AUTOC_EXTERN autoc_random_t _autoc_seed; /**< @private */
        #elif ~(~AUTOC_SEED + 1) == 1 /* if macro value is unspecified on the command line it is implicitly set to 1 */
          #undef AUTOC_SEED
          #define AUTOC_SEED 1
        #endif
      }
    end

    def render_implementation(stream)
      super
      stream << %{
        #ifdef _AUTOC_RANDOMIZE_SEED
          autoc_random_t _autoc_seed = 1;
          #if defined(__cplusplus)
            extern "C" void _autoc_randomize_seed(void);
          #elif defined(__GNUC__) || defined(__clang__) || defined(__INTEL_COMPILER) || defined(__INTEL_LLVM_COMPILER)
            void _autoc_randomize_seed(void) __attribute__((__constructor__));
          #elif defined(__POCC__)
            void __cdecl _autoc_randomize_seed(void);
            #pragma startup _autoc_randomize_seed
          #elif defined(_MSC_VER)
            #pragma message("WARNING: _autoc_randomize_seed() will not be called automatically; either call it manually or compile this source as C++ in order to actually yield random seed")
          #else
            #warning _autoc_randomize_seed() will not be be called automatically; either call it manually or compile this source as C++ in order to actually yield random seed
          #endif
          void _autoc_randomize_seed(void) {
            _autoc_seed = #{AutoC::Random.seeder.generate(nil)};
            assert(_autoc_seed != 0);
          }
          #ifdef __cplusplus
            static struct _seeder {
              _seeder() { _autoc_randomize_seed(); }
            } _seeder;
          #endif

        #endif
      }
    end

  end # Seed


  def self.seed = Seed.instance


  DEFINITIONS = AutoC::Code.new interface: %{
    /**
      @brief Random number type
      @since 2.1
    */
    typedef unsigned long int autoc_random_t;
  }


  # Default random seed generator
  class Seeder

    include Singleton

    include AutoC::Entity

    def initialize = dependencies << AutoC::Module::DEFINITIONS << DEFINITIONS << AutoC::STD::STDLIB_H

    def generate(*args) = args.empty? ? 'autoc_random_seed_next' : 'autoc_random_seed_next()'

    def render_interface(stream)
      super
      stream << %{
        /**
          @brief Generate a random seed value with default seeder

          The exact quality depends on the target platform.
          Its purpose is to be useful when no specific properties for the seeds are required.
          As a consequence is not meant to be cryptographically viable.

          @since 2.1
        */
        AUTOC_EXTERN autoc_random_t #{generate}(void);
      }
    end

    def render_implementation(stream)
      super
      # TODO ensure the seed is a full 32 bit random value
      # Ex. std::random_device()() yield unsigned int which might be 16 bit type
      stream << %{
        #if __cplusplus >= 201103L
          #include <random>
        #endif
        #include <time.h>
        autoc_random_t #{generate}(void) {
          #if defined(__POCC__)
            /* Pelles C check comes first as it might define _MSC_VER as well */
            unsigned r;
            _rand_s(&r);
            return r;
          #elif defined(_MSC_VER) && !(defined(__INTEL_COMPILER) || defined(__INTEL_LLVM_COMPILER)) /* Intel compilers define _MSC_VER on Windows yet their CRTs seem to lack rand_s() */
            unsigned r;
            rand_s(&r);
            return r;
          #elif __cplusplus >= 201103L
            return std::random_device()();
          #elif _POSIX_C_SOURCE >= 199309L
            struct timespec ts;
            clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &ts);
            srand(ts.tv_nsec);
            return rand();
          #else
            srand(time(NULL));
            return rand();
          #endif
        }
      }
    end

  end # Seeder


  def self.seeder = @seeder
  def self.seeder=(s) @seeder = s end
  
  
  self.seeder = Seeder.instance


  # Default pseudo-random number generator
  class Generator
  
    include Singleton

    include AutoC::Entity

    def initialize = dependencies << AutoC::Module::DEFINITIONS << DEFINITIONS << AutoC::STD::ASSERT_H

    def to_s = type

    def type = :autoc_random_t

    def state_type = type

    def generate(state = nil)  = state.nil? ? 'autoc_random_next' : "autoc_random_next(&(#{state}))"

    def render_interface(stream)
      super
      stream << %{
        /**
          @brief Generate a random value with default pseudo-random number generator

          @since 2.1
        */
        AUTOC_EXTERN #{type} autoc_random_next(#{state_type}* state);
      }
    end

    def render_implementation(stream)
      super
      # https://en.wikipedia.org/wiki/Lehmer_random_number_generator
      stream << %{
        #{type} #{generate}(#{state_type}* state) {
          /* Park-Miller PRNG */
          #if __cplusplus >= 201103L || __STDC_VERSION__ >= 199901L || defined(HAVE_LONG_LONG)
            /* suitable for machines with types wider than autoc_random_t avaliable */
            typedef unsigned long long int ull_t;
            ull_t product = (ull_t)*state * 48271;
            ull_t x = (product & 0x7fffffff) + (product >> 31);
            x = (x & 0x7fffffff) + (x >> 31);
          #else
            /* fallback implementation for any 32-bit machine */
            const #{type} A = 48271;
            #{type} low  = (*state & 0x7fff) * A;
            #{type} high = (*state >> 15)    * A;
            #{type} x = low + ((high & 0xffff) << 15) + (high >> 16);
            x = (x & 0x7fffffff) + (x >> 31);
          #endif
        assert(*state != 0); /* zero state breaks the LCG type generator */
        return *state = x;
      }
      }
    end

  end # Generator


  def self.generator = @generator
  def self.generator=(g) @generator = g end

  self.generator = Generator.instance


end