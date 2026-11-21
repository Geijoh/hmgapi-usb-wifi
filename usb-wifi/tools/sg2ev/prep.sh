# options the car's TCC803X build selects, which this tree's Kconfig would drop
printf '\nconfig CAR_ABI\n\tdef_bool y\n\tselect ARCH_DMA_ADDR_T_64BIT\n\tselect ZONE_DMA\n\tselect MIGHT_HAVE_PCI\n' >> arch/arm/Kconfig
# the car's kernel has the vmacache_seqnum u64 backport
sed -i 's/^\(\s*\)u32 vmacache_seqnum;/\1u64 vmacache_seqnum;/' include/linux/mm_types.h include/linux/sched.h
