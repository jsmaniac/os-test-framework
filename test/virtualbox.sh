#!/bin/sh
set -e

if test $# -ne 1 || test "$1" = '-h' -o "$1" = '--help'; then
    echo "Usage: $0 operating_system_file"
fi
os_filename="$1"

vbox_dir="$(./utils/mktemp.sh -d)"
vmname="automatic-os-test-$(date +%s)-$$"

ln -sf "$(./utils/absolute-path.sh "$os_filename")" "build/virtualbox.img"
VBoxManage createvm --name "$vmname" --register --basefolder "$vbox_dir"
VBoxManage modifyvm "$vmname" --hwvirtex off
VBoxManage modifyvm "$vmname" --nestedpaging off
VBoxManage modifyvm "$vmname" --pae off
VBoxManage storagectl "$vmname" --name 'floppy disk drive' --add floppy --bootable on
VBoxManage storageattach "$vmname" --storagectl 'floppy disk drive' --port 0 --device 0 --type fdd --medium "build/virtualbox.img"
VBoxManage modifyvm "$vmname" --boot1 floppy
VBoxManage startvm "$vmname" --type sdl &
pid=$!
runsikulix -r test/check-gradient.sikuli && exitcode=$? || exitcode=$?

./utils/take-screenshots.sh "./deploy-screenshots/$(basename "$0" .sh).png"

VBoxManage controlvm "$vmname" poweroff
wait $pid
# TODO: should ensure that the cleanup phase is always done even if the test fails.
for i in `seq 10`; do
    if VBoxManage unregistervm "$vmname" --delete; then
        break
    fi
    sleep 0.1
done

# Cleanup: remove temporary files and directories.
rm "/tmp/$vbox_dir" -fr

exit $exitcode
