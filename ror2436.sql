REM ROR2436
REM Work Study Emails
REM **********************************************************************
REM Purpose:
REM
REM Creates the popsel for sending emails to students who have been placed
REM   in a job since the input from_date and who have a CWS award.
REM   
REM Uses FormFusion to send the emails   
REM
REM **********************************************************************
REM Parameters
REM   1          spool file
REM   aidy       aidy
REM   from_date  from date to select the jobs
REM
REM **********************************************************************
REM Modification History
REM Who  When       What
REM ---  ---------  ------------------------------------------------------
REM SLT 23-AUG-2018 WO 43795.  New SQL.
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
/*  Driving cursor - All Student Jobs Authorizations for the given Aid Year            */ 
/***************************************************************************************/
CURSOR c_rjrsear IS
SELECT DISTINCT
spriden_pidm                                  student_pidm,
spriden_id                                    student_id,
spriden_last_name                             last_name,
spriden_first_name                            first_name,
rjrsear_aidy_code                             aidy_code,
rjrsear_aust_code                             aust_code,
rjrsear_auth_start_date                       start_date,
rjrsear_auth_end_date                         end_date,
rjrsear_activity_date                         activity_date,
rjrplrl_posn_title                            job_desc,
rjrplrl_orgn_desc                             department,
ryk_common.f_get_student_email(spriden_pidm)  email,
(select nbrjobs_supervisor_pidm
from nbrjobs
where nbrjobs_posn = rjrsear_jobt_code
and nbrjobs_pidm = rjrsear_pidm
and nbrjobs_suff = rjrsear_suff
and nbrjobs_orgn_code_ts = rjrsear_place_cde
and nbrjobs_status = 'A'
and nbrjobs_effective_date = rjrsear_pay_start_date) supervisor_pidm
from rjrsear, rjrplrl, spriden 
where spriden_change_ind is null
and spriden_pidm = rjrsear_pidm
and rjrplrl_posn = rjrsear_posn
and rjrplrl_place_cde = rjrsear_place_cde
and rjrplrl_aidy_code = rjrsear_aidy_code
and rjrsear_aidy_code = '&aidy'
and rjrsear_aust_code = 'AUTH'
and trunc(rjrsear_activity_date) > trunc(to_date('&from_date','DD-MON-YYYY'))
order by spriden_last_name, spriden_first_name;

/***************************************************************************************/
/* Variables                                                                           */
/***************************************************************************************/
v_count              number;
supervisor_email     goremal.goremal_email_address%type;
supervisor_name      varchar2(180);

/**************************************************************************************************************************/
BEGIN

dbms_output.put_line ('STUDENT_ID, FIRST_NAME, LAST_NAME, JOB_DESC, DEPARTMENT, START_DATE, END_DATE, EMAIL, SUPERVISOR_NAME, SUPERVISOR_EMAIL');
v_count := 0;

/**************************************************/
/* Loop through all student jobs for the aid year */
/**************************************************/
FOR v_rjrsear IN c_rjrsear LOOP

    v_count := v_count + 1;
    
    if v_rjrsear.supervisor_pidm is null
    then
       supervisor_email := 'financial.aid.mailing@oregonstate.edu';
       supervisor_name  := 'Financial Aid Office';
    else 
       supervisor_email := gyk_common.Get_email_from_pidm(v_rjrsear.supervisor_pidm);
       supervisor_name  := gokname.f_get_name (v_rjrsear.supervisor_pidm, 'DISPFML');
       if supervisor_email is null
       then
          supervisor_email := 'financial.aid.mailing@oregonstate.edu';
          supervisor_name  := 'Financial Aid Office';
       end if;
    end if;
           
    dbms_output.put_line ('"'||v_rjrsear.student_id     ||'","'||
                               v_rjrsear.first_name     ||'","'||
                               v_rjrsear.last_name      ||'","'||
                               v_rjrsear.job_desc       ||'","'||
                               v_rjrsear.department     ||'","'||
                               v_rjrsear.activity_date  ||'","'||
                               v_rjrsear.end_date       ||'","'|| 
                               v_rjrsear.email          ||'","'||
                               supervisor_name          ||'","'||
                               supervisor_email           ||'"');

END LOOP;

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
      
    DBMS_OUTPUT.PUT_LINE('Exception: ' || SQLERRM);

END;
/
