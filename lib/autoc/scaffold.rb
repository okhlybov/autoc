# frozen_string_literal: true

# These methods are meant to be used by the one-liners: ruby -r autoc/scaffold -e tests

# Generate generated interface reference header to processable with Doxygen
def docs = require_relative 'scaffold/docs'

# Generated test suite
def tests = require_relative 'scaffold/tests'

# Generate skeleton project
def project = require_relative 'scaffold/project'