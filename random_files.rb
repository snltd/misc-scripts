#!/usr/bin/env ruby

#=============================================================================
#
# random_files.rb
# ---------------
#
# In a target directory, create symbolic links to a given number of randomly
# selected files in any number of source directories.
#
# Link filenames may be the basename() of the source file; the full path of the
# source file with slashes changed to dashes (to avoid collisions); the MD5 sum
# of the full path; or a sequence of numbers.
#
# The user can use -N and -O options to control find(1)'s -mtime parameter, and
# can select any number of filename extensions to match using the -e flag.
# It is also possible to filter on filename using find(1)'s -name option.
# For instance, to link to files whose name contains the string 'mars', use
# -r '"*mars*"'.
#
# Run with -h for usage.
#
# Works with ruby-1.9, requires nothing non-core.
#
# R Fisher 12/2012
#
#=============================================================================

#-----------------------------------------------------------------------------
# VARIABLES

defnum = 10
	# How many files to link if user doesn't give -n

findargs = '-type f'
options = {}
	# These will be added to later

$seq_count = 1
	# used as a counter to sequentially number links

format_count = 0
	# used to count how many format specifying options the user tries to pass

#-----------------------------------------------------------------------------
# FUNCTIONS

def gen_random_list(elements, total)

	# Get a unique list of array elements, of the size we require. Called with
	# the size of the array, and the number of elements to return

	# If we're asked for more than we have or all that we have, return
	# everything

	if total >= elements
		out_list = 0..elements
	else
		out_list = []

		while out_list.size < total
			candidate = rand(elements)

			unless out_list.include?(candidate)
				out_list.push(candidate)
			end

		end

	end

	return out_list
end

def make_link(src_file, target, options)

	# Actually do the linking. Generate the proper file paths first.  We may
	# want to convert slashes to dashes. If we do that, strip off the leading
	# one, becuase no one likes filenames beginning with -

	case options[:namescheme]

		when 'obscure'
			dest_fname = Digest::MD5.hexdigest(src_file) + File.extname(src_file)

		when 'expand'
			dest_fname = src_file.gsub('/', '-').slice(1..-1)

		when 'seq'
			dest_fname = "%04d" % $seq_count + File.extname(src_file)
			$seq_count += 1

		else
			dest_fname = File.basename(src_file)

	end

	dest_file = File.join(target, dest_fname)

	if (File.exists?(dest_file))
		STDERR.puts("WARNING: #{dest_file} exists")
	else
		puts("#{src_file} -> #{dest_file}") if options[:debug]
		File.symlink(src_file, dest_file)
	end

end

#-----------------------------------------------------------------------------
# SCRIPT STARTS HERE

# There are quite a lot of options, but it's easy to get them with Ruby

require 'optparse'

optparse = OptionParser.new do |opts|
	opts.banner = "Usage: #{File.basename(__FILE__)} [options] dir dir ..."

	# The number of random files to select and link
	#
	options[:number] = defnum
	opts.on('-n', '--number N',
			"link to N random files (default is #{defnum})") do |n|
		options[:number] = n
	end

	# Where to create the symbolic links. Must exist and be writable
	#
	options[:target] = false
	opts.on('-d', '--dir DIRECTORY', 'put symlinks in DIRECTORY') do |dir|
		options[:target] = dir
	end

	# A comma-separated list of file extensions to allow linkage of
	#
	options[:extensions] = false
	opts.on('-e', '--ext ext1,ext2..', 
			'only link to files with these extensions') do |extlist|
		options[:extlist] = extlist
	end

	# Filter on file age (as arguments to find(1))
	#
	options[:timeo] = options[:timen] = false
	opts.on('-O', '--older N', 'only link to files older than N days') do |n|
		options[:timeo] = n
	end

	opts.on('-N', '--newer N', 'only link to files newer than N days') do |n|
		options[:timen] = n
	end

	# Filter on filename pattern
	#
	options[:filter] = false
	opts.on('-r', '--regex REGEX', 
	'only link to files whose names contain this pattern') do |regex|
		options[:regex] = regex
	end

	# Remove existing symlinks in target directory
	#
	options[:rm] = false
	opts.on('-R', '--remove', 'remove symlinks in target directory') do
		options[:rm] = true
	end

	# How to name the links. Default is "copy", which just uses the same name as
	# the target
	#
	options[:namescheme] = 'copy'
	opts.on('-x', '--expand', 'link filenames are dir-file.ext') do
		options[:namescheme] = 'expand'
		format_count += 1
	end

	opts.on('-s', '--sequence', 'link filenames are numbered 000x.ext') do
		options[:namescheme] = 'seq'
		format_count += 1
	end

	opts.on('-X', '--obscure', 'link filenames are MD5 hashes') do
		options[:namescheme] = 'obscure'
		format_count += 1
		require 'digest/md5'
	end

	# Be verbose
	#
	options[:verbose] = options[:debug] = false
	opts.on('-v', '--verbose', 'be verbose') { options[:verbose] = true }
	opts.on('-D', '--debug', 'show debug info') { options[:debug] = true }

	# Help!
	#
	opts.on('-h', '--help', 'show this information') do
		puts opts
		exit 0
	end

end

optparse.parse!

# Let's do some sanity checking. We need at least one directory to search

if ARGV.length == 0
	STDERR.puts 'ERROR: require at least one directory'
	exit 1
end

# -x, -X, -s are exclusive. Make sure we have at most one of them

if format_count > 1
	STDERR.puts 'ERROR: -x, -X, and -s are exclusive'
	exit 2
end

# Check the target directory. We need to have one supplied, and it must be
# writable

unless options[:target]
	STDERR.puts 'ERROR: require a target directory [-d]'
	exit 1
end

target = options[:target]

unless File.exists?(target) && File.directory?(target) && File.writable?(target)
	STDERR.puts "ERROR: #{target} does not exist or is not a writable directory"
	exit 1
end

target = File.absolute_path(target)

puts("Creating links in #{target}") if options[:verbose]

# Are we removing files? We only removing symbolic links, which is a rough stab
# at removing what this script might have created on previous runs

if options[:rm]
	puts('Removing existing links') if options[:verbose]

	Dir.foreach(target) do |file|
		rmfile = File.join(target, file)
		File.unlink(rmfile) if File.symlink?(rmfile)
	end

end

dirlist = ARGV.join(' ')

# Expand the -e options into a string that find(1) understands

if options[:extlist]
	extarr = options[:extlist].split(',')
	findargs += ' -a -name \\*.' + extarr.shift()

	extarr.each do |ext|
		findargs += ' -o -name \\*.' + ext
	end

end

# Time options

findargs += ' -a -mtime +' + options[:timeo] if options[:timeo] 
findargs += ' -a -mtime -' + options[:timen] if options[:timen] 

# Regex options

findargs += ' -a -name ' + options[:regex] if options[:regex]

# Run the command, saying what it is if we're being verbose

puts "running 'find #{dirlist} #{findargs}'" if (options[:verbose])
f_arr = %x(find #{dirlist} #{findargs} 2>/dev/null).split("\n");

# If find didn't give us anything, exit without raising an error

exit 0 if f_arr.size == 0

# Now go through the list getting the real values

if options[:verbose]
	puts "Linking #{options[:number]} of #{String(f_arr.size)} candidate files" 
end

# Now go through the array of candidate files, and create a symbolic link for
# each one

gen_random_list(f_arr.size, Integer(options[:number])).each do |el|
	make_link(File.absolute_path(f_arr[el]), target, options) if f_arr[el]
end

# All done
