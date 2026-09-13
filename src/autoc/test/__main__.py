import autoc.test
import autoc.module

if __name__ == "__main__":
  with autoc.module.Module("test") as m:
    autoc.test.configure_module(m)