#!/usr/bin/env ruby
#
#=============================================================================
#
# time_from_epoch.rb
# ------------------
#
# Feed it epoch times and it prints the corresponding system time.
# Because Sensu prints times as seconds since the epoch.
#
# R Fisher 12/2013
#
#=============================================================================

require 'date'

abort "ERROR: no timestamp(s) given" if ARGV.length == 0

ARGV.each do |t|

  if t.match(/^\d+$/)
    puts DateTime.strptime(t, "%s")
  else
    puts "skipping #{t}"
  end

end
