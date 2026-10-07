import autoc.scaffolder


reader = autoc.scaffolder.make_template_reader(__package__)


class Scaffolder(autoc.scaffolder.Scaffolder):

  def __init__(self, resources=None, parameters=None):
    params = dict(parameters or {})
    generator = params.get("generator", "autoc.cmake.CMake")
    params.setdefault("generator", generator)
    if "generator_module" not in params:
      params["generator_module"] = generator.rpartition(".")[0] if "." in generator else generator

    super().__init__(
      resources={
        "@module@.py": reader,
        "@module@.c": reader,
      } | dict(resources or {}),
      parameters=params,
    )
