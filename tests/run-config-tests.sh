#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_BIN="/tmp/labconf-config-matrix-test"
SMOKE_BIN="/tmp/labconf-config-smoke-test"
LAYOUT_BIN="/tmp/labconf-config-layout-test"
ENV_BIN="/tmp/labconf-environment-logic-test"
TEST_HOME="/tmp/labconf-config-matrix-home"

rm -rf "$TEST_HOME"
mkdir -p "$TEST_HOME"

valac --pkg gio-2.0 --pkg glib-2.0 \
  -o "$TEST_BIN" \
  "$ROOT_DIR/src/config.vala" \
  "$ROOT_DIR/tests/config_matrix_test.vala"

HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/.config" "$TEST_BIN"

valac --pkg gio-2.0 --pkg glib-2.0 \
  -o "$SMOKE_BIN" \
  "$ROOT_DIR/src/config.vala" \
  "$ROOT_DIR/tests/config_smoke_test.vala"

HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/.config" "$SMOKE_BIN"

valac --pkg gio-2.0 --pkg glib-2.0 \
  -o "$LAYOUT_BIN" \
  "$ROOT_DIR/src/config.vala" \
  "$ROOT_DIR/tests/config_layout_logic_test.vala"

HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/.config" "$LAYOUT_BIN"

valac --pkg gio-2.0 --pkg glib-2.0 \
  -o "$ENV_BIN" \
  "$ROOT_DIR/src/environment_config.vala" \
  "$ROOT_DIR/tests/environment_logic_test.vala"

HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/.config" "$ENV_BIN"
