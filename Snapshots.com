$!******************************************************************
$!
$set nover
$       On Error Then Goto ERROR_EXIT
$       On Control_y Then Goto OPER_EXIT
$       set proc/priv=all
$!
$       node = f$getsyi("nodename")
$       copy == "copy/log/noconfirm"
$       del*ete == "delete/log/noconfirm"
$       pur*ge == "purge/log/noconfirm"
$       nodename == f$getsyi("nodename")
$       Prodnodes == "xxxxx/yyyyy/zzzzz/aaaaa"
$       devnodes == "bbbbb/ccccc"
$       soltnodes == "ddddd/eeeeeee"
$       user == f$edit(f$getjpi("","USERNAME"),"Trim,collapse")
$       datetime == f$cvtime(,,"date") -"-"-"-"
$!
$!
$!
$       If  f$locate("''nodename'",devnodes) .ne. f$length(devnodes)
$       then
$               Home    =       "disk$performance:[snapshots]"
$       endif
$!
$       if  f$locate("''nodename'",Prodnodes) .ne. f$length(Prodnodes)
$       then
$               Home    =       "DISK$SYS_LOG1:[Snapshots]"
$       endif
$!
$       if f$locate("''nodename'",soltnodes) .ne. f$length(soltnodes)
$       then
$               Home ==  "disk$performance:[snapshots]"
$       endif
$!
$       if f$search("''Home'snapshots_''node'.dir") .eqs. ""
$       then
$               Home = Home - "]"
$               create/dire/log                 'Home'.snapshots_'node']
$               define/proc/nolog snapshots     'Home'.snapshots_'node']
$       else
$               Home = Home - "]"
$               define/proc/nolog snapshots     'Home'.snapshots_'node']
$               delete/nolog/noconfirm snapshots:*.*;*
$               Directory snapshots:
$       endif
$!
$       write sys$output ""
$       write sys$output "Writing Output Files To ''f$trnlnm("snapshots")'"
$       write sys$output ""
$!
$       show dev dsa/full/out=snapshots:shadow_sets_'node'.out
$       show dev dga/full/out=snapshots:dg_disks_'node'.out
$       show dev dk/full/out=snapshots:dk_disks_'node'.out
$       show dev dnfs/full/out=snapshots:dnfs_disks_'node'.out
$       show system/full/out=snapshots:system_'node'.out
$       show dev/out=snapshots:devices_'node'.out
$!
$       show que/man/full/out=snapshots:queue_manager.out
$       show que/all/full/batch/by=exe/out=snapshots:batches_executing.out
$       show que/all/full/batch/by=hold/out=snapshots:batches_holding.out
$       show que/all/full/batch/by=pending/out=snapshots:batches_pending.out
$       show que/all/full/batch/out=snapshots:batches_full.out
$       show que/dev/full/out=snapshots:device_queues.out
$!
$       show license/out=snapshots:license_'node'.out
$       show logical */table=* /out=snapshots:logicals_'node'.out
$       show mem/full/out=snapshots:memory_'node'.out
$       show rms/out=snapshots:rms_'node'.out
$       show cpu/full/out=snapshots:cpu_'node'.out
$!
$       show system/full/out=snapshots:system_processes_'node'.out
$!
$       mc lancp show dev /char/out=snapshots:lan_devices_'node'.out
$!
$       If f$getsyi("nodename") .eqs. "xxxxx"
$       Then
$               if f$search("snapshots:user_listing_''datetime'.out") .eqs. ""
$               Then
$!
$                       mc authorize list/full
$                       rename sysuaf.lis; user_listing_'datetime'.out
$                       copy/log user_listing_'datetime'.out snapshots:user_listing_'datetime'.out
$                       delete /log user_listing_'datetime'.out;*
$               endif
$       endif
$!
$       ifconfig := $tcpip$ifconfig
$       tcpip show services/full/out=snapshots:tcpip_'node'.out
$       define/user sys$output snapshots:tcpip_'node'_interfaces.out
$       tcpip show interfaces/full
$       define/user sys$output snapshots:tcpip_'node'_config.out
$       ifconfig -a
$       define/user sys$output snapshots:tcpip_'node'_config_name.out
$       tcpip show config name
$!
$       define sys$output snapshots:network_'node'.out
$       show net/full
$       deassign sys$output
$!
$       write sys$output ""
$       write sys$output " Saving sys$system:*.dat & cluster_common:*.dat into one saveset"
$       write sys$output ""
$!
$       backup/nolog/ignore=inter/replace sys$system:*.dat;,cluster_common:*.dat; snapshots:datfiles_out.bck/save
$       copy/nolog/noconfirm sys$system:startup.log snapshots:*.sav;
$       if f$search("sys$startup:startup$%.log") .nes. ""
$       then
$               copy/nolog/noconfirm sys$startup:startup$%.log; snapshots:*.sav;
$       endif
$!
$!
$       define sys$output snapshots:sysman_params_and_startup'node'.out
$       MC SYSMAN Parameter Show /ALL
$       MC Sysman Startup Show File/full
$       deass sys$output
$!
$       define sys$output snapshots:products_'node'.out
$       product show product
$       product show history
$       product show object
$       deassign sys$output
$!
$       define sys$output snapshots:installed_images_'node'.out
$       install list
$       deassign sys$output
$!
$       purge/nolo/noconfirm snapshots:*.*
$!
$       schedule show /out=snapshots:schedule.out
$!
$!set nover
$       set file/nobackup snapshots:*.*;*
$!      DIRE/SINCE/siz=all/Grand/sel=unit=byte SNAPSHOTS:
$ERROR_EXIT:
$OPER_EXIT:
$       deassign/proc snapshots
$       set def sys$login
$       exit
