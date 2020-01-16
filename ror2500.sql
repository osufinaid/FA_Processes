REM ROR2500
REM Financial Aid General Email Notifications
REM **********************************************************************
REM Purpose:
REM
REM Creates a csv file for sending a general email to students based on the
REM   input popsel.  
REM
REM Inserts letter code FAGEN into GURMAIL.
REM   
REM Uses FormFusion to send the emails   
REM
REM **********************************************************************
REM Parameters
REM   1           spool file
REM   aidy        Aid Year
REM   application Popsel Application
REM   selection   Popsel Selection
REM   creator_id  Popsel Creator ID
REM   user_id     Popsel User ID
REM   runmode     A=Audit, U=Update
REM
REM **********************************************************************
REM Modification History
REM Who  When       What
REM ---  ---------  ------------------------------------------------------
REM SLT 21-OCT-2019 WO 56515.  New SQL.
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

/****************************************************************/
/*  Driving cursor                                              */
/****************************************************************/
CURSOR c_email
IS
SELECT DISTINCT
spriden_pidm                                     student_pidm,
spriden_id                                       student_id,
spriden_last_name                                last_name,
spriden_first_name                               first_name,
ryk_common.f_get_student_email(spriden_pidm)     email
from glbextr, spriden 
where spriden_change_ind is null
and spriden_pidm = glbextr_key
and glbextr_application = '&application'
and glbextr_selection = '&selection'
and glbextr_creator_id = '&creator_id'
and glbextr_user_id = '&user_id'
order by spriden_last_name, spriden_first_name;


CURSOR c_fafsa (pidm  spriden.spriden_pidm%type )
IS
SELECT rcrapp4_email_address                     fafsa_email,
       rcrapp4_p_email_address                   fafsa_parent_email,
       rcrapp1_addr                              fafsa_street_address,
       rcrapp1_city                              fafsa_city,
       rcrapp1_stat_code                         fafsa_stat_code,
       rcrapp1_zip                               fafsa_zip
 FROM  rcrapp4,
       rcrapp1
 WHERE rcrapp1_pidm = pidm
   AND rcrapp1_infc_code = 'EDE'
   AND rcrapp1_curr_rec_ind = 'Y'
   AND rcrapp1_aidy_code = '&aidy'
   AND rcrapp4_aidy_code = rcrapp1_aidy_code
   AND rcrapp4_pidm = rcrapp1_pidm
   AND rcrapp4_infc_code = rcrapp1_infc_code
   AND rcrapp4_seq_no = rcrapp1_seq_no;

CURSOR c_mailing (pidm  spriden.spriden_pidm%type )
IS
select spraddr_street_line1                      cm_street_address1,
       spraddr_street_line2                      cm_street_address2,
       spraddr_street_line3                      cm_street_address3,
       spraddr_city                              cm_city,
       spraddr_stat_code                         cm_state,
       spraddr_zip                               cm_zip
from spraddr
where spraddr_pidm = pidm
and spraddr_atyp_code = 'CM'
and spraddr_status_ind is null
and (   (spraddr_to_date is null and
         spraddr_from_date is null)
     or (spraddr_to_date is not null and
         spraddr_from_date is not null and
         sysdate between trunc(spraddr_from_date) and trunc(spraddr_to_date))
     or (spraddr_from_date is not null and spraddr_to_date is null and
         sysdate >= trunc(spraddr_from_date)));


/***************************************************************************************/
/* Variables                                                                           */
/***************************************************************************************/
v_count                               number;

lv_fafsa_email                        rcrapp4.rcrapp4_email_address%type;
lv_fafsa_parent_email                 rcrapp4.rcrapp4_p_email_address%type;
lv_fafsa_street_address               rcrapp1.rcrapp1_addr%type;
lv_fafsa_city                         rcrapp1.rcrapp1_city%type;
lv_fafsa_stat_code                    rcrapp1.rcrapp1_stat_code%type;
lv_fafsa_zip                          rcrapp1.rcrapp1_zip%type;
lv_cm_street_address1                 spraddr.spraddr_street_line1%type;
lv_cm_street_address2                 spraddr.spraddr_street_line2%type;
lv_cm_street_address3                 spraddr.spraddr_street_line3%type;
lv_cm_city                            spraddr.spraddr_city%type;
lv_cm_state                           spraddr.spraddr_stat_code%type;
lv_cm_zip                             spraddr.spraddr_zip%type;

lv_fafsa                              c_fafsa%rowtype;
lv_mailing                            c_mailing%rowtype;

/**************************************************************************************************************************/
BEGIN

dbms_output.put_line ('STUDENT_ID, FIRST_NAME, LAST_NAME, EMAIL, FAFSA_EMAIL, FAFSA_PARENT_EMAIL, FAFSA_STREET_ADDRESS, FAFSA_CITY, FAFSA_STATE, FAFSA_ZIP, '||
                      'CM_STREET_ADDRESS1, CM_STREET_ADDRESS2, CM_STREET_ADDRESS3, CM_CITY, CM_STATE, CM_ZIP');

    v_count := 0;

/**************************************************/
/* Loop through all student jobs for the aid year */
/**************************************************/
FOR v_email IN c_email LOOP

    v_count := v_count + 1;
    
    if c_fafsa%isopen     
    then
     close c_fafsa;
    end if;
    open c_fafsa(v_email.student_pidm);
    fetch c_fafsa into lv_fafsa;
    if c_fafsa%NOTFOUND then
       lv_fafsa_email            := '';
       lv_fafsa_parent_email     := '';
       lv_fafsa_street_address   := '';
       lv_fafsa_city             := '';
       lv_fafsa_stat_code        := '';
       lv_fafsa_zip              := '';    
    else
       lv_fafsa_email            := lv_fafsa.fafsa_email;
       lv_fafsa_parent_email     := lv_fafsa.fafsa_parent_email;
       lv_fafsa_street_address   := lv_fafsa.fafsa_street_address;
       lv_fafsa_city             := lv_fafsa.fafsa_city;
       lv_fafsa_stat_code        := lv_fafsa.fafsa_stat_code;
       lv_fafsa_zip              := lv_fafsa.fafsa_zip;
    end if;
    close c_fafsa;
    
    if c_mailing%isopen     
    then
     close c_mailing;
    end if;	  
    open c_mailing(v_email.student_pidm);
    fetch c_mailing into lv_mailing;
    if c_mailing%NOTFOUND then
       lv_cm_street_address1 := '';
       lv_cm_street_address2 := '';
       lv_cm_street_address3 := '';
       lv_cm_city            := '';
       lv_cm_state           := '';
       lv_cm_zip             := '';
    else
       lv_cm_street_address1 := lv_mailing.cm_street_address1;
       lv_cm_street_address2 := lv_mailing.cm_street_address2;
       lv_cm_street_address3 := lv_mailing.cm_street_address3;
       lv_cm_city            := lv_mailing.cm_city;
       lv_cm_state           := lv_mailing.cm_state;
       lv_cm_zip             := lv_mailing.cm_zip;
    end if;
    close c_mailing;
    
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
    (v_email.student_pidm,
    'R',
    'R',
    'FAGEN',
    SYSDATE,
    SYSDATE,
    USER,
    '&aidy',
    'S',
    'G',
    SYSDATE); 
    
    dbms_output.put_line ('"'||v_email.student_id ||'",'||
                          '"'||v_email.first_name ||'",'||
                          '"'||v_email.last_name ||'",'||
                          '"'||v_email.email ||'",'||
                          '"'||lv_fafsa_email ||'",'||
                          '"'||lv_fafsa_parent_email ||'",'||
                          '"'||lv_fafsa_street_address ||'",'||
                          '"'||lv_fafsa_city ||'",'||
                          '"'||lv_fafsa_stat_code ||'",'||
                          '"'||lv_fafsa_zip ||'",'||
                          '"'||lv_cm_street_address1 ||'",'||
                          '"'||lv_cm_street_address2 ||'",'||
                          '"'||lv_cm_street_address3 ||'",'||
                          '"'||lv_cm_city ||'",'||
                          '"'||lv_cm_state ||'",'||
                          '"'||lv_cm_zip||'"' );

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
