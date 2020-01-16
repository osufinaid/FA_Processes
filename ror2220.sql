REM Place Cascades Holds Report
REM **********************************************************************
REM Purpose:
REM
REM Generates the students who need Cascades holds placed (CE).
REM
REM **********************************************************************
REM Parameters
REM   1  spool file
REM   2  Aid Year
REM   3  Term
REM **********************************************************************
REM Modification History
REM Who  When      What
REM ---  --------- -------------------------------------------------------
REM SLT  29-JAN-14 New program
REM SLT  23-SEP-14 Removed join with SHRLGPA and SGBSTDN, utilized
REM                functions to find student level and class standing to
REM                catch new post-bacc students.
REM                Used relations rather than prompts for term code and aid
REM                year where possible.
REM BTW  01-SEP-15 WO 30132 Removed level restriction of 01 & 03 based on 
REM                request from Jane Reynolds (approved by Doug Severs).
REM SLT  18-NOV-15 Comment out "and rorstat_pckg_comp_date is not null"
REM **********************************************************************
whenever sqlerror exit failure
whenever oserror exit failure
clear columns
clear sql
set termout off
set echo off
set pause off
set pagesize 1000
set verify off
set feedback off
set space 0
set linesize 500
set heading on
set underline off
set colsep ','
column ID format a15
column LAST_NAME format a50
column FIRST_NAME format a25
column FAFSA_LEVL format a20
column STUDENT_LEVEL format a20
column CLASS_STANDING a20
column HRS_EARNED format a10
column EMAIL format a100
spool &1
select distinct 
'"'||spriden_id||'"'                                            ID, 
'"'||spriden_last_name||'"'                                     LAST_NAME, 
'"'||spriden_first_name||'"'                                    FIRST_NAME,
'"'||decode((select RCRAPP1_YR_IN_COLL
            from rcrapp1
            where rcrapp1_pidm = spriden_pidm
            and rcrapp1_aidy_code = rorstat_aidy_code
            and rcrapp1_infc_code = 'EDE'
            and rcrapp1_curr_rec_ind = 'Y'), '1', 'Freshman', '2', 'Freshman', '3', 'Sophomore', '4', 'Junior', '5', 'Senior', '6', 'PB', '7', 'Grad')||'"'      
                                                                FAFSA_LEVEL,
'"'||f_sgbstdn_fields (rorstat_pidm, rpratrm_period, 'LEVEL')||'"' 
                                                                STUDENT_LEVEL,
(select '"'||decode(sgkclas.f_class_code(rorstat_pidm,(f_sgbstdn_fields (rorstat_pidm, rpratrm_period, 'LEVEL')),rpratrm_period),'ST',stvstyp_desc,stvclas_desc)||'"' from stvclas, stvstyp
where stvclas_code = sgkclas.f_class_code(rorstat_pidm,(f_sgbstdn_fields (rorstat_pidm, rpratrm_period, 'LEVEL')),rpratrm_period)
and  stvstyp_code(+) = f_sgbstdn_fields (rorstat_pidm, rpratrm_period, 'STU_TYPE'))  CLASS_STANDING,
'"'||(select SHRLGPA_HOURS_EARNED
      from shrlgpa
      where shrlgpa_pidm = rorstat_pidm
      and shrlgpa_levl_code = f_sgbstdn_fields (rorstat_pidm, rpratrm_period, 'LEVEL')
      and SHRLGPA_GPA_TYPE_IND = 'O')||'"'                       HRS_EARNED,     
'"'||(nvl((select goremal_email_address
      from goremal
      where goremal_pidm = spriden_pidm
      and goremal_emal_code = 'ONID'
      and goremal_status_ind = 'A'),(select RCRAPP4_EMAIL_ADDRESS
                                          from rcrapp4 inner join rcrapp1
                                                on rcrapp1_pidm = rcrapp4_pidm and rcrapp1_aidy_code = rcrapp4_aidy_code and rcrapp1_infc_code = rcrapp4_infc_code and rcrapp1_seq_no = rcrapp4_seq_no
                                                where rcrapp1_pidm = spriden_pidm
                                                and rcrapp1_aidy_code = rorstat_aidy_code
                                                and rcrapp1_curr_rec_ind = 'Y')))||'"'      
                                                                 EMAIL               
from spriden 
inner join rorstat on spriden_pidm = rorstat_pidm
inner join rpratrm on rorstat_pidm = rpratrm_pidm and rorstat_aidy_code = rpratrm_aidy_code
where spriden_change_ind is null
and rpratrm_aidy_code = '&aidy'
and rpratrm_period = '&term'
/* and rorstat_pckg_comp_date is not null */
and rpratrm_offer_amt > 0
and OSU_FA_DISB_RULES.F_GET_CAMP_CODE(rorstat_pidm, rorstat_aidy_code, rpratrm_period ) = 'B'
and 0 = ( nvl((select sum(sfrstcr_credit_hr) 	     
            from sfrstcr 	     
            where sfrstcr_pidm = spriden_pidm 	     
            and ((sfrstcr_rsts_code like 'R%') 	     
            or     
                (sfrstcr_rsts_code = 'GS'))     
            and sfrstcr_term_code = rpratrm_period
            ),0))
and not exists (select 'Y'
                from rorhold
                where rorhold_pidm = spriden_pidm
                and RORHOLD_HOLD_CODE = 'CE'
                and RORHOLD_PERIOD = rpratrm_period)
order by STUDENT_LEVEL, HRS_EARNED 
/
spool off
