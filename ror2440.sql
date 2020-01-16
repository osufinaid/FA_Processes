REM ROR2440
REM Loan History Email Notifications
REM **********************************************************************
REM Purpose:
REM
REM Creates the popsel for sending emails to students who have been 
REM   notified of their loan history.  It checks for:
REM      1. Active student (sgbstdn record in aid year with status CN or RT)
REM      2. FAFSA in aid year
REM      3. GURMAIL letter code of SB253 does not already exist for the aid year
REM   
REM Uses FormFusion to send the emails   
REM
REM **********************************************************************
REM Parameters
REM   1          spool file
REM   aidy       Aid Year
REM   runmode    A=Audit, U=Update
REM
REM **********************************************************************
REM Modification History
REM Who  When       What
REM ---  ---------  ------------------------------------------------------
REM SLT 15-OCT-2018 WO 50457.  New SQL.
REM **********************************************************************
whenever sqlerror exit failure
whenever oserror exit failure
@$BAN_UTIL/set_optimizer_mode;
SET TERMOUT OFF
SET ECHO OFF
SET FEEDBACK OFF
SET VERIFY OFF
set pagesize 50000
set linesize 2000
set serveroutput on
SPOOL &1

DECLARE

/***************************************************************************************/
/*  Driving cursor - All new and continuing students who have not received the         */
/*                   SB 253 Loan History email                                         */ 
/***************************************************************************************/
CURSOR c_sgbstdn (term  stvterm.stvterm_code%type )
IS
SELECT DISTINCT
spriden_pidm                                                                                           student_pidm,
spriden_id                                                                                             student_id,
spriden_last_name                                                                                      last_name,
spriden_first_name                                                                                     first_name,
stvlevl_desc                                                                                           student_level,
ryk_common.f_get_student_email(spriden_pidm)                                                           email,
f_sgbstdn_fields(spriden_pidm, term, 'LEVEL')                                                          levl,
(Select shrlgpa_hours_earned from shrlgpa
                             where shrlgpa_pidm = spriden_pidm
                             and shrlgpa_gpa_type_ind = 'O'
                             and shrlgpa_levl_code = f_sgbstdn_fields(spriden_pidm, term, 'LEVEL'))    earned_hours,
RCRLDS4_AGT_SUB_OUT_PRIN_BAL                                                                           sub_loans,
rcrlds4_agt_comb_prin_bal                                                                              total_sub_unsub_loans,
rcrlds4_perk_cumulative_amt                                                                            perkins,
rcrlds4_proc_date                                                                                      loan_date,
(Select rcrapp2_c_depend_status from rcrapp2 inner join rcrapp1
            on rcrapp2_PIDM = rcrapp1_PIDM AND rcrapp2_AIDY_CODE = rcrapp1_AIDY_CODE AND rcrapp2_INFC_CODE = rcrapp1_INFC_CODE AND rcrapp2_SEQ_NO = rcrapp1_SEQ_NO
                        where rcrapp2_PIDM = spriden_pidm
                        AND rcrapp2_AIDY_CODE = '&aidy'
                        AND rcrapp2_INFC_CODE = 'EDE'
                        and rcrapp1_curr_rec_ind = 'Y')                                                dependency,
(select decode(SGKCLAS.F_CLASS_CODE(spriden_pidm,f_sgbstdn_fields(sgbstdn_pidm, term, 'LEVEL'),term),'ST',stvstyp_desc,stvclas_desc)
        FROM sgbstdn, stvstyp, stvclas
         WHERE sgbstdn_pidm = spriden_pidm
           AND stvstyp_code(+) = sgbstdn_styp_code
           AND stvclas_code = sgkclas.f_class_code(spriden_pidm,f_sgbstdn_fields(sgbstdn_pidm, term, 'LEVEL'),term)
           AND sgbstdn_term_code_eff = (select max(sgbstdn_term_code_eff)
                                          from sgbstdn
                                         where sgbstdn_pidm = spriden_pidm
                                           and sgbstdn_term_code_eff <= term))                        class,
(SELECT distinct rlrdlor_hppa_ind
        from rlrdlor
        where rlrdlor_pidm = spriden_pidm
        and rlrdlor_hppa_ind = 'Y')                                                                    HPPA,
(select distinct 'Y'
        from rcrlds6
        where rcrlds6_aidy_code = '&aidy'
        and rcrlds6_pidm = spriden_pidm
        and rcrlds6_extra_unsub_ln_flag = 'P'
        and rcrlds6_dir_prog_cd = 'D2'
        and rcrlds6_curr_rec_ind = 'Y')                                                                plus_denied
from stvlevl, sgbstdn, rcrapp1, rcrlds4, spriden 
where spriden_change_ind is null
and spriden_pidm = sgbstdn_pidm
and sgbstdn_stst_code in ('CN', 'RT')
and stvlevl_code = sgbstdn_levl_code
and rcrapp1_pidm = sgbstdn_pidm
and rcrapp1_aidy_code = rcrlds4_aidy_code
and rcrapp1_infc_code = 'EDE'
and rcrapp1_curr_rec_ind = 'Y'
and rcrlds4_pidm = sgbstdn_pidm
and rcrlds4_aidy_code = '&aidy'
and rcrlds4_curr_rec_ind = 'Y'
and exists (select 'x'
            from rcrlds4
            where rcrlds4_pidm = spriden_pidm
            and (nvl(rcrlds4_agt_sub_out_prin_bal,0) > 0 
                 or nvl(rcrlds4_agt_comb_prin_bal,0) > 0
                 or nvl(rcrlds4_perk_cumulative_amt,0) > 0))
and exists (select 'x'
            from rcrapp3
            where rcrapp3_pidm = spriden_pidm
            and rcrapp3_aidy_code = rcrlds4_aidy_code
            and rcrapp3_infc_code = 'EDE'
            and rcrapp3_offl_unoffl_ind <> '2')
and sgbstdn_term_code_eff = (select max(sgbstdn_term_code_eff)
                             from sgbstdn
                             where sgbstdn_pidm = spriden_pidm
                             and sgbstdn_term_code_eff <= (select max(stvterm_code) from stvterm
                                                           where stvterm_trmt_code = '4'
                                                           and stvterm_fa_proc_yr = '&aidy'))
and not exists (select 'x'
                from gurmail
                where gurmail_pidm = spriden_pidm
                and gurmail_letr_code = 'SB253'
                and gurmail_aidy_code = rcrlds4_aidy_code)
order by spriden_last_name, spriden_first_name;


/***************************************************************************************/
/* Variables                                                                           */
/***************************************************************************************/
v_count                   number;
term_code                 stvterm.stvterm_code%type; 
lifetime_remain_direct    number;
lifetime_remain_perkins   number;
lifetime_remain_sub       number;
lifetime_remain_total     number;
lifetime_used_direct      number;
lifetime_used_perkins     number;
lifetime_used_sub         number;
lifetime_used_total       number;
max_direct                number;
max_perkins               number;
max_sub                   number;
max_total                 number;
message_sub               varchar2(50);
message_unsub             varchar2(50);

/**************************************************************************************************************************/
BEGIN

dbms_output.put_line ('STUDENT_ID, FIRST_NAME, LAST_NAME, STUDENT_LEVEL, EMAIL, MESSAGE_SUB, MESSAGE_UNSUB, DEPEND, HPPA, PLUS_DENIED,MAX_SUB, SUB_LOAN, SUB_REMAIN, MAX_TOTAL, TOTAL_LOAN, TOTAL_REMAIN');

    v_count := 0;

    select max(stvterm_code)
    into term_code
    from stvterm
    where stvterm_trmt_code = '4'
    and trunc(stvterm_start_date) <= TRUNC(sysdate);

/**************************************************/
/* Loop through all student jobs for the aid year */
/**************************************************/
FOR v_sgbstdn IN c_sgbstdn (term_code) LOOP

    v_count := v_count + 1;
    
    INSERT INTO GENERAL.GURMAIL
    (GURMAIL_PIDM,
    GURMAIL_SYSTEM_IND,
    GURMAIL_MODULE_CODE,
    GURMAIL_LETR_CODE,
    GURMAIL_DATE_INIT,
    GURMAIL_DATE_PRINTED,
    GURMAIL_USER,
    GURMAIL_AIDY_CODE,
    GURMAIL_ORIG_IND,
    GURMAIL_PUB_GEN,
    GURMAIL_ACTIVITY_DATE)
    VALUES
    (v_sgbstdn.student_pidm,
    'R',
    'R',
    'SB253',
    SYSDATE,
    SYSDATE,
    USER,
    '&aidy',
    'S',
    'G',
     SYSDATE); 
    
     if v_sgbstdn.levl is not null
     then    
     
      message_sub := '';
      message_unsub := '';
        
      case 
         when v_sgbstdn.levl = '01' or v_sgbstdn.levl = '03' then
            max_sub := 23000;
            case 
               when v_sgbstdn.dependency = '1' then 
                  max_direct := 57500;
               when v_sgbstdn.dependency = '2' then
                  if v_sgbstdn.plus_denied is null then
                     max_direct := 31000;
                  else 
                     max_direct := 57500;
                  end if;
               else
                  max_direct := 31000;
            end case;  
         when v_sgbstdn.levl = '02' then
            max_sub := 65500;
            max_direct := 138500;
         when v_sgbstdn.levl = '05' then
            max_sub := 65500;
            max_direct := 138500;
            if v_sgbstdn.HPPA = 'Y'
            then
               message_sub := 'N/A';
               message_unsub := 'Unable to calculate usage';
            end if;
         when v_sgbstdn.levl = '04' then
            max_sub := 23000;
            max_direct := 31000;
            message_sub := 'Unable to calculate usage';
            message_unsub := 'Unable to calculate usage';
         else
            max_sub := 23000;
            max_direct := 31000;
      end case;   
 
      lifetime_used_sub := nvl(v_sgbstdn.sub_loans,0);
      lifetime_remain_sub := max_sub - lifetime_used_sub;
      lifetime_used_direct := nvl(v_sgbstdn.total_sub_unsub_loans,0);
      lifetime_remain_direct := max_direct - lifetime_used_direct;
      
      if lifetime_remain_sub < 0
      then
         message_sub := 'Unable to calculate usage';
      end if;
      if lifetime_remain_direct < 0
      then
         message_unsub := 'Unable to calculate usage';
      end if;
     
    end if;
           
    dbms_output.put_line ('"'||v_sgbstdn.student_id ||'",'||
                          '"'||v_sgbstdn.first_name ||'",'||
                          '"'||v_sgbstdn.last_name ||'",'||
                          '"'||v_sgbstdn.student_level ||'",'||
                          '"'||v_sgbstdn.email||'",'|| 
                          '"'||message_sub ||'",'|| 
                          '"'||message_unsub ||'",'|| 
                          '"'||v_sgbstdn.dependency ||'",'|| 
                          '"'||v_sgbstdn.HPPA ||'",'|| 
                          '"'||v_sgbstdn.plus_denied ||'",'|| 
                          '"'||max_sub ||'",'|| 
                          '"'||v_sgbstdn.sub_loans ||'",'|| 
                          '"'||lifetime_remain_sub ||'",'|| 
                          '"'||max_direct ||'",'|| 
                          '"'||v_sgbstdn.total_sub_unsub_loans ||'",'|| 
                          '"'||lifetime_remain_direct||'"' );

END LOOP;

if ('&runmode' = 'U')
then
   COMMIT;
   dbms_output.put_line (v_count || ' ROWS COMMITTED');
else
   ROLLBACK;
   dbms_output.put_line ('AUDIT MODE - ROLLBACK '||v_count||' ROWS');
end if;


EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
      
    DBMS_OUTPUT.PUT_LINE('Exception: ' || SQLERRM);

END;
/
