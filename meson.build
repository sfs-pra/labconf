project('labconf', 'vala',
  version: '1.0.0',
  meson_version: '>= 0.56.0'
)

subdir('po')

gtk_dep = dependency('gtk+-3.0', version: '>= 3.22')
glib_dep = dependency('glib-2.0')
cc = meson.get_compiler('c')
math_dep = cc.find_library('m', required: true)

executable('labconf',
  sources: [
    'src/main.vala',
    'src/config.vala',
    'src/environment_config.vala',
    'src/backup.vala',
    'src/themes.vala',
    'src/fonts.vala',
    'src/theme_parser.vala',
    'src/xbm_parser.vala'
  ],
  c_args: ['-DGETTEXT_PACKAGE="labconf"'],
  dependencies: [gtk_dep, glib_dep, math_dep],
  install: true,
  install_dir: get_option('prefix') / 'bin'
)

install_data('data/labconf.desktop',
  install_dir: get_option('prefix') / 'share/applications'
)
