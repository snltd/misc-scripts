#!/opt/td-agent/embedded/bin/ruby

# Shovel random crap into syslog at some (slightly inaccurate) rate.
#
require 'syslog'

if ARGV.length != 2
  abort "usage: #{File.basename($0)} message_rate duration"
end

PRIS = %w(LOG_EMERG LOG_ALERT LOG_CRIT LOG_ERR LOG_WARNING LOG_NOTICE
          LOG_INFO)

FACS = %w(LOG_AUTH LOG_AUTHPRIV LOG_CRON LOG_DAEMON LOG_FTP LOG_KERN
          LOG_LPR LOG_MAIL LOG_NEWS LOG_SYSLOG LOG_USER LOG_UUCP
          LOG_LOCAL0 LOG_LOCAL1 LOG_LOCAL2 LOG_LOCAL3 LOG_LOCAL4
          LOG_LOCAL5 LOG_LOCAL6 LOG_LOCAL7)

class Syslogger
  attr_reader :words, :syslog, :rate, :duration

  def initialize(rate = 100, duration = 1)
    @words = IO.read('./words').split("\n")
    @rate = rate
    @duration = duration
    puts "write #{rate} messages/s for #{duration} sec"
  end

  def syslog
    Syslog.open(words.sample, Syslog::LOG_NDELAY,
                Kernel.const_get("Syslog::#{FACS.sample}"))
  end

  def gen_msg
    ret = []
    rand(10).times { ret.<<  words.sample }
    ret.join(' ')
  end

  def write_msg
    puts "writing message"
    s = syslog
    s.log(Kernel.const_get("Syslog::#{PRIS.sample}"), gen_msg)
    s.close
  end

  def write_msgs
    sleep_time = (1.0 / rate) -  0.000295
    sent_msgs = 0

    if duration > 0
      1.upto(duration * rate) do
        write_msg
        sent_msgs += 1
        sleep sleep_time
      end

    else
      while true do
        write_msg
        sent_msgs += 1
        sleep sleep_time
      end
    end

    puts "sent #{sent_msgs} messages"
  end
end

sl = Syslogger.new(ARGV[0].to_i, ARGV[1].to_i)
sl.write_msgs
