#!/usr/bin/env bash
# ============================================================
# UniShell - Module 3 (File Permissions Lab) tests  (Phase 5)
# COMMAND: bash tests/test_05_permissions.sh | PURPOSE: prove chmod, umask and stat work on the practice file and that chown is never executed | MODULE: Permissions
# ============================================================

cd "$(dirname "$0")/.." || exit 1

pass=0
fail=0
ok()  { printf '  [PASS] %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf '  [FAIL] %s\n' "$1"; fail=$((fail + 1)); }

perm_run() { printf '\n' | bash -c "source ./lib/common.sh; source ./modules/permissions.sh; $1" 2>&1; }

printf 'Module 3 (File Permissions Lab) tests\n'

mkdir -p sandbox

# ---------- 1. the practice file ----------
printf '\n1. Practice file setup\n'
rm -f sandbox/perm_demo.txt 2>/dev/null
perm_run 'perm_make_demo' >/dev/null
if [ -f sandbox/perm_demo.txt ]; then ok "perm_make_demo creates sandbox/perm_demo.txt"; else bad "the practice file was not created"; fi
mode="$(stat -c '%a' sandbox/perm_demo.txt 2>/dev/null)"
if [ "$mode" = "644" ]; then ok "the practice file starts at mode 644"; else bad "starting mode is $mode, expected 644"; fi
if bash -c 'source ./lib/common.sh; check_inside_sandbox "$UNISHELL_SANDBOX/perm_demo.txt"'; then ok "the practice file is inside ./sandbox"; else bad "the practice file is outside ./sandbox"; fi

# ---------- 2. chmod is really honoured on this filesystem ----------
printf '\n2. chmod is honoured on this filesystem\n'
# COMMAND: chmod 600 | PURPOSE: set a known mode for the check | MODULE: Permissions
chmod 600 sandbox/perm_demo.txt
mode="$(stat -c '%a' sandbox/perm_demo.txt)"
if [ "$mode" = "600" ]; then ok "chmod 600 gives mode 600"; else bad "chmod 600 gave mode $mode"; fi
chmod 755 sandbox/perm_demo.txt
mode="$(stat -c '%a' sandbox/perm_demo.txt)"
if [ "$mode" = "755" ]; then ok "chmod 755 gives mode 755"; else bad "chmod 755 gave mode $mode"; fi

# ---------- 3. symbolic chmod ----------
printf '\n3. Symbolic chmod\n'
chmod 644 sandbox/perm_demo.txt
chmod u+x sandbox/perm_demo.txt
mode="$(stat -c '%a' sandbox/perm_demo.txt)"
if [ "$mode" = "744" ]; then ok "chmod u+x turns 644 into 744"; else bad "chmod u+x gave $mode, expected 744"; fi
chmod g-w sandbox/perm_demo.txt
mode="$(stat -c '%a' sandbox/perm_demo.txt)"
if [ "$mode" = "744" ]; then ok "chmod g-w keeps 744 (group had no write)"; else bad "chmod g-w gave $mode"; fi

# ---------- 4. the module's own numeric demo ----------
printf '\n4. The numeric chmod demo\n'
out="$(perm_run 'perm_demo_numeric')"
if printf '%s' "$out" | grep -qF "numeric mode = 600"; then ok "the demo shows mode 600 after chmod 600"; else bad "the 600 line is missing from the demo"; fi
if printf '%s' "$out" | grep -qF "numeric mode = 644"; then ok "the demo shows mode 644 after chmod 644"; else bad "the 644 line is missing from the demo"; fi
mode="$(stat -c '%a' sandbox/perm_demo.txt)"
if [ "$mode" = "644" ]; then ok "the demo leaves the file at 644"; else bad "the demo left mode $mode, expected 644"; fi

# ---------- 5. reading permissions ----------
printf '\n5. The read-permissions demo\n'
out="$(perm_run 'perm_demo_read')"
if printf '%s' "$out" | grep -qF "OWNER"; then ok "the demo explains owner, group and others"; else bad "the explanation text is missing"; fi
if printf '%s' "$out" | grep -qF "numeric mode = 644"; then ok "stat reports the numeric mode"; else bad "stat output is missing from the demo"; fi

# ---------- 6. umask ----------
printf '\n6. umask\n'
out="$(perm_run 'perm_demo_umask')"
if printf '%s' "$out" | grep -qF "umask 077 -> new FILE mode 600"; then ok "umask 077 makes a new file 600"; else bad "the umask 077 file line is missing"; fi
if printf '%s' "$out" | grep -qF "umask 077 -> new DIR  mode 700"; then ok "umask 077 makes a new directory 700"; else bad "the umask 077 directory line is missing"; fi
# The demo must not leak the strict mask into the parent shell.
if printf '%s' "$out" | grep -qF "the UniShell umask is not changed"; then ok "the demo states that the parent umask is untouched"; else bad "the umask explanation is missing"; fi

# ---------- 7. chown is explained, never executed ----------
printf '\n7. chown is explained, never run\n'
owner_before="$(stat -c '%U:%G' sandbox/perm_demo.txt 2>/dev/null)"
out="$(perm_run 'perm_demo_chown')"
owner_after="$(stat -c '%U:%G' sandbox/perm_demo.txt 2>/dev/null)"
if printf '%s' "$out" | grep -qiF "chown"; then ok "the demo explains chown"; else bad "chown is not explained"; fi
if [ "$owner_before" = "$owner_after" ]; then ok "chown did not change the owner of the practice file"; else bad "the owner changed from $owner_before to $owner_after"; fi
if grep -q 'chown --' modules/permissions.sh; then bad "modules/permissions.sh appears to run chown"; else ok "modules/permissions.sh never runs chown"; fi

# ---------- 8. no dynamic execution ----------
printf '\n8. No dynamic execution\n'
if grep -n '\beval\b' modules/permissions.sh >/dev/null 2>&1; then bad "the word eval appears in modules/permissions.sh"; else ok "modules/permissions.sh contains no eval"; fi

# ---------- clean up ----------
find sandbox -mindepth 1 ! -name '.gitkeep' -exec rm -rf -- {} + 2>/dev/null

# ---------- summary ----------
printf '\nmodule 3 test result: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -eq 0 ]; then exit 0; else exit 1; fi
