MAKEFLAGS = --warn-undefined-variables
SHELL = bash -euET -o pipefail -c
.SECONDEXPANSION:

os_filename = os.bat
tests_emu = test/qemu-system-i386-floppy test/qemu-system-i386-cdrom test/qemu-system-arm test/virtualbox test/bochs test/gui-sh test/dosbox
tests_requiring_sudo = test/fat12_mount test/iso_mount
tests_noemu = test/zip test/os.reasm test/sizes test/fat12_contents

offset_names = bytes_os_size \
               bytes_mbr_start \
               bytes_mbr_end \
               bytes_header_32k_start \
               bytes_header_32k_end \
               bytes_iso_start \
               bytes_iso_end \
               bytes_fat12_start \
               bytes_fat12_end \
               bytes_gpt_mirror_start \
               bytes_gpt_mirror_end \
               bytes_zip_start \
               bytes_zip_end

more_offset_names = ${offset_names} \
                    bytes_fat12_size \
                    bytes_gpt_mirror_size \
                    bytes_header_32k_size \
                    bytes_iso_size \
                    bytes_zip_size \
                    sectors_fat12_size \
                    sectors_fat12_start \
                    sectors_gpt_mirror_size \
                    sectors_iso_size \
                    sectors_os_size \
                    sectors_zip_size \
                    tracks_fat12_size \
                    tracks_gpt_mirror_size \
                    tracks_iso_size \
                    tracks_os_size \
                    tracks_zip_size

more_offset_dec = ${more_offset_names:%=build/offsets/%.dec}
more_offset_hex = ${more_offset_names:%=build/offsets/%.hex}

# + os.arm.disasm
# + os.reasm.disasm
built_files = ${os_filename} \
              build/check_makefile \
              build/check_makefile_targets \
              build/check_makefile_w_arnings \
              build/makefile_built_directories \
              build/makefile_built_files \
              build/makefile_database \
              build/makefile_database_files \
              build/makefile_file_targets \
              build/makefile_non_file_targets \
              build/makefile_phony \
              build/makefile_targets \
              build/makefile_w_arnings \
              build/os.ndisasm.disasm \
              build/os.reasm.asm \
              build/os.reasm \
              build/os.file \
              build/os.fdisk \
              build/os.zip \
              build/os.zip.adjusted \
              build/os.iso \
              build/os.32k \
              build/os.fat12 \
              build/os.offsets \
              build/os.hex_with_offsets \
              build/iso_files/os.zip \
              build/iso_files/boot/iso_boot.sys \
              ${more_offset_dec} \
              ${more_offset_hex} \
              ${tests_emu:test/%=build/test_pass/emu_%} \
              ${tests_noemu:test/%=build/test_pass/noemu_%} \
              ${tests_requiring_sudo:test/%=build/test_pass/sudo_%} \
              ${tests_emu:test/%=deploy-screenshots/%.png} \
              ${tests_emu:test/%=deploy-screenshots/%-anim.gif}

built_directories = build/iso_files/boot build/iso_files build/offsets build/mnt_fat12 build/mnt_iso build/test_pass deploy-screenshots
more_built_directories = ${built_directories} build

os_image_size_kb = 1440
os_partition_start_sectors = 3
os_partition_size_sectors = 717 # 720 - start
# CHS parameters for 1.44 MB floppy disk
os_floppy_chs_h = 2
os_floppy_chs_s = 9

.PHONY: all
# all: os.arm.disasm
all: ${os_filename} build/os.ndisasm.disasm build/os.reasm.asm build/os.file build/os.fdisk build/os.offsets build/os.hex_with_offsets .gitignore build/check_makefile ${more_offset_dec} ${more_offset_hex}

build/makefile_w_arnings: | $${@D}
${built_files}: | $${@D}

build/makefile_w_arnings: Makefile
	@make -n --warn-undefined-variables test 2>$@ 1>/dev/null || make -n --warn-undefined-variables test

# Check that the file build/makefile_w_arnings is present, and that it does not contain the string "warn".
build/check_makefile_w_arnings: build/makefile_w_arnings
	@cat build/makefile_w_arnings > /dev/null && (! grep -i warn $<) && touch $@

# Check that the declared list of built files matches the list of targets extracted from the Makefile.
build/check_makefile_targets: build/makefile_built_files build/makefile_file_targets build/check_makefile_w_arnings
	@diff build/makefile_built_files build/makefile_file_targets && touch $@

build/check_makefile: build/check_makefile_w_arnings build/check_makefile_targets
	@touch $@

build/makefile_database: Makefile build/check_makefile_w_arnings
	@make -rpn | sed -n -e '/^# Make data base,/,$$p' > $@

build/makefile_database_files: build/makefile_database build/check_makefile_w_arnings
	@sed -n -e '/^# Files$$/,/^# files hash-table stats:$$/p' $< > $@

build/makefile_built_directories: build/check_makefile_w_arnings
	@echo ${more_built_directories} | tr ' ' '\n' | grep -v '^\s*$$' | sort > $@

build/makefile_built_files: build/check_makefile_w_arnings
	@echo ${built_files} | tr ' ' '\n' | grep -v '^\s*$$' | sort > $@

build/makefile_phony: build/makefile_database_files build/check_makefile_w_arnings
	@sed -r -n -e 's/^.PHONY: (.*)$$/\1/p' $< | tr ' ' '\n' | grep -v '^\s*$$' | sort > $@

build/makefile_targets: build/makefile_database_files build/check_makefile_w_arnings
	@grep -E -v '^(\s|#|\.|$$|^[^:]*:$$)' $< | grep '^[^ :]*:' | sed -r -e 's|^([^:]*):.*$$|\1|' | sort > $@

build/makefile_non_file_targets: build/makefile_phony build/makefile_built_directories build/check_makefile_w_arnings
	@cat build/makefile_phony build/makefile_built_directories | sort > $@

build/makefile_file_targets: build/makefile_non_file_targets build/makefile_targets build/check_makefile_w_arnings
	@comm -23 build/makefile_targets build/makefile_non_file_targets > $@

${built_directories}: build/check_makefile
${more_built_directories}: Makefile
	mkdir -p $@ && touch $@

# 32k header of the ISO9660 image
build/os.32k: example-os/os.asm build/check_makefile
	nasm -o $@ $<

build/os.iso: build/iso_files/os.zip build/iso_files/boot/iso_boot.sys build/check_makefile
	mkisofs \
	 --input-charset utf-8 \
	 -rock \
	 -joliet \
	 -eltorito-catalog boot/boot.cat \
	 -eltorito-boot boot/iso_boot.sys \
	 -no-emul-boot \
	 -boot-load-size 4 \
	 -pad \
	 -output $@ \
	 ./build/iso_files/

# Layout:
# MBR; GPT; UNIX sh & MS-DOS batch scripts; ISO9660; FAT12; GPT mirror; ZIP

define offset
tmp_${1} = ${3}
build/offsets/${1}.dec: $${tmp_${1}:%=build/offsets/%.dec} build/check_makefile
	echo $$$$(( ${2} )) > $$@
${1} = $$$$(cat build/offsets/${1}.dec)
dep_${1} = build/offsets/${1}.dec
endef

define div_round_up
( ( ( ${1} ) + ( ${2} ) - 1 ) / ( ${2} ) )
endef

sector_size = 512
# should be exact (TODO: make a check)
${eval ${call offset,bytes_os_size,     $${os_image_size_kb} * 1024,,                                 }}
${eval ${call offset,sectors_os_size,   $${bytes_os_size}    / $${sector_size},                        bytes_os_size,}}
${eval ${call offset,tracks_os_size,    $${sectors_os_size}  / $${os_floppy_chs_s},                    sectors_os_size,}}

# round up
${eval ${call offset,bytes_iso_size,    $$$$(wc -c build/os.iso | cut -d ' ' -f 1),                    ,build/os.iso}}
${eval ${call offset,sectors_iso_size,  ${call div_round_up,$${bytes_iso_size},$${sector_size}},       bytes_iso_size,}}
${eval ${call offset,tracks_iso_size,   ${call div_round_up,$${sectors_iso_size},$${os_floppy_chs_s}}, sectors_iso_size,}}

# round up
${eval ${call offset,bytes_zip_size,    $$$$(wc -c build/os.zip | cut -d ' ' -f 1),                    ,build/os.zip}}
${eval ${call offset,sectors_zip_size,  ${call div_round_up,$${bytes_zip_size},$${sector_size}},       bytes_zip_size,}}
${eval ${call offset,tracks_zip_size,   ${call div_round_up,$${sectors_zip_size},$${os_floppy_chs_s}}, sectors_zip_size,}}

# round up
${eval ${call offset,sectors_gpt_mirror_size, 33,,                                                   }}
${eval ${call offset,tracks_gpt_mirror_size,  ${call div_round_up,$${sectors_gpt_mirror_size},$${os_floppy_chs_s}}, sectors_gpt_mirror_size,}}

# allocate the remaining sectors to the FAT, aligned on tracks
${eval ${call offset,tracks_fat12_size, $${tracks_os_size} - $${tracks_iso_size} - $${tracks_gpt_mirror_size} - $${tracks_zip_size}, tracks_os_size tracks_iso_size tracks_gpt_mirror_size tracks_zip_size,}}
${eval ${call offset,sectors_fat12_size,$${tracks_fat12_size} * $${os_floppy_chs_s},                   tracks_fat12_size,}}

# zip should probably have its end aligned, not its start
${eval ${call offset,bytes_zip_start,   $${bytes_os_size} - $${bytes_zip_size},                        bytes_os_size bytes_zip_size,}}

${eval ${call offset,bytes_mbr_start,        0,,}}
${eval ${call offset,bytes_mbr_end,          512,,}}
${eval ${call offset,bytes_header_32k_start, 0,,}}
${eval ${call offset,bytes_header_32k_end,   32 * 1024,,}}
${eval ${call offset,bytes_header_32k_size,  $${bytes_header_32k_end} - $${bytes_header_32k_start},      bytes_header_32k_end bytes_header_32k_start,}}
${eval ${call offset,bytes_iso_start,        32 * 1024,,}}
${eval ${call offset,bytes_iso_end,          $${sectors_iso_size} * $${sector_size},                     sectors_iso_size,}}
${eval ${call offset,bytes_fat12_start,      $${tracks_iso_size} * $${os_floppy_chs_s} * $${sector_size}, tracks_iso_size,}}
${eval ${call offset,sectors_fat12_start,    $${bytes_fat12_start} / $${sector_size},                    bytes_fat12_start,}}
${eval ${call offset,bytes_fat12_size,       $${sectors_fat12_size} * $${sector_size},                   sectors_fat12_size,}}
${eval ${call offset,bytes_fat12_end,        $${bytes_fat12_start} + $${bytes_fat12_size},               bytes_fat12_start bytes_fat12_size,}}
# It is probably not necessary to align the GPT mirror end on a track boundary.
${eval ${call offset,bytes_gpt_mirror_size,  $${sectors_gpt_mirror_size} + $${sector_size},              sectors_gpt_mirror_size,}}
${eval ${call offset,bytes_gpt_mirror_end,   $${bytes_fat12_end} + $${bytes_gpt_mirror_size},            bytes_fat12_end bytes_gpt_mirror_size,}}
${eval ${call offset,bytes_gpt_mirror_start, $${bytes_gpt_mirror_end} - $${bytes_gpt_mirror_size},       bytes_gpt_mirror_end bytes_gpt_mirror_size,}}
${eval ${call offset,bytes_zip_end,          $${bytes_os_size},,                                         }}

os_fat12_partition = "$@@@${bytes_fat12_start}"
build/os.fat12: build/os.zip ${dep_bytes_fat12_size} ${dep_bytes_fat12_start} ${dep_sectors_os_size} build/check_makefile
	set -x; dd if=/dev/zero bs=${sector_size} count=${sectors_os_size} of=$@
	set -x; mformat -v "Example OS" \
	 -T ${sectors_fat12_size} \
	 -h ${os_floppy_chs_h} \
	 -s ${os_floppy_chs_s} \
	 -i ${os_fat12_partition}
	set -x; mcopy -i ${os_fat12_partition} build/os.zip "::os.zip"

build/iso_files/os.zip: build/os.zip build/check_makefile
# TODO: make it so that the various file formats are mutual quines:
# * the ISO should contain the original file
# * the ZIP should contain the original file
# * the FAT12 should contain the original file
	cp $< $@

# 4 sectors loaded when booting from optical media (CD-ROM, …):
build/iso_files/boot/iso_boot.sys: build/os.32k build/check_makefile
# TODO: this copy of the (or alternate) bootsector should contain a Boot Information Table,
#       see https://wiki.osdev.org/El-Torito#A_BareBones_Boot_Image_with_Boot_Information_Table
	dd if=$< bs=512 count=4 of=$@

build/os.zip: build/os.32k build/check_makefile
	zip $@ $<

build/os.zip.adjusted: build/os.zip ${dep_bytes_zip_start} build/check_makefile
# TODO: the ZIP file can end with a variable-length comment, this would allow us to hide the GPT mirrors.
	set -x; dd if=/dev/zero bs=1 count=${bytes_zip_start} of=$@
	cat $< >> $@
	zip --adjust-sfx $@

${os_filename}: build/os.32k build/os.iso build/os.fat12 build/os.zip.adjusted \
                ${dep_bytes_header_32k_start} \
                ${dep_bytes_header_32k_size} \
                ${dep_bytes_fat12_start} \
                ${dep_bytes_fat12_size} \
                ${dep_bytes_gpt_mirror_end} \
                ${dep_sectors_fat12_start} \
                ${dep_sectors_fat12_size} \
                ${dep_bytes_zip_start} \
                build/check_makefile
	rm -f $@
# start with the .iso
	cp build/os.iso $@
# splice in the first 32k (bootsector and partition table)
	set -x; dd skip=${bytes_header_32k_start} seek=${bytes_header_32k_start} bs=1 count=${bytes_header_32k_size} conv=notrunc if=build/os.32k of=$@
# splice in fat12
	set -x; dd skip=${bytes_fat12_start} seek=${bytes_fat12_start} bs=1 count=${bytes_fat12_size} conv=notrunc if=build/os.fat12 of=$@
# pad with zeroes to prepare for GPT table
	set -x; dd if=/dev/zero seek=$$((${bytes_gpt_mirror_end} - 1 )) bs=1 count=1 conv=notrunc of=$@
# patch the partition table
	printf "p\nd\nn\np\n1\n${sectors_fat12_start}\n${sectors_fat12_size}\nt\n01\na\n1\np\nw\nq\n" | fdisk $@
# Thanks to https://wiki.gentoo.org/wiki/Hybrid_partition_table for showing that gdisk can be used to make a hybrid MBR / GPT.
# gdisk commands: recovery, make hybrid, add GPT partition #1 to the hybrid MBR, don't put the EFI partition first,
#                 partition type=0x01, bootable=Y, don't add extra partitions, print GPT, print MBR, write, proceed, quit.
	printf "r\nh\n1\nN\n01\nY\nN\np\no\nw\nY\nq\n" | gdisk $@
# splice in zip at the end
	set -x; dd skip=${bytes_zip_start} seek=${bytes_zip_start} bs=1 conv=notrunc if=build/os.zip.adjusted of=$@
	chmod a+x-w $@

build/os.file: ${os_filename} build/check_makefile
	file -kr $< > $@

build/os.fdisk: ${os_filename} build/check_makefile
	fdisk -l $< > $@

build/os.offsets: ${offset_names:%=build/offsets/%.hex} build/check_makefile
	cat ${offset_names:%=build/offsets/%.hex} > $@

build/offsets/%.hex: build/offsets/%.dec
	printf '%x\n' $$(cat $<) > $@

build/os.hex_with_offsets: ${os_filename} build/os.offsets
	hexdump -C $< \
	 | grep -E -e "($$(cat build/os.offsets | cut -d '=' -f 2 | sed -r -e 's/^\s*0x(.*).$$/^\10/' | tr '\n' '|')^)" --color=yes > $@

build/os.ndisasm.disasm: ${os_filename} utils/compact-ndisasm.sh build/check_makefile
	./utils/compact-ndisasm.sh $< $@

build/os.reasm.asm: build/os.ndisasm.disasm build/check_makefile
	sed -r -e 's/^[^ ]+ +[^ ]+ +//' $< > $@

build/test_pass/noemu_%.reasm build/%.reasm: build/%.reasm.asm ${os_filename} utils/compact-ndisasm.sh build/check_makefile
# For now ignore this test, since we cannot have a reliable re-assembly of arbitrary data.
	touch build/test_pass/noemu_$*.reasm build/$*.reasm
#	nasm $< -o $@
#	@echo "diff $@ ${os_filename}"
#	@diff $@ ${os_filename} \
#         && echo "[1;32mRe-assembled file is identical to ${os_filename}[m" \
#         || (./utils/compact-ndisasm.sh $@ build/os.reasm.disasm; \
#	     echo "[0;33mRe-assembled file is different from ${os_filename}. Use meld build/os.ndisasm.disasm build/os.reasm.disasm to see differences.[m"; \
#	     exit 0)

#os.arm.disasm: ${os_filename} build/check_makefile
#	arm-none-eabi-objdump --endian=little -marm -b binary -D --adjust-vma=0x8000 $< > $@

.PHONY: clean
clean: build/check_makefile
	rm -f ${built_files}
	for d in $$(echo ${more_built_directories} | tr ' ' '\n' | sort --reverse); do \
          if test -e "$$d"; then \
            rmdir "$$d"; \
          fi; \
        done

.gitignore: build/check_makefile
	for f in ${built_files}; do echo "/$$f"; done | sort > $@

.PHONY: test
test: ${tests_emu:test/%=build/test_pass/emu_%} \
      ${tests_noemu:test/%=build/test_pass/noemu_%} \
      ${tests_requiring_sudo:test/%=build/test_pass/sudo_%} \
      all \
      build/check_makefile

.PHONY: ${tests_emu}
${tests_emu}: build/test_pass/emu_$$(@F)

build/test_pass/emu_% deploy-screenshots/%.png deploy-screenshots/%-anim.gif: \
 ${os_filename} utils/gui-wrapper.sh test/%.sh build/check_makefile \
 | build/test_pass deploy-screenshots
	./utils/gui-wrapper.sh 800x600x24 ./test/$*.sh $<
	touch build/test_pass/emu_$*

.PHONY: test/noemu
test/noemu: ${tests_noemu:test/%=build/test_pass/noemu_%} build/check_makefile

build/test_pass/noemu_zip: ${os_filename} build/check_makefile
	unzip -t ${os_filename}
	touch $@

build/test_pass/noemu_sizes: build/os.32k ${os_filename} build/check_makefile
	test "$$(wc -c build/os.32k)" = "$$((32*1024)) build/os.32k"
	test "$$(wc -c ${os_filename})" = "$$((1440*1024)) ${os_filename}"
	touch $@

# check that the fat filesystem has the correct contents
build/test_pass/noemu_fat12_contents: ${os_filename} ${dep_bytes_fat12_start} build/check_makefile
	mdir -i "$<@@${bytes_fat12_start}" :: | grep -E "^os\s+zip\s+"
	touch $@

.PHONY: test/requiring_sudo
test/requiring_sudo: ${tests_requiring_sudo:test/%=build/test_pass/sudo_%} build/check_makefile

# check that the fat filesystem can be mounted and has the correct contents
build/test_pass/sudo_fat12_mount: ${os_filename} ${dep_bytes_fat12_start} build/check_makefile | build/mnt_fat12
	sudo umount build/mnt_fat12 || true
	sudo mount -o loop,ro,offset=${bytes_fat12_start} $< build/mnt_fat12
	ls -l build/mnt_fat12 | grep os.zip
	sudo umount build/mnt_fat12
	touch $@

build/test_pass/sudo_iso_mount: ${os_filename} build/check_makefile | build/mnt_iso
	sudo umount build/mnt_iso || true
	sudo mount -o loop,ro $< build/mnt_iso
	ls -l build/mnt_iso | grep os.zip
	sudo umount build/mnt_iso
	touch $@

# See https://wiki.osdev.org/EFI#Emulation to emulate an UEFI system with qemu, to test the EFI boot from hdd / cd / fd (?).