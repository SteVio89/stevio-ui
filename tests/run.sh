#!/usr/bin/env bash
# Runs every check CI runs: syntax, lint, format and the unit tests.
# Usage: tests/run.sh  (from anywhere; needs lua5.1 or lua, luac, luacheck, stylua)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

lua=$(command -v lua5.1 || command -v lua)
luac=$(command -v luac5.1 || command -v luac)

echo "== syntax"
git ls-files '*.lua' | while read -r file; do
	"$luac" -p "$file"
done

echo "== luacheck"
luacheck --no-color -q .

echo "== stylua"
stylua --check .

echo "== tests"
for test in tests/*_test.lua; do
	echo "-- $test"
	"$lua" "$test"
done

echo "all checks passed"
