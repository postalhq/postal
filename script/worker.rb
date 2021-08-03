#!/usr/bin/env ruby
require_relative "../config/environment"
Postal::Worker.new([:main]).work
