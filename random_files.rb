#!/usr/bin/env ruby

#=============================================================================
#
# random_files.rb
# ---------------
#
# In a target directory, create symbolic links to a given number of
# randomly selected files in any number of source directories.
#
# Link filenames may be the basename() of the source file; the full path
# of the source file with slashes changed to dashes (to avoid
# collisions); the MD5 sum of the full path; or a sequence of numbers.
#
# The user can use -N and -O options to control find(1)'s -mtime
# parameter, and can select any number of filename extensions to match
# using the -e flag.  It is also possible to filter on filename using
# find(1)'s -name option.  For instance, to link to files whose name
# contains the string 'mars', use -r '"*mars*"'.
#
# Run with -h for usage.
#
# Works with ruby-1.9, requires nothing non-core.
#
# R Fisher 12/2012
#
#=============================================================================

require "optparse"
require "open3"
require "pathname"

#-----------------------------------------------------------------------------
# VARIABLES

# Default options. :number is the number of files to link if we don't
# get '-n'

options = {
  :number => 10, :target => false, :extensions => false,
  :timeo => false, :timen => false, :filter => false, :rm => false,
  :namescheme => "copy", :verbose => false, :debug => false
}

$seq_count = 1
  # used as a counter to sequentially number links

format_count = 0
  # used to count how many format specifying options the user tries to pass


#-----------------------------------------------------------------------------
# FUNCTIONS

def random_indices(elements, want)
  #
  # Pick random indices out of an array. Call it with the number of
  # elements you have in the array, and the numer of random indices you
  # want.
  #
  # If we're asked for more than we have or all that we have, return a
  # range which describes the whole array.
  #
  if want >= elements
    out_list = 0..elements
  else
    out_list = []

    while out_list.size < want
      candidate = rand(elements)
      out_list << candidate unless out_list.include?(candidate)
    end

  end

  out_list
end


def make_link(src_file, target, options)
  #
  # Actually do the linking. Generate the proper file paths first.  We
  # may want to convert slashes to dashes. If we do that, strip off the
  # leading one, becuase no one likes filenames beginning with -
  #
  case options[:namescheme]

  when "obscure"
    dest_fname = Digest::MD5.hexdigest(src_file.to_s) + File.extname(src_file)
  when "expand"
    dest_fname = src_file.gsub("/", "-").slice(1..-1)
  when "seq"
    dest_fname = "%04d" % $seq_count + File.extname(src_file)
    $seq_count += 1
  else
    dest_fname = File.basename(src_file)
  end

  dest_file = Pathname(target) + dest_fname

  if dest_file.exist?
    STDERR.puts("WARNING: #{dest_file} exists")
  else
    puts(src_file + " -> " + dest_file) if options[:debug]
    File.symlink(src_file, dest_file)
  end

end

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# There are quite a lot of options, but it's easy to get them with Ruby

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} " +
                "[-neONrRxsSvDh] -d target dir..."

  # The number of random files to select and link
  #
  opts.on("-n", "--number N",
      "link to N random files (default is #{options[:number]})") do |n|
    options[:number] = n
  end

  # Where to create the symbolic links. Must exist and be writable
  #
  opts.on("-d", "--dir DIRECTORY", "put symlinks in DIRECTORY") do |dir|
    options[:target] = dir
  end

  # A comma-separated list of file extensions to allow linkage of
  #
  opts.on("-e", "--ext ext1,ext2..",
      "only link to files with these extensions") do |extlist|
    options[:extlist] = extlist.split(",")
  end

  # Filter on file age (as arguments to find(1))
  #
  opts.on("-O", "--older N", "only link to files older than N days") do |n|
    options[:timeo] = n
  end

  opts.on("-N", "--newer N", "only link to files newer than N days") do |n|
    options[:timen] = n
  end

  # Filter on filename pattern
  #
  opts.on("-r", "--regex REGEX", "only link to files matching REGEX") do |rx|
    options[:regex] = rx
  end

  # Remove existing symlinks in target directory
  #
  opts.on("-R", "--remove", "remove symlinks in target directory") do
    options[:rm] = true
  end

  # How to name the links. Default is "copy", which just uses the same name as
  # the target
  #
  opts.on("-x", "--expand", "link filenames are dir-file.ext") do
    options[:namescheme] = "expand"
    format_count += 1
  end

  opts.on("-s", "--sequence", "link filenames are numbered 000x.ext") do
    options[:namescheme] = "seq"
    format_count += 1
  end

  opts.on("-X", "--obscure", "link filenames are MD5 hashes") do
    require "digest/md5"
    options[:namescheme] = "obscure"
    format_count += 1
  end

  opts.on("-v", "--verbose", "be verbose") { options[:verbose] = true }
  opts.on("-D", "--debug", "show debug info") { options[:debug] = true }

  opts.on("-h", "--help", "show this information") do
    puts opts
    exit 0
  end

end

optparse.parse!

# Let's do some sanity checking. We need at least one directory to search

abort("ERROR: require at least one directory") if ARGV.length == 0

# -x, -X, -s are exclusive. Make sure we have at most one of them

abort "ERROR: -x, -X, and -s are exclusive" if format_count > 1

# Check the target directory. We need to have one supplied, and it must be
# writable

abort "ERROR: require a target directory [-d]" unless options[:target]

target = Pathname(options[:target])

unless target.exist? && target.directory? && target.writable?
  puts target.to_s + " does not exist or is not a writable directory"
  exit 1
end

target = target.realpath

puts("Creating links in #{target}") if options[:verbose]

# Are we removing files? We only removing symbolic links, which is a
# rough stab at removing what this script might have created on previous
# runs.

if options[:rm]
  puts("Removing existing links") if options[:verbose]

  Dir.foreach(target) do |file|
    rmfile = target + file
    File.unlink(rmfile) if rmfile.symlink?
  end

end

# Process the options to build up a find(1) command which will be used
# to generate a list of all the files from which we will choose our
# randoms.

dirlist, findargs = ARGV.join(" "), "-type f"

if options[:extlist]
  findargs << ' -a \(-name \\*.' + extlist.shift()
  extlist.each {|ext| findargs << ' -o -name \\*.' + ext }
  findargs << "\)"
end

# Time options

findargs << " -a -mtime +" + options[:timeo] if options[:timeo]
findargs << " -a -mtime -" + options[:timen] if options[:timen]

# Regex options

findargs << " -a -name " + options[:regex] if options[:regex]

# Run the command, saying what it is if we're being verbose

puts "running 'find #{dirlist} #{findargs}'" if (options[:verbose])

stdout, stderr, status = Open3.capture3(
	"/usr/bin/find #{dirlist} #{findargs}")

# If find didn't give us anything, exit without raising an error

if status.exitstatus != 0
	abort("find exited #{status.exitstatus}.\nstderr: #{stderr}")
end

f_arr = stdout.split("\n")

if f_arr.size == 0
	puts "no files matched" if options[:verbose]
	exit 0
end

# Now go through the list getting the real values

if options[:verbose]
  puts "Linking #{options[:number]} of #{f_arr.size} candidate files"
end

if options[:number].to_i > f_arr.size
  puts "WARNING: asked to link more files than we have"
end

# We have all the files we might wish to link to in the f_arr[] array.
# Randomly pick as many indices from that array as we want, then link
# the files into the target directory.

random_indices(f_arr.size, options[:number].to_i).each do |el|
  pth = Pathname(f_arr[el]).realpath
  make_link(pth, target, options) if f_arr[el]
end

# All done
