# typed: strict
addpath = ->(p) do
  path = File.expand_path("../../#{p}", __FILE__)
  $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
end
addpath.call('lib')

require('rubygems')
require('bundler/setup')

require('minitest/autorun')
require('minitest/unit')
require('mocha/minitest')
