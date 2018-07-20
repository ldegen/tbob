#!/bin/bash

# Note: run this from the project root directory

node_modules/.bin/coffee src/main.coffee -w examples/issue-13/world/ -f sexp -d '(AdresseES)'
