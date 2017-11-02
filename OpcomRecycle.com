$ !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
$ ! PROGRAM NAME: OPCOM_RECYCLE.COM                                            !
$ !                                                                            !
$ !                                                                            !
$ !    PROGRAM DESCRIPTION:                                                    !
$ !         This program does the Renewal of OPCOM file rename it by -         !
$ !         appending date to its name.                                        !
$ !                                                                            !
$ !                                                                            !
$ !                                                                            !
$ !    MODIFICATION HISTORY                                                    !
$ !    --------------------                                                    !
$ !    AUTHOR               DATE           DESCRIPTION                         !
$ !    ----------------    -----------     ---------------------------------   !
$ !    (JS)                27-OCT-2014     Initial version of the script       !
$ !                                                                            !
$ !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
$ SET NOVERIFY
$ SET NOON
$! ON WARNING THEN GOTO ERROR_HANDLE_W
$ ON ERROR THEN GOTO ERROR_HANDLE
$! ON SEVERE_ERROR THEN GOTO ERROR_HANDLE_F
$ WS := write sys$output
$ NODE = F$GETS("NODENAME")
$ YEST_D = F$CVTIME("YESTERDAY","comparison","DATE") - "-" - "-"
$ WS "Starting the script to renew the OPCOM file on node ''NODE' at ''f$time()' "
$!!!!! CHECK IF LOGICAL IS SET AND PICK FILE TO PROCESS ACCORDINGLY !!!!!!!!!
$ PARAGRAPH = "CHECKING LOGICAL"
$!
$ IF F$TRNL("OPC$LOGFILE_NAME") .NES. ""
$  THEN
$    OLD_FIL = f$sear("OPC$LOGFILE_NAME")
$    WS "Current file is ''OLD_FIL'"
$  ELSE
$    OLD_FIL = f$sear("SYS$SPECIFIC:[SYSMGR]OPERATOR.LOG;")
$    WS "Current file is ''OLD_FIL'"
$  ENDIF
$!!!!!!!! ACTUAL REFRESH OF FILE IS DONE IN THE BELOW SECTION !!!!!!!!!!!!!!!!!
$ PARAGRAPH = "REFRESH FILE"
$ SET PROCESS/PRIVILEGES=OPER
$ DEFINE SYS$COMMAND OPA0:
$ REPLY/ENABLE
$ REPLY/LOG
$ REN_STATUS = $STATUS
$ DEASSIGN SYS$COMMAND
$ WAIT 00:00:30         !!!  Allowing few seconds to create the file.
$!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
$ PARAGRAPH = "RENAME THE OLD FILE"
$ IF F$TRNL("OPC$LOGFILE_NAME") .NES. ""
$  THEN
$    NEW_FIL = f$sear("OPC$LOGFILE_NAME")
$    WS "New file is ''NEW_FIL'"
$    IF NEW_FIL .NES. OLD_FIL
$     THEN
$       WS "OPCOM file renewed and new file created"
$       DEV = F$PARSE(OLD_FIL,,,"DEVICE")
$       DRT = F$PARSE(OLD_FIL,,,"DIRECTORY")
$       FIL = F$PARSE(OLD_FIL,,,"NAME") + "_" + YEST_D
$       EXT = F$PARSE(OLD_FIL,,,"TYPE")
$       ARC_FIL = DEV + DRT + FIL + EXT + ";"
$       RENAME/LOG/NOCONF 'OLD_FIL' 'ARC_FIL'
$       IF $STATUS
$        THEN
$         WS "OPCOM file renamed as expected."
$        ELSE
$         WS "ERROR -E-, OPCOM_RECYCLE, error while renaming, please investigate"
$        ENDIF
$     ELSE
$      WS "ERROR -E-, OPCOM_RECYCLE, OPCOM file is not renewed, please investigate the reason"
$    ENDIF
$  ELSE
$    NEW_FIL = f$sear("SYS$SPECIFIC:[SYSMGR]OPERATOR.LOG;")
$    WS "New file is ''NEW_FIL'"
$    IF NEW_FIL .NES. OLD_FIL
$     THEN
$       WS "OPCOM file renewed and new file created"
$       DEV = F$PARSE(OLD_FIL,,,"DEVICE")
$       DRT = F$PARSE(OLD_FIL,,,"DIRECTORY")
$       FIL = F$PARSE(OLD_FIL,,,"NAME") + "_" + YEST_D
$       EXT = F$PARSE(OLD_FIL,,,"TYPE")
$       ARC_FIL = DEV + DRT + FIL + "_" + NODE + EXT + ";"
$       RENAME/LOG/NOCONF 'OLD_FIL' 'ARC_FIL'
$       IF $STATUS
$           THEN
$            WS "OPCOM file renamed as expected."
$           ELSE
$            WS "ERROR -E-, OPCOM_RECYCLE, error while renaming, please investigate"
$       ENDIF
$     ELSE
$      WS "ERROR -E-, OPCOM_RECYCLE, OPCOM file is not renewed, please investigate the reason"
$    ENDIF
$  ENDIF
$!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
$ARCHIVING:
$  PARAGRAPH = "ARCHIVING"
$  D_DIR = DEV + DRT
$  FILE =  F$PARSE(OLD_FIL,,,"NAME") + "_*" + EXT + ";*"
$  IF F$SEARCH("SYS$TOOLS:ARCHIVE_SUB.COM") .NES. ""
$   THEN
$     !!! Calling a common subroutine to do the archiving
$     @ SYS$TOOLS:ARCHIVE_SUB 'D_DIR' 'FILE' "" "1" "SYS_LOG1:[OPCOM_LOGS]"
$   ELSE
$     WS "Archive subroutine ARCHIVE_SUB.COM  is not availabe in sys$tool, please check"
$   ENDIF
$  EXIT
$!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
$ERROR_HANDLE:
$ PROC_STAT = $STATUS
$ Sho sym proc_stat
$ WS "ERROR -E-, OPCOM_RECYCLE, Error encountered during the script execution in the section label:''label'"
$ EXIT 'PROC_STAT'
