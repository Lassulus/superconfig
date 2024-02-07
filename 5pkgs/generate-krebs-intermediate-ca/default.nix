{ pkgs }:
pkgs.writers.writeDashBin "generate-intermediate-ca" ''
  TMPDIR=$(mktemp -d)
  trap "rm -rf $TMPDIR;" INT TERM EXIT
  mkdir -p "$TMPDIR/krebs"
  pass show brain/ca/ca.key > "$TMPDIR/krebs/ca.key"
  pass show brain/ca/ca.crt > "$TMPDIR/krebs/ca.crt"
  export STEPPATH="$TMPDIR/step"
  cat << EOF > "$TMPDIR/intermediate.tpl"
  {
      "subject": {{ toJson .Subject }},
      "keyUsage": ["certSign", "crlSign"],
      "basicConstraints": {
          "isCA": true,
          "maxPathLen": 0
      },
      "nameConstraints": {
          "critical": true,
          "permittedDNSDomains": ["r" ,"w"]
      }
  }
  EOF

  ${pkgs.step-cli}/bin/step certificate create "Krebs ACME CA" intermediate_ca.crt intermediate_ca.key \
    --template "$TMPDIR/intermediate.tpl" \
    --not-after 8760h \
    --ca "$TMPDIR/krebs/ca.crt" \
    --ca-key "$TMPDIR/krebs/ca.key" \
    --no-password --insecure
''
