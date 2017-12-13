$!  DCL to update and indexed file on OpenVMS 
$    bmn_t_date     = 0
$    bmn_s_date     = 12
$    bmn_t_dupr     = 12
$    bmn_s_dupr     = 76
$    bmn_t_upr      = 88
$    bmn_s_upr      = 64
$    bmn_t_label    = 152
$    bmn_s_label    = 64
$    bmn_t_status   = 216
$    bmn_s_status   = 20
$    bmn_l_tt       = 236*8
$    bmn_l_totfil   = 240*8
$    bmn_l_picked   = 244*8
$    bmn_l_success  = 248*8
$    bmn_l_errored  = 252*8
$    bmn_l_skipped  = 256*8
$    bmn_l_succperc = 260*8
$    bmn_t_logfil   = 264
$    bmn_s_logfil   = 109
$!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
$       date            = f$element(0,",",P1)
$       dupr            = f$element(0,",",P1)+f$element(1,",",P1)
$       upr             = f$element(1,",",P1)
$       label           = f$element(2,",",P1)
$       status          = f$element(3,",",P1)
$       ttinmin         = f$integer(f$element(4,",",P1))
$       totfil          = f$integer(f$element(5,",",P1))
$       picked          = f$integer(f$element(6,",",P1))
$       success         = f$integer(f$element(7,",",P1))
$       errored         = f$integer(f$element(8,",",P1))
$       skipped         = f$integer(f$element(9,",",P1))
$       succperc        = f$integer(f$element(10,",",P1))
$       logfil          = f$element(11,",",P1)
$!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
$       rec = ""
$       rec[bmn_t_date,bmn_s_date]              := "''date'"
$       rec[bmn_t_dupr,bmn_s_dupr]              := "''dupr'"
$       rec[bmn_t_upr,bmn_s_upr]                := "''upr'"
$       rec[bmn_t_label,bmn_s_label]            := "''label'"
$       rec[bmn_t_status,bmn_s_status]          := "''status'"
$       rec[bmn_l_tt,32]                        = ttinmin
$       rec[bmn_l_totfil,32]                    = totfil
$       rec[bmn_l_picked,32]                    = picked
$       rec[bmn_l_success,32]                   = success
$       rec[bmn_l_errored,32]                   = errored
$       rec[bmn_l_skipped,32]                   = skipped
$       rec[bmn_l_succperc,32]                  = succperc
$       rec[bmn_t_logfil,bmn_s_logfil]          := "''logfil'"
$!sho sym rec
$!write sys$output f$length(rec)
$!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
$!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
$write_rec:
$       close/nolog bmn_db_rec
$       open/read/write/share=write/error=err bmn_db_rec BMON_DB_NEW.DAT;
$       write/symbol/error=fatal bmn_db_rec rec
$       goto out
$err:
$       write sys$output "label:err-",f$message($status)
$       goto out
$fatal:
$! sho sym $status
$       if $status .eqs. "%X000184EC" then goto duplicate
$       write sys$output "label:fatal-",f$message($status)
$       goto out
$duplicate:
$       close/nolog bmn_db_rec
$       open/read/write/share=write/error=err bmn_db_rec BMON_DB_NEW.DAT;
$       read/match=EQ/key='dupr'/index=1/dele/error=dup_read_err/end=dup_read_end bmn_db_rec old_rec
$       close/nolog bmn_db_rec
$       goto write_rec
$dup_read_end:
$       write sys$output "label:dup_read_end-",f$message($status)
$       goto out
$dup_read_err:
$       write sys$output "label:dup_read_err-",f$message($status)
$       goto out
$out:
$       close/nolog bmn_db_rec
$exit
