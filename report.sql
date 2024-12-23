SET SERVEROUTPUT ON;
BEGIN
    -- ------------------------------------------------------------
    -- 1. DATABASE INSTANCE DETAILS
    -- ------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('DATABASE INSTANCE DETAILS');
    DBMS_OUTPUT.PUT_LINE('============================================================');

    FOR rec IN (
        SELECT
            inst_id,
            instance_name,
            host_name,
            version,
            status,
            parallel,
            TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
        FROM gv$instance
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('Instance ID     : ' || rec.inst_id);
        DBMS_OUTPUT.PUT_LINE('Instance Name   : ' || rec.instance_name);
        DBMS_OUTPUT.PUT_LINE('Host Name       : ' || rec.host_name);
        DBMS_OUTPUT.PUT_LINE('Version         : ' || rec.version);
        DBMS_OUTPUT.PUT_LINE('Status          : ' || rec.status);
        DBMS_OUTPUT.PUT_LINE('Parallel        : ' || rec.parallel);
        DBMS_OUTPUT.PUT_LINE('Startup Time    : ' || rec.startup_time);
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    END LOOP;


    -- ------------------------------------------------------------
    -- 2. ACTIVE SESSIONS (CURRENT LOAD)
    -- ------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('ACTIVE SESSIONS');
    DBMS_OUTPUT.PUT_LINE('============================================================');

    FOR rec IN (
        SELECT COUNT(*) AS active_sessions
        FROM gv$session
        WHERE status = 'ACTIVE'
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('Active Sessions : ' || rec.active_sessions);
    END LOOP;


    -- ------------------------------------------------------------
    -- 3. TOP WAIT EVENTS (EXCLUDING IDLE)
    -- ------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('TOP WAIT EVENTS');
    DBMS_OUTPUT.PUT_LINE('============================================================');

    FOR rec IN (
        SELECT
            event,
            total_waits,
            time_waited_micro / 1000000 AS time_waited_sec,
            average_wait / 1000        AS avg_wait_ms,
            wait_class
        FROM v$system_event
        WHERE wait_class != 'Idle'
        ORDER BY time_waited_micro DESC
        FETCH FIRST 10 ROWS ONLY     -- For Oracle 12c and above
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('Event               : ' || rec.event);
        DBMS_OUTPUT.PUT_LINE('  Total Waits       : ' || rec.total_waits);
        DBMS_OUTPUT.PUT_LINE('  Time Waited (sec) : ' || rec.time_waited_sec);
        DBMS_OUTPUT.PUT_LINE('  Avg Wait (ms)     : ' || rec.avg_wait_ms);
        DBMS_OUTPUT.PUT_LINE('  Wait Class        : ' || rec.wait_class);
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    END LOOP;


    -- ------------------------------------------------------------
    -- 4. TOP SQL BY CPU USAGE
    -- ------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('TOP SQL BY CPU USAGE');
    DBMS_OUTPUT.PUT_LINE('============================================================');

    FOR rec IN (
        SELECT
            sql_id,
            plan_hash_value,
            elapsed_time / 1000000 AS elapsed_time_sec,
            cpu_time     / 1000000 AS cpu_time_sec,
            buffer_gets,
            disk_reads,
            executions,
            SUBSTR(sql_text, 1, 100) AS sql_text
        FROM v$sql
        WHERE elapsed_time > 0
        ORDER BY cpu_time DESC
        FETCH FIRST 10 ROWS ONLY     -- For Oracle 12c and above
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('SQL ID            : ' || rec.sql_id);
        DBMS_OUTPUT.PUT_LINE('  Plan Hash       : ' || rec.plan_hash_value);
        DBMS_OUTPUT.PUT_LINE('  Elapsed Time(s) : ' || rec.elapsed_time_sec);
        DBMS_OUTPUT.PUT_LINE('  CPU Time (s)    : ' || rec.cpu_time_sec);
        DBMS_OUTPUT.PUT_LINE('  Buffer Gets     : ' || rec.buffer_gets);
        DBMS_OUTPUT.PUT_LINE('  Disk Reads      : ' || rec.disk_reads);
        DBMS_OUTPUT.PUT_LINE('  Executions      : ' || rec.executions);
        DBMS_OUTPUT.PUT_LINE('  SQL Text        : ' || rec.sql_text);
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    END LOOP;


    -- ------------------------------------------------------------
    -- 5. I/O PERFORMANCE METRICS
    -- ------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('I/O PERFORMANCE METRICS');
    DBMS_OUTPUT.PUT_LINE('============================================================');

    FOR rec IN (
        SELECT
            f.file_id,
            f.tablespace_name,
            fs.phyrds               AS physical_reads,
            fs.phywrts              AS physical_writes,
            fs.readtim  / 100       AS read_time_ms,
            fs.writetim / 100       AS write_time_ms
        FROM v$filestat fs
        JOIN dba_data_files f
          ON f.file_id = fs.file#
        ORDER BY fs.phyrds DESC
        FETCH FIRST 10 ROWS ONLY     -- For Oracle 12c and above
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('File ID            : ' || rec.file_id);
        DBMS_OUTPUT.PUT_LINE('  Tablespace       : ' || rec.tablespace_name);
        DBMS_OUTPUT.PUT_LINE('  Physical Reads   : ' || rec.physical_reads);
        DBMS_OUTPUT.PUT_LINE('  Physical Writes  : ' || rec.physical_writes);
        DBMS_OUTPUT.PUT_LINE('  Read Time (ms)   : ' || rec.read_time_ms);
        DBMS_OUTPUT.PUT_LINE('  Write Time (ms)  : ' || rec.write_time_ms);
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    END LOOP;


    -- ------------------------------------------------------------
    -- 6. SYSTEM RESOURCE USAGE
    -- ------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('SYSTEM RESOURCE USAGE');
    DBMS_OUTPUT.PUT_LINE('============================================================');

    FOR rec IN (
        SELECT
            resource_name,
            current_utilization,
            max_utilization,
            limit_value
        FROM v$resource_limit
        ORDER BY resource_name
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE('Resource            : ' || rec.resource_name);
        DBMS_OUTPUT.PUT_LINE('  Current Util.     : ' || rec.current_utilization);
        DBMS_OUTPUT.PUT_LINE('  Max Util.         : ' || rec.max_utilization);
        DBMS_OUTPUT.PUT_LINE('  Limit             : ' || rec.limit_value);
        DBMS_OUTPUT.PUT_LINE('------------------------------------------------------------');
    END LOOP;

END;
/
