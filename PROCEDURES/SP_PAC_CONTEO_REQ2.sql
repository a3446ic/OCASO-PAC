CREATE OR REPLACE PROCEDURE EXT.SP_PAC_CONTEO_REQ2 (IN i_file_name varchar(120))
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 17/04/2026
    |----------------------------------------------------------------------
    | Procedure Purpose: Por cada póliza que aparezca en el fichero y el número de transacciones a marcar que se informará en el fichero
    |
    | Version: 0.1  SMM 20260331    Initial Version.
    |
    -----------------------------------------------------------------------
*/

BEGIN
	
	USING SQLSCRIPT_STRING AS LIBRARY;
	
	DECLARE v_id_proceso INTEGER;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '0.1';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	DECLARE v_periodseq BIGINT;
	DECLARE v_PeriodName VARCHAR(25);
	DECLARE v_file_name VARCHAR(250) = 'PAC_CONTEO_REQ2_';
	DECLARE v_const_processingunitseq BIGINT = 38280596832649217;
	DECLARE v_const_credito VARCHAR(50) = 'DC-O-GEN-Inspector-PrimaCorregida-998';
	DECLARE v_const_medida VARCHAR(50) = 'SM-O-GEN-Inspector-NumeroPolizas-998-Extornar-S5';
	DECLARE v_const_out_batch_control_load INT = EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_LOAD; --1
	DECLARE v_const_out_batch_control_ok INT := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_OK; --2
	DECLARE v_const_out_batch_control_error INT := EXT.LIB_CONSTANTES:CONST_OUT_BATCH_CONTROL_ERROR; --3
	
	BEGIN
	
		DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
			CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name , 'Error en procedimiento principal ' || proc_name || ' - SQL_ERROR_MESSAGE: ' || IFNULL(::SQL_ERROR_MESSAGE,'')
																												|| '. SQL_ERROR_CODE: ' || ::SQL_ERROR_CODE, v_log_count, v_id_proceso, 'error');
			--v_hayError := 1;
			v_num_rows := 0;
		
		UPDATE EXT.OUT_BATCH_CONTROL
		SET STATUS = v_const_out_batch_control_error,
			END_DATE = CURRENT_TIMESTAMP
		WHERE COALESCE(FILE_NAME,'') = COALESCE(v_file_name,'')
			AND ID_PROCESO = v_id_proceso;
			
			COMMIT;
			
			RESIGNAL;
		END;
	
	--Inicializamos el idProceso
		-- SELECT EXT.ID_PROCESO.NEXTVAL INTO v_id_proceso FROM DUMMY;
		SELECT 0 INTO v_id_proceso FROM DUMMY;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for plRunseq ' || v_file_name, v_log_count, v_id_proceso, 'info');
	
		-- SELECCIONAMOS PERIODSEQ
		-- SELECT PERIODSEQ, NAME INTO v_PeriodSeq, v_PeriodName FROM EXT.LIB_GLOBAL:getPeriodRow(v_idTenant, i_pPlRunSeq);
		
		-- FICHERO DE SALIDA
		SELECT v_file_name||TO_VARCHAR(CURRENT_DATE, 'YYYYMMDD')||'_'||TO_VARCHAR(ADD_SECONDS(CURRENT_TIME, 7200), 'HH24MISS')||'.txt' INTO v_file_name from dummy;
		
		-- CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Parametros: v_PeriodSeq: ' || v_PeriodSeq || ' - v_PeriodName: ' || v_PeriodName || ' - v_file_name ' || v_file_name, v_log_count, v_id_proceso, 'info');
		
		
	
		INSERT INTO EXT.OUT_BATCH_CONTROL(ID_PROCESO,FILE_NAME,PROCEDURE_NAME,TARGET_ROWS,STATUS,START_DATE,END_DATE)
		VALUES (v_id_proceso, v_file_name, ::CURRENT_OBJECT_NAME, v_num_rows, :v_const_out_batch_control_load, CURRENT_TIMESTAMP,NULL);
		/*
		DELETE FROM EXT.OUT_PAC_CONTEO_REQ1_FILE WHERE PERIODSEQ = v_periodseq;
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Borrar en OUT_PAC_CONTEO_REQ1_FILE. Filas: ' || ::rowcount, v_log_count, v_id_proceso, 'info');
		
		
		SELECT SO.ORDERID,ST.LINENUMBER,ST.SUBLINENUMBER,E.EVENTTYPEID,SUBSTR(SO.ORDERID,8,16) POLIZA, 0 CONTEO, v_periodseq,M.*
		FROM TCMP.CS_CREDIT C
		INNER JOIN TCMP.CS_SALESTRANSACTION ST ON C.SALESTRANSACTIONSEQ = ST.SALESTRANSACTIONSEQ
			AND ST.TENANTID = v_idtenant
		INNER JOIN TCMP.CS_SALESORDER SO ON SO.SALESORDERSEQ = ST.SALESORDERSEQ 
			AND SO.TENANTID = v_idtenant 
			AND SO.PROCESSINGUNITSEQ = v_const_processingunitseq 
			AND SO.REMOVEDATE = v_eot 
			AND SO.ORDERID IS NOT NULL
		INNER JOIN TCMP.CS_EVENTTYPE E ON E.DATATYPESEQ = ST.EVENTTYPESEQ
			AND E.TENANTID = v_idtenant 
			AND E.REMOVEDATE = v_eot
		-- TRANSACCIONES AJUSTADAS MANUALMENTE ¿?
		-- INNER JOIN TCMP.CS_TRANSACTIONADJUSTMENT TA ON TA.SALESTRANSACTIONSEQ = ST.SALESTRANSACTIONSEQ
		INNER JOIN TCMP.CS_PMCREDITTRACE PMC ON C.CREDITSEQ = PMC.CREDITSEQ
		        AND PMC.TENANTID = v_idtenant
		INNER JOIN TCMP.CS_MEASUREMENT M ON M.MEASUREMENTSEQ = PMC.MEASUREMENTSEQ
		        AND M.TENANTID = v_idtenant 
		        AND M.PERIODSEQ = v_PeriodSeq
		      --  AND M.NAME = v_const_medida
		WHERE C.PERIODSEQ = v_PeriodSeq
		AND C.NAME = v_const_credito
		AND C.PROCESSINGUNITSEQ = v_const_processingunitseq
		AND C.TENANTID = v_idtenant
		;
		
		
		INSERT INTO EXT.OUT_PAC_CONTEO_REQ1_FILE(ORDERID,LINENUMBER,SUBLINENUMBER,EVENTTYPEID,POLIZA,CONTEO,PERIODSEQ)
		SELECT SO.ORDERID,ST.LINENUMBER,ST.SUBLINENUMBER,E.EVENTTYPEID,SUBSTR(SO.ORDERID,8,16) POLIZA, 0 CONTEO, v_periodseq
		FROM TCMP.CS_CREDIT C
		INNER JOIN TCMP.CS_SALESTRANSACTION ST ON C.SALESTRANSACTIONSEQ = ST.SALESTRANSACTIONSEQ
			AND ST.TENANTID = v_idtenant
		INNER JOIN TCMP.CS_SALESORDER SO ON SO.SALESORDERSEQ = ST.SALESORDERSEQ 
			AND SO.TENANTID = v_idtenant 
			AND SO.PROCESSINGUNITSEQ = v_const_processingunitseq 
			AND SO.REMOVEDATE = v_eot 
			AND SO.ORDERID IS NOT NULL
		INNER JOIN TCMP.CS_EVENTTYPE E ON E.DATATYPESEQ = ST.EVENTTYPESEQ
			AND E.TENANTID = v_idtenant 
			AND E.REMOVEDATE = v_eot
		-- TRANSACCIONES AJUSTADAS MANUALMENTE ¿?
		-- INNER JOIN TCMP.CS_TRANSACTIONADJUSTMENT TA ON TA.SALESTRANSACTIONSEQ = ST.SALESTRANSACTIONSEQ
		INNER JOIN TCMP.CS_PMCREDITTRACE PMC ON C.CREDITSEQ = PMC.CREDITSEQ
		        AND PMC.TENANTID = v_idtenant
		INNER JOIN TCMP.CS_MEASUREMENT M ON M.MEASUREMENTSEQ = PMC.MEASUREMENTSEQ
		        AND M.TENANTID = v_idtenant 
		        AND M.PERIODSEQ = v_PeriodSeq
		WHERE C.PERIODSEQ = v_PeriodSeq
		AND C.NAME = v_const_credito
		AND C.PROCESSINGUNITSEQ = v_const_processingunitseq
		AND C.TENANTID = v_idtenant
		;
		
		v_num_rows = ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT en OUT_PAC_CONTEO_REQ1_FILE. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		
		
		*/
		
		UPDATE EXT.OUT_BATCH_CONTROL SET STATUS = :v_const_out_batch_control_ok, TARGET_ROWS =v_num_rows, END_DATE = CURRENT_TIMESTAMP WHERE FILE_NAME = v_file_name AND ID_PROCESO = v_id_proceso;
		
		CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log,proc_name, 'Fin procesamiento del fichero ' || v_file_name, v_log_count, v_id_proceso, 'info');
		
	END;
		
END;

DO BEGIN
	DECLARE v_file_name VARCHAR(250) = 'PRUEBA.TXT';
	DECLARE PLRUNSEQ BIGINT = 20547673299945597;
	
	
	DELETE FROM EXT.CSE_LOG WHERE CAST(DATETIME AS DATE) = CURRENT_DATE
	AND OBJECT LIKE '%SP_PAC_CONTEO_REQ2%';
	
	CALL EXT.SP_PAC_CONTEO_REQ2(v_file_name);
	
	SELECT * FROM EXT.CSE_LOG WHERE CAST(DATETIME AS DATE) = CURRENT_DATE
	AND OBJECT LIKE '%SP_PAC_CONTEO_REQ2%';
	
	-- SELECT * FROM CS_PLRUN R INNER JOIN CS_PERIOD C ON R.PERIODSEQ = C.PERIODSEQ AND C.NAME = 'Marzo 2026';
	
	SELECT COUNT(*) FROM EXT.OUT_PAC_CONTEO_REQ2_FILE_LOAD;
END;
