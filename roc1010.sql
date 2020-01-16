REM ROC1010
REM Create Population for Fin Aid Award Letters
REM **********************************************************************
REM Purpose:
REM
REM Create Population for Fin Aid Award Letters
REM
REM **********************************************************************
REM Parameters
REM   2  aid year
REM   3  upto letter
REM   4  student type (<I>ncoming, <R>eturning, <B>oth)
REM   5  revision   (<I>nitial, <R>evised, <B>oth)
REM   6  mail/email (<E>-mail, <M>mail) Email will exclude those who opt
REM                 for hard-copy only. (ROBUSDF_VALUE_9 = M)
REM **********************************************************************
REM Modification History
REM Who When      What
REM --- --------- --------------------------------------------------------
REM RHB 01-JUN-01 Added Revision parameter.
REM TbH 03-MAY-02 Added E-mail/Mailed parameter.
REM TbH 15-JUL-02 Fixed bug in Initial/Revised selection logic.
REM DAM 25-APR-07 Added call to set_optimizer_mode for Oracle 10
REM DAS 27-Feb-09 Auto-modified to fix set optimizer mode
REM SLT 18-JUL-13 Added AND RORSTAT_PCKG_REQ_COMP_DATE IS NOT NULL
REM SLT 20-MAY-14 DBEU Changes
REM SLT 24-MAR-16 Changed dependency parameter to incoming/returning 
REM               student parameter
REM **********************************************************************
whenever sqlerror exit failure
whenever oserror exit failure
@$BAN_UTIL/set_optimizer_mode;
SET ECHO ON
SET FEEDBACK ON
 
DELETE FROM GENERAL.GLBEXTR
 WHERE GLBEXTR_APPLICATION = 'FINAID'
   AND GLBEXTR_SELECTION   = 'AWDLTR'
   AND GLBEXTR_CREATOR_ID  = 'SAISUSR'
   AND GLBEXTR_USER_ID     = 'SAISPRD';
 
INSERT INTO GENERAL.GLBEXTR
(GLBEXTR_APPLICATION,
 GLBEXTR_SELECTION,
 GLBEXTR_CREATOR_ID,
 GLBEXTR_USER_ID,
 GLBEXTR_KEY,
 GLBEXTR_ACTIVITY_DATE,
 GLBEXTR_SYS_IND,
 GLBEXTR_SLCT_IND)
SELECT 'FINAID','AWDLTR','SAISUSR','SAISPRD',RORSTAT_PIDM,SYSDATE,'M',NULL
FROM RORSTAT
     INNER JOIN RCRAPP1 on rcrapp1_aidy_code = rorstat_aidy_code and rcrapp1_pidm = rorstat_pidm
     INNER JOIN RCRAPP2 on rcrapp2_aidy_code = rcrapp1_aidy_code and rcrapp2_pidm = rcrapp1_pidm and rcrapp2_infc_code = rcrapp1_infc_code and rcrapp2_seq_no = rcrapp1_seq_no
     INNER JOIN SPRIDEN on spriden_pidm = rorstat_pidm
 WHERE RORSTAT_AIDY_CODE = '&2'
 AND NVL(RORSTAT_AWD_LTR_IND,'Y') = 'Y'
   AND RORSTAT_PCKG_COMP_DATE IS NOT NULL
   AND RORSTAT_PCKG_REQ_COMP_DATE IS NOT NULL
   and rcrapp1_curr_rec_ind = 'Y'
   AND SPRIDEN_CHANGE_IND IS NULL
   AND EXISTS (SELECT 'X' FROM FAISMGR.RRRAREQ
                WHERE RORSTAT_AIDY_CODE = RRRAREQ_AIDY_CODE
                  AND RORSTAT_PIDM      = RRRAREQ_PIDM
                  AND RRRAREQ_TREQ_CODE = 'ADMIT'
                  AND RRRAREQ_TRST_CODE NOT IN ('E','C'))
   AND NOT EXISTS (SELECT 'X' FROM FAISMGR.RTVSAPR, FAISMGR.RORSAPR
                WHERE RORSAPR_TERM_CODE = (SELECT MAX(RORSAPR_TERM_CODE)
                                             FROM FAISMGR.RORSAPR
                                            WHERE RORSAPR_PIDM = RORSTAT_PIDM)
                  AND RORSAPR_PIDM      = RORSTAT_PIDM
                  AND RORSAPR_SAPR_CODE = RTVSAPR_CODE
                  AND RTVSAPR_PCKG_IND = 'Y')
   AND EXISTS (SELECT 'X' FROM FAISMGR.RPRAWRD
                WHERE RORSTAT_AIDY_CODE = RPRAWRD_AIDY_CODE
                  AND RORSTAT_PIDM      = RPRAWRD_PIDM
                  AND RPRAWRD_OFFER_AMT > 0)
   and ('&6' <> 'E'
          or
        not exists
          (select 'x' from ROBUSDF
             where ROBUSDF_PIDM = RORSTAT_PIDM
             and   ROBUSDF_AIDY_CODE = RORSTAT_AIDY_CODE
             and   NVL(ROBUSDF_VALUE_9, 'E') = 'M'))
   and (
          ('&5' = 'B')
          or (
                ('&5' = 'R')
                and exists (select 'X'
                                from gurmail
                               where gurmail_pidm = rorstat_pidm
                                 and gurmail_aidy_code = rorstat_aidy_code
                                 and gurmail_system_ind = 'R'
                                 and gurmail_module_code = 'R'
                                 and gurmail_letr_code = 'AWDLTR')
             )
          or (
                ('&5' = 'I')
                and not exists (select 'X'
                                from gurmail
                               where gurmail_pidm = rorstat_pidm
                                 and gurmail_aidy_code = rorstat_aidy_code
                                 and gurmail_system_ind = 'R'
                                 and gurmail_module_code = 'R'
                                 and gurmail_letr_code = 'AWDLTR')
                )
       )
 and (
          ('&4' = 'B')
          or (
                ('&4' = 'I')
                and exists (select 'X'
                            from saradap b
                            left join sarappd c on b.saradap_pidm = c.sarappd_pidm 
                                               and b.saradap_term_code_entry = c.sarappd_term_code_entry 
                                               and b.saradap_appl_no = c.sarappd_appl_no
                            where b.saradap_pidm = rorstat_pidm
                            and b.saradap_term_code_entry in (select stvterm_code 
                                                              from stvterm 
                                                              where STVTERM_FA_PROC_YR = '&2')
                            and nvl(c.sarappd_apdc_code,'AA') not in (select stvapdc_code
                                                                      from stvapdc
                                                                      where stvapdc_appl_inact = 'Y')
                            and (c.sarappd_seq_no is null or (c.sarappd_seq_no = (select max(d.sarappd_seq_no)
                                                              from sarappd d
                                                              where d.sarappd_pidm = c.sarappd_pidm
                                                              and d.sarappd_term_code_entry = c.sarappd_term_code_entry
                                                              and d.sarappd_appl_no = c.sarappd_appl_no))))
             )
          or (
                ('&4' = 'R')
                and not exists (select 'X'
                            from saradap b
                            left join sarappd c on b.saradap_pidm = c.sarappd_pidm 
                                               and b.saradap_term_code_entry = c.sarappd_term_code_entry 
                                               and b.saradap_appl_no = c.sarappd_appl_no
                            where b.saradap_pidm = rorstat_pidm
                            and b.saradap_term_code_entry in (select stvterm_code 
                                                              from stvterm 
                                                              where STVTERM_FA_PROC_YR = '&2')
                            and nvl(c.sarappd_apdc_code,'AA') not in (select stvapdc_code
                                                                      from stvapdc
                                                                      where stvapdc_appl_inact = 'Y')
                            and (c.sarappd_seq_no is null or (c.sarappd_seq_no = (select max(d.sarappd_seq_no)
                                                             from sarappd d
                                                             where d.sarappd_pidm = c.sarappd_pidm
                                                             and d.sarappd_term_code_entry = c.sarappd_term_code_entry
                                                             and d.sarappd_appl_no = c.sarappd_appl_no))))
                )
       )
     ;
