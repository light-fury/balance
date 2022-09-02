#!/bin/bash

for ((i=0; i < 350; i++)); do
  echo "Doing $i"
  cat ./balance-pass_meta-prereveal/template.json | sed "s/#/#$i/g" > "./balance-pass_meta-prereveal/$i.json"
done