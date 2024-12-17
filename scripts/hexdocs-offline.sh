#!/bin/bash

gleam run -m hexdocs_offline
mv HEXDOCS.html docs/hexdocs.html
