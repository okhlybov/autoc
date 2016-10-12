#!/bin/bash

set -e

asciidoctor index.asciidoc

scp index.html fougas@web.sf.net:/home/project-web/autoc/htdocs

#