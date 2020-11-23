import streams
import strutils,os
import ibApi


for kind, path in walkDir("data"):
  echo(path)