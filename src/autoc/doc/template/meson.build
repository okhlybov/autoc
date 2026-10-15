project('@project@',
  version: '@version@',
  meson_version: '>= 1.1'
)

fs = import('fs')
doxygen = find_program('doxygen', required: true)
py = import('python').find_installation('python3')

# Read site configuration if present
site_py = ''
site_pythonpath = ''
if fs.exists('.autoc/meson.site')
  site_lines = fs.read('.autoc/meson.site').strip().split('\n')
  foreach line : site_lines
    if line.startswith('PYTHON = ')
      site_py = line.substring(10, -1)
    elif line.startswith('AUTOC_PYTHONPATH = ')
      site_pythonpath = line.substring(20, -1)
    endif
  endforeach
endif

if site_py != ''
  py = import('python').find_installation(site_py, required: false)
endif

module_name = '@module@'
env_cmd = []
if site_pythonpath != ''
  env_cmd = ['env', 'PYTHONPATH=' + site_pythonpath]
endif

gen_cmd = []
if env_cmd.length() > 0
  gen_cmd += env_cmd
endif
gen_cmd += [py, '@INPUT@', module_name, '@OUTPUT@']

autoc_gen = custom_target(
  module_name + '-generate',
  input: module_name + '.py',
  output: module_name + '.stamp',
  command: gen_cmd,
  build_by_default: true,
)

doc_cmd = [doxygen, files('Doxyfile')]

doc_target = custom_target(
  'doc',
  command: doc_cmd,
  output: 'reference',
  depends: [autoc_gen],
  build_by_default: true,
)
