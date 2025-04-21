#!/bin/sh

git show --pretty=format: --unified=0 | grep '^+[^+]' | sed -e 's/^+//' -e 's/::.*//' | awk '{print NR ": " $0}'
