#!/usr/bin/env bash
# sanitize-configs.sh — XML-safe sanitizer + detailed report (file:line) with debug logging
# - XML handled with xmlstarlet (or Python fallback): structure preserved
# - Redacts secrets, usernames, UUIDs; masks public IPv4s (ignores 1.1.1.1 / 8.8.8.8)
# - Explicitly redacts OPNsense WebGUI cert/key nodes: <crt>, <prv> (plus <cert>, etc.)
# - Originals untouched; sanitized copy + report written under configs/sanitized/<timestamp>/
# - Verbose debug messages to stderr; cleans up temp files even on error

set -euo pipefail

# ---------- config ----------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$ROOT"
OUT="$ROOT/sanitized"
STAMP="$(date +%Y%m%d_%H%M%S)"
DST="$OUT/$STAMP"
REPORT="$DST/SANITIZE-REPORT-$STAMP.txt"

# Exclude scripts/internal from copy
RSYNC_EXCLUDES=(
  --exclude 'sanitized/'
  --exclude 'file-list/'
  --exclude '*.sh'
  --exclude 'SANITIZE-REPORT-*.txt'
  --exclude 'audit-report-*.txt'
  --exclude 'scan-report-*.txt'
  --exclude 'file-list-*.txt'
)

# Patterns
ALLOWLIST_IPS_RE='(1\.1\.1\.1|8\.8\.8\.8)'
UUID_RE='[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

# Add crt/prv to catch OPNsense WebGUI certificate and private key blobs
SECRET_KEYS_RE='(password|passwd|pass|passphrase|secret|token|api[_-]?key|client[_-]?secret|private[_-]?key|shared[_-]?key|preshared|psk|auth(pass(word)?)?|community|cert|certificate|crt|prv)'
USER_KEYS_RE='(username|user|login|admin[_-]?user|owner|rbd[_-]?user|db[_-]?user|pguser)'

# Toggle: mask public IPs inside XML too?
MASK_IPS_IN_XML=true

# ---------- debug helpers ----------
say_dbg() { echo -e "\033[33m[debug]\033[0m $*" >&2; }   # yellow to stderr
say()     { printf "%s\n" "$*" | tee -a "$REPORT" >/dev/null; }
section() { printf "\n===== %s =====\n" "$1" | tee -a "$REPORT" >/dev/null; }
is_text() { grep -Iq . "$1"; } # crude text/binary check

# Cleanup any temp files we might leave behind, even on error
cleanup_temps() {
  say_dbg "Cleaning up temp files under $DST (if any)…"
  find "$DST" -type f \( -name '*.bak' -o -name '*.__tmp' -o -name '*.__san' \) -print -delete 2>/dev/null || true
}
trap cleanup_temps EXIT

# ---------- env checks ----------
command -v rsync >/dev/null 2>&1 || { echo "rsync not found"; exit 1; }

# ---------- helpers ----------
is_public_ip_shell() {
  local ip="$1" a b c d
  IFS='.' read -r a b c d <<<"$ip" || return 1
  for n in "$a" "$b" "$c" "$d"; do [[ "$n" =~ ^[0-9]+$ ]] && (( n>=0 && n<=255 )) || return 1; done
  if ((a==10)) || ( ((a==172)) && ((b>=16&&b<=31)) ) || ( ((a==192)) && b==168 ) || (a==127) || (a==169 && b==254); then
    return 1
  fi
  [[ "$ip" =~ ^(1\.1\.1\.1|8\.8\.8\.8)$ ]] && return 1
  return 0
}

mask_preview_line() {
  # Mask preview for REPORT (never leak raw values)
  sed -E '
    s/(\b('"$SECRET_KEYS_RE"'|'"$USER_KEYS_RE"')\b\s*[:=]\s*)("[^"]*"|'\''[^'\'']*'\''|[^#;,\s]+|\S)/\1REDACTED/Ig;
    s/([, \t]|^)(('"$SECRET_KEYS_RE"'|'"$USER_KEYS_RE"'))=([^, \t]+)/\1\2=REDACTED/Ig;
    s!(<\s*(('"$SECRET_KEYS_RE"'|'"$USER_KEYS_RE"'))\b[^>]*>)[^<]{1,2048}(</\s*\2\s*>)!\1REDACTED\4!Ig;
    s/"(('"$SECRET_KEYS_RE"'|'"$USER_KEYS_RE"'))"\s*:\s*"[^"]*"/"\1":"REDACTED"/Ig;
    s/'"'"'(('"$SECRET_KEYS_RE"'|'"$USER_KEYS_RE"'))'"'"'\s*:\s*'"'"'[^'"'"']*'"'"'/'"'"'\1'"'"': '"'"'REDACTED'"'"'/Ig;
    s/'"$UUID_RE"'/UUID-REDACTED/gI;
  ' <<<"$1"
}

report_line() {
  local kind="$1" f="$2" ln="$3" raw="$4"
  local masked; masked="$(mask_preview_line "$raw")"
  say "  [$kind] $f:$ln: $masked"
}

scan_report_before_edit() {
  local f="$1"
  say_dbg "Scanning for report: $f"
  grep -Eni '(^|[^A-Za-z0-9_])(('"$SECRET_KEYS_RE"'|'"$USER_KEYS_RE"'))([^A-Za-z0-9_])' "$f" 2>/dev/null \
    | while IFS=: read -r ln line; do report_line "secret/user" "$f" "$ln" "$line"; done || true
  grep -Eni "<\s*(('"$SECRET_KEYS_RE"'|'"$USER_KEYS_RE"'))\b" "$f" 2>/dev/null \
    | while IFS=: read -r ln line; do report_line "xml-tag" "$f" "$ln" "$line"; done || true
  grep -Eni "('\''|\"| )?(('"$SECRET_KEYS_RE"'|'"$USER_KEYS_RE"'))\s*=" "$f" 2>/dev/null \
    | while IFS=: read -r ln line; do report_line "xml-attr" "$f" "$ln" "$line"; done || true
  grep -Eni '(^|[[:space:]])args[[:space:]]*:.*('"$SECRET_KEYS_RE"')=' "$f" 2>/dev/null \
    | while IFS=: read -r ln line; do report_line "secret" "$f" "$ln" "$line"; done || true
  grep -Eni 'password' "$f" 2>/dev/null \
    | while IFS=: read -r ln line; do report_line "password-any" "$f" "$ln" "$line"; done || true
  grep -Eno "$UUID_RE" "$f" 2>/dev/null \
    | while IFS=: read -r ln _; do say "  [uuid]  $f:$ln: UUID-REDACTED"; done || true
  grep -Eno '([0-9]{1,3}\.){3}[0-9]{1,3}' "$f" 2>/dev/null \
    | while IFS=: read -r ln ip; do is_public_ip_shell "$ip" && say "  [ipmask] $f:$ln: $ip -> 0.0.0.0"; done || true
}

# ---------- XML sanitizer (safe) ----------
sanitize_xml_inplace() {
  local f="$1"
  say_dbg "Sanitizing XML: $f"
  if command -v xmlstarlet >/dev/null 2>&1; then
    # XSLT transform: redact element text & attribute values for sensitive names (case-insensitive)
    if ! xmlstarlet tr -s <(cat <<'XSL'
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  <xsl:strip-space elements="*"/>
  <xsl:variable name="AZ" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"/>
  <xsl:variable name="az" select="'abcdefghijklmnopqrstuvwxyz'"/>

  <!-- identity -->
  <xsl:template match="@*|node()"><xsl:copy><xsl:apply-templates select="@*|node()"/></xsl:copy></xsl:template>

  <!-- redact element text if local-name contains a sensitive substring -->
  <xsl:template match="*[
    contains(translate(local-name(),$AZ,$az),'pass') or
    contains(translate(local-name(),$AZ,$az),'secret') or
    contains(translate(local-name(),$AZ,$az),'token') or
    contains(translate(local-name(),$AZ,$az),'key') or
    contains(translate(local-name(),$AZ,$az),'auth') or
    contains(translate(local-name(),$AZ,$az),'psk') or
    contains(translate(local-name(),$AZ,$az),'user') or
    contains(translate(local-name(),$AZ,$az),'cert') or
    contains(translate(local-name(),$AZ,$az),'crt') or
    contains(translate(local-name(),$AZ,$az),'prv')
  ]">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:text>REDACTED</xsl:text>
    </xsl:copy>
  </xsl:template>

  <!-- redact attribute values if attribute name contains a sensitive substring -->
  <xsl:template match="@*[
    contains(translate(local-name(),$AZ,$az),'pass') or
    contains(translate(local-name(),$AZ,$az),'secret') or
    contains(translate(local-name(),$AZ,$az),'token') or
    contains(translate(local-name(),$AZ,$az),'key') or
    contains(translate(local-name(),$AZ,$az),'auth') or
    contains(translate(local-name(),$AZ,$az),'psk') or
    contains(translate(local-name(),$AZ,$az),'user') or
    contains(translate(local-name(),$AZ,$az),'cert') or
    contains(translate(local-name(),$AZ,$az),'crt') or
    contains(translate(local-name(),$AZ,$az),'prv')
  ]">
    <xsl:attribute name="{name()}">REDACTED</xsl:attribute>
  </xsl:template>
</xsl:stylesheet>
XSL
    ) "$f" > "$f.__san"; then
      say_dbg "!! xmlstarlet transform failed on $f; falling back to Python"
      rm -f "$f.__san"
      python3 - "$f" <<'PY'
import sys, xml.etree.ElementTree as ET
f = sys.argv[1]
# Include crt/prv in sensitive names
keys = ('pass','secret','token','key','auth','psk','user','cert','crt','prv')
def redact(e):
    name = e.tag.split('}')[-1].lower()
    if any(k in name for k in keys):
        e.text = 'REDACTED'
    for a in list(e.attrib):
        if any(k in a.lower() for k in keys):
            e.attrib[a] = 'REDACTED'
    for c in list(e): redact(c)
t = ET.parse(f); r = t.getroot(); redact(r)
t.write(f, encoding='utf-8', xml_declaration=True)
PY
    else
      mv "$f.__san" "$f"
    fi
  else
    say_dbg "xmlstarlet not found; using Python XML sanitizer for $f"
    python3 - "$f" <<'PY'
import sys, xml.etree.ElementTree as ET
f = sys.argv[1]
keys = ('pass','secret','token','key','auth','psk','user','cert','crt','prv')
def redact(e):
    name = e.tag.split('}')[-1].lower()
    if any(k in name for k in keys):
        e.text = 'REDACTED'
    for a in list(e.attrib):
        if any(k in a.lower() for k in keys):
            e.attrib[a] = 'REDACTED'
    for c in list(e): redact(c)
t = ET.parse(f); r = t.getroot(); redact(r)
t.write(f, encoding='utf-8', xml_declaration=True)
PY
  fi
}

# ---------- non-XML sanitizers ----------
sanitize_uuid_inplace() {
  local f="$1"
  say_dbg "Redacting UUIDs in $f"
  sed -E -i "s/${UUID_RE}/UUID-REDACTED/gI" "$f"
}

mask_public_ips_inplace() {
  local f="$1"
  say_dbg "Masking public IPs in $f"

  # Fast precheck: bail if no IPv4-looking tokens
  if ! grep -Eq '([0-9]{1,3}\.){3}[0-9]{1,3}' "$f"; then
    say_dbg "No IPv4-looking tokens in $f; skipping."
    return 0
  fi

  # Protect allowlisted IPs (1.1.1.1, 8.8.8.8)
  sed -E "s/${ALLOWLIST_IPS_RE}/__ALLOW_IP__/g" "$f" > "$f.__tmp" && mv "$f.__tmp" "$f" || { rm -f "$f.__tmp"; return; }

  # Single-pass Perl: replace only non-RFC1918/non-loopback/non-link-local with 0.0.0.0
  perl -0777 -i -pe '
    sub is_pub {
      my ($ip) = @_;
      return 0 if $ip eq "__ALLOW_IP__";
      my @o = split(/\./, $ip); return 0 unless @o==4;
      for (@o) { return 0 unless /^\d+$/ && $_>=0 && $_<=255 }
      return 0 if $o[0]==10;
      return 0 if $o[0]==172 && $o[1]>=16 && $o[1]<=31;
      return 0 if $o[0]==192 && $o[1]==168;
      return 0 if $o[0]==127;
      return 0 if $o[0]==169 && $o[1]==254;
      return 1;
    }
    s{(?<!\d)((?:\d{1,3}\.){3}\d{1,3})(?!\d)}{ is_pub($1) ? "0.0.0.0" : $1 }eg;
  ' "$f"

  # Restore allowlisted IPs
  sed -E -i "s/__ALLOW_IP__/1.1.1.1/g" "$f"
  sed -E -i "0,/1\.1\.1\.1/{s/1\.1\.1\.1/__A__/}" "$f"
  sed -E -i "s/__ALLOW_IP__/8.8.8.8/g" "$f" || true
  sed -E -i "s/__A__/1.1.1.1/g" "$f"

  say_dbg "Public IP masking done for $f"
}

sanitize_kv_like_inplace() {
  local f="$1"
  say_dbg "Sanitizing KV/JSON/YAML/args in $f"
  sed -E -i.bak '
    s/(\b('"$SECRET_KEYS_RE"'|'"$USER_KEYS_RE"')\b\s*[:=]\s*)("[^"]*"|'\''[^'\'']*'\''|[^#;,\s]+)/\1REDACTED/Ig;
    s/(\b('"$SECRET_KEYS_RE"'|'"$USER_KEYS_RE"')\b)[[:space:]]+("[^"]*"|'\''[^'\'']*'\''|[^#;,\s]+)/\1 REDACTED/Ig;
    s/([,{ \t]|^)(('"$SECRET_KEYS_RE"'|'"$USER_KEYS_RE"'))[ \t]*:[ \t]*("[^"]*"|'\''[^'\'']*'\''|[^#,\}\s]+)/\1\3: "REDACTED"/Ig;
    s/((^|[\s,])--[A-Za-z0-9_-]*pass(word)?[A-Za-z0-9_-]*)(=|\s+)([^,\s;#}]+)/\1\4REDACTED/Ig;
    s/((^|[\s,])-[pP])(\s+)([^-\s][^,\s;#}]*)/\1\3REDACTED/g;
  ' "$f" || true
  rm -f "$f.bak"
}

# ---------- run ----------
mkdir -p "$DST"
: > "$REPORT"

section "Run"
say "Creating sanitized copy at: $DST"
say "Reporting each item as: [kind] file:line: masked preview"
say "XML via xmlstarlet/Python fallback; public IPs allowlisted: 1.1.1.1, 8.8.8.8"
say_dbg "Copying tree -> $DST (excluding scripts/internal)…"
rsync -a "${RSYNC_EXCLUDES[@]}" "$SRC/" "$DST/"

# Walk copied tree: report first (line numbers match), then sanitize
while IFS= read -r -d '' f; do
  [[ "$f" == *"/SANITIZE-REPORT-"* ]] && continue
  is_text "$f" || { say_dbg "Skipping binary: $f"; continue; }
  say_dbg "Processing: $f"

  scan_report_before_edit "$f"

  case "$f" in
    *.xml)
      sanitize_xml_inplace "$f"
      sanitize_uuid_inplace "$f"
      if [[ "$MASK_IPS_IN_XML" == "true" ]]; then
        mask_public_ips_inplace "$f"
      else
        say_dbg "Skipping IP masking in XML (MASK_IPS_IN_XML=false)"
      fi
      ;;
    *.conf|*.cfg|*.json|*.yaml|*.yml|*/hosts|*/hostname|*/interfaces|*/grub|*/modules|*/datacenter.cfg|*/user.cfg|*/vzdump.conf)
      sanitize_kv_like_inplace "$f"
      sanitize_uuid_inplace "$f"
      mask_public_ips_inplace "$f"
      ;;
    *)
      sanitize_uuid_inplace "$f"
      mask_public_ips_inplace "$f"
      ;;
  esac
done < <(find "$DST" -type f -print0)

chmod -R go-rwx "$DST" || true
cleanup_temps

section "Summary"
say "Output directory: $DST"
say "Report:           $REPORT"
say_dbg "Sanitized copy created in $DST"
say_dbg "Report written to $REPORT"
