$ !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
$ ! PROGRAM NAME: MAIL.COM                                                                                         !
$ !                                                                                                                !
$ !                                                                                                                !
$ !    PROGRAM DESCRIPTION:                                                                                        !
$ !         This program is used to send mail in our environment (Mainly for mails with attachments)               !
$ !                                                                                                                !
$ !                                                                                                                !
$ !    ADDITIONAL INFO:                                                                                            !
$ !         P1 : Subject of the mail to be sent                                                                    !
$ !         P2 : Body of the mail should be put in a file and given as P2                                          !
$ !         P3 : List of attachments with , separated and prefix by TEXT- or BINARY-                               !
$ !                 (Ex:TEXt-SYS$lOGIN.COM BINARY-PRISM_REPORT:TEST.DOC)                                           !
$ !         P4 : EMAIL-ID to which the E-MAIL to be sent. IF YOU ARE GIVING DIS FILE THEN PREIX WITH @ EX: @X.DIS  !
$ !         P5 : CC EMAIL ID - IF YOU ARE GIVING DIS FILE THEN PREIX WITH @ EX: @X.DIS                             !
$ !                                                                                                                !
$ !    Usage:                                                                                                      !
$ !         @mail "Subject" "body.txt" "text-attachment.txt,binary-attachment.doc" "myemail@domain.com             !
$ !    MODIFICATION HISTORY                                                                                        !
$ !    --------------------                                                                                        !
$ !    AUTHOR               DATE           DESCRIPTION                                                             !
$ !    ----------------    -----------     ------------------------------------                                    !
$ !    (JS)                10-APR-2015    Initial version of the script                                            !
$ !                                                                                                                !
$ !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
$    WS :== WRITE SYS$OUTPUT
$    NODE = F$GETSYI("NODENAME")
$    SET NOVERIFY
$!
$!   Populating the mail file to be sent
$    OPEN/WRITE OUT_FILE MAIL.OUT
$    WRITE OUT_FILE "MIME-VERSION: 1.0"
$    WRITE OUT_FILE "CONTENT-TYPE: TEXT/HTML; CHARSET=ISO-8859-1"
$    WRITE OUT_FILE "CONTENT-DISPOSITION: INLINE"
$    WRITE OUT_FILE "CONTENT-TRANSFER-ENCODING: 7BIT"
$    WRITE OUT_FILE "MESSAGE-ID: <564310338.113694182911398975.1@OPENVMS.MIME.V1.93>"
$    WRITE OUT_FILE "X-Priority: 1 (Highest)"
$    WRITE OUT_FILE "X-MSMail-Priority: High"
$    WRITE OUT_FILE "Importance: High"
$    WRITE OUT_FILE ""
$    WRITE OUT_FILE "<html>"
$    WRITE OUT_FILE "<body>"
$    WRITE OUT_FILE "<pre style=""font: monospace"">"
$!   If mail body details are provided in a file, insert all the records.
$    IF P2 .NES. ""
$      THEN
$          IF F$SEARCH(P2) .EQS. ""
$           THEN
$            WS "MAIL-W-BODY FILE PROVIDED DOES NOT EXIST, BODY WILL BE EMPTY"
$           ELSE
$             OPEN/READ BODYIN 'P2'
$BODY_LOOP:
$             READ/END=END_BODY_LOOP BODYIN BODYLINE
$             WRITE OUT_FILE BODYLINE
$             GOTO BODY_LOOP
$END_BODY_LOOP:
$             CLOSE BODYIN
$           ENDIF
$       ELSE
$        WS "MAIL-W-BODY NO INPUT FOR MAIL BODY, BODY WILL BE EMPTY"
$       ENDIF
$    CLOSE OUT_FILE
$!    Now populating a temp file for mime to wrap the attachements to mail.out file.
$    OPEN/WRITE TEMP_FILE MIME_TEMP.OUT
$    WRITE TEMP_FILE "MIME := $SYS$SYSTEM:MIME.EXE"
$    WRITE TEMP_FILE "MIME"
$    WRITE TEMP_FILE "OPEN/DRAFT   MAIL.OUT"
$    IF P3 .NES. ""
$      THEN
$         COUNT = 0
$         FILE_LIST = P3
$FILE_LOOP:
$         FILE = ""
$         FILE = F$ELEMENT('COUNT',",",FILE_LIST)
$         IF FILE .NES. ","
$           THEN
$              FILE_'COUNT' = FILE
$           ELSE
$              GOTO END_FILE_LOOP
$           ENDIF
$         COUNT = COUNT + 1
$         GOTO FILE_LOOP
$END_FILE_LOOP:
$         TOTAL_FILE = COUNT
$         ATTACH_COUNT = 0
$ATTACH_LOOP:
$         IF ATTACH_COUNT .LT. TOTAL_FILE
$          THEN
$             FORMAT = F$ELEMENT(0,"-",FILE_'ATTACH_COUNT')
$             FILE_ATT = F$ELEMENT(1,"-",FILE_'ATTACH_COUNT')
$             WRITE TEMP_FILE " ADD/''FORMAT' ''FILE_ATT'"
$             ATTACH_COUNT = ATTACH_COUNT + 1
$             GOTO ATTACH_LOOP
$          ENDIF
$      ENDIF
$        WRITE TEMP_FILE " </pre> "
$    WRITE TEMP_FILE " </body> "
$    WRITE TEMP_FILE " </html> "
$    WRITE TEMP_FILE " CLOSE "
$    WRITE TEMP_FILE " EXIT"
$    CLOSE TEMP_FILE
$!   Executing the temp file to have the attachment and body to be wrapped in mail.out
$    @MIME_TEMP.OUT
$    IF P5 .EQS. ""
$     THEN
$       IF P2 .EQS. "" .AND. P3 .EQS. ""
$               THEN
$                       MAIL/SUBJECT="''P1'" NL: "''P4'"
$               ELSE
$                       MAIL/SUBJECT="''P1'" MAIL.OUT; "''P4'"
$               ENDIF
$         ELSE
$               IF P2 .EQS. "" .AND. P3 .EQS. ""
$               THEN
$                                       OPEN/WRITE CCOUT MAIL_CC.OUT
$                                       WRITE CCOUT "MAIL"
$                                       WRITE CCOUT "SET CC"
$                                       WRITE CCOUT "SEND"
$                                       WRITE CCOUT P4
$                                       WRITE CCOUT P5
$                                       WRITE CCOUT P1
$                                       CLOSE CCOUT
$                                       @mail_cc.out
$                          ELSE
$                   OPEN/WRITE CCOUT MAIL_CC.OUT
$                   WRITE CCOUT "MAIL"
$                   WRITE CCOUT "SET CC"
$                   WRITE CCOUT "SEND MAIL.OUT"
$                   WRITE CCOUT P4
$                   WRITE CCOUT P5
$                   WRITE CCOUT P1
$                   CLOSE CCOUT
$                   @mail_cc.out
$                         ENDIF
$               ENDIF
$    IF F$SEARCH("MAIL.OUT") .NES. "" THEN DELETE/NOLOG/NOCONF MAIL.OUT;*
$        IF F$SEARCH("MAIL_CC.OUT") .NES. "" THEN DELETE/NOLOG/NOCONF MAIL_CC.OUT;*
$    IF F$SEARCH("MIME_TEMP.OUT") .NES. "" THEN DELETE/NOLOG/NOCONF MIME_TEMP.OUT;*
$    EXIT
