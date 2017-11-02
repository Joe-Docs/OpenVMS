$! Usage @SetXtermDisplay.com
$! Works for both telnet and SSH sessions.
$!
$       if f$extract(0,4,F$GETJPI("","TT_PHYDEVNAM")) .EQS. "_TNA"
$       then
$               x = f$getjpi("","tt_accpornam")
$               p1 = f$element(1," ",x)
$               SET DISPLAY /CREATE /NODE='p1'/tran=tcpip
$       else
$               if f$extract(0,4,F$GETJPI("","TT_PHYDEVNAM")) .EQS. "_FTA"
$                then
$                       p1 = f$trnlnm("SYS$REM_NODE_FULLNAME","LNM$JOB") - "::"
$                       SET DISPLAY /CREATE /NODE='p1'/tran=tcpip
$                endif
$       endif
$ exit
