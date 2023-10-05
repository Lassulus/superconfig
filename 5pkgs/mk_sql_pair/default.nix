{ pkgs, ... }:

pkgs.writeScriptBin "mk_sql_pair" ''
  #!/bin/sh

  name=$1
  password=$2

  if [ $# -ne 2 ]; then
    echo '$1=name, $2=password'
    exit 23;
  fi

  cat <<EOF
  create database $name;
  create user $name;
  grant all on $name.* to $name@'localhost' identified by '$password';
  EOF
''
