import autoc.test
import autoc.module

if __name__ == "__main__":
  with autoc.module.Module("test") as m:
    m.source_threshold = 100*1024
    autoc.test.configure_module(m)