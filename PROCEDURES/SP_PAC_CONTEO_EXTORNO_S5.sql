CREATE OR REPLACE PROCEDURE EXT.SP_PAC_CONTEO_EXTORNO_S5 (OUT FILENAME VARCHAR(120) , IN i_pPlRunSeq VARCHAR(50))
LANGUAGE SQLSCRIPT 
SQL SECURITY INVOKER 
DEFAULT SCHEMA EXT AS

/*---------------------------------------------------------------------
    | Author: Samuel Miralles Manresa
    | Company: Inycom
    | Initial Version Date: 31/03/2026
    |----------------------------------------------------------------------
    | Procedure Purpose: Extracción de datos a fichero a partir de los resultados generados por el crédito DC-O-GEN-Inspector-PrimaCorregida-998 y una medida
    |
    | Version: 0.1  SMM 20260331    Initial Version.
    | Version: 0.2  SMM 20260422    Cambiada información fichero. Mostrar POSITIONNAME,CONTEO
    | Version: 1.0  SMM 20260521    Cambio de nombre procedimiento y fichero de salida
    |
    -----------------------------------------------------------------------
*/

BEGIN
	
	USING SQLSCRIPT_STRING AS LIBRARY;
	
	DECLARE v_id_proceso INTEGER;
	DECLARE proc_name VARCHAR2(50) := ::CURRENT_OBJECT_SCHEMA ||'.'|| ::CURRENT_OBJECT_NAME;
	DECLARE v_version VARCHAR2(10) := '1.0';
	DECLARE v_num_rows INTEGER := 0;
	DECLARE v_log_count INTEGER := 0;
	DECLARE v_permisos_log VARCHAR(50) := EXT.LIB_GLOBAL:GET_PERMISOS_LOG();
	DECLARE v_idtenant VARCHAR(50) := EXT.LIB_GLOBAL:getTenantID();
	DECLARE v_eot DATE := EXT.LIB_CONSTANTES:v_eot;
	DECLARE v_periodseq BIGINT;
	DECLARE v_PeriodName VARCHAR(25);
	DECLARE v_file_name VARCHAR(250) = 'CONTEO_EXTORNOS_S5';
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
			
			v_num_rows := 0;
		
		UPDATE EXT.OUT_BATCH_CONTROL
		SET STATUS = v_const_out_batch_control_error,
			END_DATE = CURRENT_TIMESTAMP
		WHERE COALESCE(FILE_NAME,'') = COALESCE(FILENAME,'')
			AND ID_PROCESO = v_id_proceso;
			
			COMMIT;
			
			RESIGNAL;
		END;
	
	--Inicializamos el idProceso
		SELECT EXT.ID_PROCESO.NEXTVAL INTO v_id_proceso FROM DUMMY;
		
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Version: ' || v_version || ' - Procedure starting for plRunseq ' || i_pPlRunSeq, v_log_count, v_id_proceso, 'info');
	
		-- SELECCIONAMOS PERIODSEQ
		SELECT PERIODSEQ, NAME INTO v_PeriodSeq, v_PeriodName FROM EXT.LIB_GLOBAL:getPeriodRow(v_idTenant, i_pPlRunSeq);
		
		-- FICHERO DE SALIDA
		SELECT v_file_name||TO_VARCHAR(CURRENT_DATE, 'YYYYMMDD')||'_'||TO_VARCHAR(ADD_SECONDS(CURRENT_TIME, 7200), 'HH24MISS')||'.txt' INTO FILENAME from dummy;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Parametros: v_PeriodSeq: ' || v_PeriodSeq || ' - v_PeriodName: ' || v_PeriodName || ' - FILENAME ' || FILENAME, v_log_count, v_id_proceso, 'info');
		
		
	
		INSERT INTO EXT.OUT_BATCH_CONTROL(ID_PROCESO,FILE_NAME,PROCEDURE_NAME,TARGET_ROWS,STATUS,START_DATE,END_DATE)
		VALUES (v_id_proceso, FILENAME, ::CURRENT_OBJECT_NAME, v_num_rows, :v_const_out_batch_control_load, CURRENT_TIMESTAMP,NULL);
		
		TRUNCATE TABLE EXT.OUT_PAC_CONTEO_EXTORNO_S5_FILE;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Borrar en OUT_PAC_CONTEO_EXTORNO_S5_FILE. Filas: ' || ::rowcount, v_log_count, v_id_proceso, 'info');
		
		
		INSERT INTO EXT.OUT_PAC_CONTEO_EXTORNO_S5_FILE(PERIODSEQ,POSITIONNAME,CONTEO)
		SELECT v_periodseq,P.NAME,M.VALUE 
		FROM CS_MEASUREMENT M 
		INNER JOIN CS_POSITION P ON M.POSITIONSEQ = P.RULEELEMENTOWNERSEQ
		WHERE M.NAME = v_const_medida
		AND M.TENANTID = v_idtenant
		AND P.TENANTID = v_idtenant
		AND M.PERIODSEQ = v_periodseq 
		AND P.REMOVEDATE = v_eot
		AND P.ISLAST = 1
		ORDER BY VALUE DESC;
		
		
		v_num_rows = ::rowcount;
		
		CALL LIB_GLOBAL:WRITE_LOG (v_permisos_log, proc_name, 'Fin INSERT en OUT_PAC_CONTEO_EXTORNO_S5_FILE. Filas: ' || v_num_rows, v_log_count, v_id_proceso, 'info');
		
	
		
		
		UPDATE EXT.OUT_BATCH_CONTROL SET STATUS = :v_const_out_batch_control_ok, TARGET_ROWS =v_num_rows, END_DATE = CURRENT_TIMESTAMP WHERE FILE_NAME = FILENAME AND ID_PROCESO = v_id_proceso;
		
		CALL EXT.LIB_GLOBAL:WRITE_LOG (v_permisos_log,proc_name, 'Fin procesamiento del fichero ' || FILENAME, v_log_count, v_id_proceso, 'info');
		
	END;
		
END;

DO BEGIN
	DECLARE FILENAME VARCHAR(250) = 'PRUEBA.TXT';
	DECLARE PLRUNSEQ BIGINT = 20547673299945874;
	
	
	DELETE FROM EXT.CSE_LOG WHERE CAST(DATETIME AS DATE) = CURRENT_DATE
	AND OBJECT LIKE '%SP_PAC_CONTEO_EXTORNO_S5%';
	
	 CALL EXT.SP_PAC_CONTEO_EXTORNO_S5(FILENAME,PLRUNSEQ);
	
	SELECT * FROM EXT.CSE_LOG WHERE CAST(DATETIME AS DATE) = CURRENT_DATE
	AND OBJECT LIKE '%SP_PAC_CONTEO_EXTORNO_S5%';
	
	-- SELECT * FROM CS_PLRUN R INNER JOIN CS_PERIOD C ON R.PERIODSEQ = C.PERIODSEQ AND C.NAME = 'Marzo 2026';
-- SELECT * FROM EXT.OUT_PAC_CONTEO_EXTORNO_S5_FILE ORDER BY CONTEO DESC,POSITIONNAME;
END;

