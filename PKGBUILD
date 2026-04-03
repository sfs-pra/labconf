# PKGBUILD для labconf
# Автор: opencode
# Лицензия: GPL-3.0-or-later

pkgname=labconf
pkgver=1.0.0
pkgrel=1
_srcname="${pkgname}-${pkgver}"
pkgdesc="GTK3 конфигуратор тем и параметров labwc (obconf-like)"
arch=('x86_64')
url="https://github.com/labwc/labwc"
license=('GPL-3.0-or-later')
depends=(
    'gtk3'
    'glib2'
    'pango'
)
makedepends=(
    'vala'
    'meson'
    'ninja'
)
optdepends=(
    'labwc: оконный менеджер Wayland'
)

# Исходники - текущая директория
source=("${_srcname}.tar.gz")

sha256sums=('SKIP')

prepare() {
    cd "${srcdir}/${_srcname}"
    rm -rf build/
}

build() {
    cd "${srcdir}/${_srcname}"
    
    # Настройка meson
    arch-meson build \
        --prefix=/usr \
        --buildtype=release \
        -Db_lto=true
    
    # Сборка
    ninja -C build
}

check() {
    cd "${srcdir}/${_srcname}"
    ./tests/run-config-tests.sh
}

package() {
    cd "${srcdir}/${_srcname}"
    
    # Установка
    DESTDIR="${pkgdir}" ninja -C build install
    
    # Лицензия
    install -Dm644 README.md \
        "${pkgdir}/usr/share/licenses/${pkgname}/README.md"
}
