{ writers }:

#usage: ping 8.8.8.8 |& logify -I
writers.writeDashBin "logify" ''
  date_args=''${@:--Is}
  while read line; do echo $(date "$date_args") $line; done
''
