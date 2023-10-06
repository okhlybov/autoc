# frozen_string_literal: true


require 'autoc/record'


GlassRecord = AutoC::Record.new(:GlassRecord, { i: :int }, profile: :glassbox, visibility: :public)
