#!/bin/sh

# d8 is a tool included with V8:
# https://code.google.com/p/v8/

d8 bench.js Tracer.js benchmark_tracer.js
