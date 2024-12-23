SET SERVEROUTPUT ON;
BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('      ORACLE DATABASE LOAD & PERFORMANCE REPORT');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('');

    -----------------------------------------------------------------------
    -- 1. INSTANCE & HOST INFORMATION
    -----------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('1. INSTANCE & HOST INFORMATION');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------');

    FOR rec IN (
        SELECT inst_id,
               instance_name,
               host_name,
               version,
               status,
               parallel,
               TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
        FROM gv$instance
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE(' Instance ID      : ' || rec.inst_id);
        DBMS_OUTPUT.PUT_LINE(' Instance Name    : ' || rec.instance_name);
        DBMS_OUTPUT.PUT_LINE(' Host Name        : ' || rec.host_name);
        DBMS_OUTPUT.PUT_LINE(' DB Version       : ' || rec.version);
        DBMS_OUTPUT.PUT_LINE(' Status           : ' || rec.status);
        DBMS_OUTPUT.PUT_LINE(' Parallel Support : ' || rec.parallel);
        DBMS_OUTPUT.PUT_LINE(' Startup Time     : ' || rec.startup_time);
        DBMS_OUTPUT.PUT_LINE('--------------------------------------');
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');

    -----------------------------------------------------------------------
    -- 2. ACTIVE SESSIONS (INDICATES CURRENT LOAD)
    -----------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('2. ACTIVE SESSIONS (CURRENT LOAD)');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------');

    FOR rec IN (
        SELECT COUNT(*) AS active_sessions
        FROM gv$session
        WHERE status = 'ACTIVE'
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE(' Active Sessions   : ' || rec.active_sessions);
        DBMS_OUTPUT.PUT_LINE(' (Higher number often indicates heavier load.)');
        DBMS_OUTPUT.PUT_LINE('--------------------------------------');
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('');

    -----------------------------------------------------------------------
    -- 3. CPU & OS STATS (Optional Check)
    --    Note: Not all systems grant access to v$osstat
    -----------------------------------------------------------------------
    BEGIN
        DBMS_OUTPUT.PUT_LINE('3. CPU & OS STATS');
        DBMS_OUTPUT.PUT_LINE('--------------------------------------');

        FOR rec IN (
            SELECT stat_name,
                   value
            FROM v$osstat
            WHERE stat_name IN ('NUM_CPUS','LOAD','BUSY_TIME','IDLE_TIME')
        )
        LOOP
            DBMS_OUTPUT.PUT_LINE(' ' || rec.stat_name || ' : ' || rec.value);
        END LOOP;
        DBMS_OUTPUT.PUT_LINE(' (Compare LOAD vs. NUM_CPUS; if LOAD >> NUM_CPUS, CPU may be saturated.)');
        DBMS_OUTPUT.PUT_LINE('--------------------------------------');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(' *Could not retrieve OS stats (lack of privileges on v$osstat).');
    END;
    
    DBMS_OUTPUT.PUT_LINE('');

    -----------------------------------------------------------------------
    -- 4. TOP WAIT EVENTS (EXCLUDING IDLE)
    -----------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('4. TOP WAIT EVENTS (EXCLUDING IDLE)');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------');

    FOR rec IN (
        SELECT
            event,
            total_waits,
            time_waited_micro / 1e6 AS time_waited_sec,
            average_wait / 1e3      AS avg_wait_ms,
            wait_class
        FROM v$system_event
        WHERE wait_class != 'Idle'
        ORDER BY time_waited_micro DESC
        FETCH FIRST 10 ROWS ONLY   -- Replace with: AND ROWNUM <= 10 if <12c
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE(' Event               : ' || rec.event);
        DBMS_OUTPUT.PUT_LINE('   Total Waits       : ' || rec.total_waits);
        DBMS_OUTPUT.PUT_LINE('   Time Waited (sec) : ' || rec.time_waited_sec);
        DBMS_OUTPUT.PUT_LINE('   Avg Wait (ms)     : ' || rec.avg_wait_ms);
        DBMS_OUTPUT.PUT_LINE('   Wait Class        : ' || rec.wait_class);
        DBMS_OUTPUT.PUT_LINE('--------------------------------------');
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE(' (High wait times in non-idle events => system stress.)');
    DBMS_OUTPUT.PUT_LINE('');

    -----------------------------------------------------------------------
    -- 5. TOP SQL BY CPU USAGE
    -----------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('5. TOP SQL BY CPU USAGE');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------');

    FOR rec IN (
        SELECT
            sql_id,
            plan_hash_value,
            cpu_time / 1e6      AS cpu_time_sec,
            elapsed_time / 1e6  AS elapsed_time_sec,
            buffer_gets,
            disk_reads,
            executions,
            SUBSTR(sql_text, 1, 100) AS sql_text
        FROM v$sql
        WHERE elapsed_time > 0
        ORDER BY cpu_time DESC
        FETCH FIRST 10 ROWS ONLY   -- Replace with: AND ROWNUM <= 10 if <12c
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE(' SQL ID          : ' || rec.sql_id);
        DBMS_OUTPUT.PUT_LINE('   Plan Hash     : ' || rec.plan_hash_value);
        DBMS_OUTPUT.PUT_LINE('   CPU Time (s)  : ' || rec.cpu_time_sec);
        DBMS_OUTPUT.PUT_LINE('   Elapsed Time  : ' || rec.elapsed_time_sec);
        DBMS_OUTPUT.PUT_LINE('   Buffer Gets   : ' || rec.buffer_gets);
        DBMS_OUTPUT.PUT_LINE('   Disk Reads    : ' || rec.disk_reads);
        DBMS_OUTPUT.PUT_LINE('   Executions    : ' || rec.executions);
        DBMS_OUTPUT.PUT_LINE('   SQL Text      : ' || rec.sql_text);
        DBMS_OUTPUT.PUT_LINE('--------------------------------------');
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(' (These SQLs may be heavy contributors to load.)');
    DBMS_OUTPUT.PUT_LINE('');

    -----------------------------------------------------------------------
    -- 6. I/O PERFORMANCE METRICS
    -----------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('6. I/O PERFORMANCE METRICS');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------');

    FOR rec IN (
        SELECT
            f.file_id,
            f.tablespace_name,
            fs.phyrds                      AS physical_reads,
            fs.phywrts                     AS physical_writes,
            ROUND(fs.readtim / 100, 2)     AS read_time_ms,
            ROUND(fs.writetim / 100, 2)    AS write_time_ms
        FROM v$filestat fs
        JOIN dba_data_files f
          ON f.file_id = fs.file#
        ORDER BY fs.phyrds DESC
        FETCH FIRST 10 ROWS ONLY   -- Replace with: AND ROWNUM <= 10 if <12c
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE(' File ID          : ' || rec.file_id);
        DBMS_OUTPUT.PUT_LINE('   Tablespace     : ' || rec.tablespace_name);
        DBMS_OUTPUT.PUT_LINE('   Physical Reads : ' || rec.physical_reads);
        DBMS_OUTPUT.PUT_LINE('   Physical Writes: ' || rec.physical_writes);
        DBMS_OUTPUT.PUT_LINE('   Read Time (ms) : ' || rec.read_time_ms);
        DBMS_OUTPUT.PUT_LINE('   Write Time(ms) : ' || rec.write_time_ms);
        DBMS_OUTPUT.PUT_LINE('--------------------------------------');
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(' (High reads/writes or read/write times => potential I/O bottleneck.)');
    DBMS_OUTPUT.PUT_LINE('');

    -----------------------------------------------------------------------
    -- 7. BLOCKING / LOCKED SESSIONS (OPTIONAL)
    -----------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('7. BLOCKING / LOCKED SESSIONS');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------');

    FOR rec IN (
        SELECT blocking_session,
               sid AS blocked_session,
               wait_class,
               event,
               seconds_in_wait
        FROM gv$session
        WHERE blocking_session IS NOT NULL
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE(' Blocked Session   : ' || rec.blocked_session);
        DBMS_OUTPUT.PUT_LINE('   Blocking Session: ' || rec.blocking_session);
        DBMS_OUTPUT.PUT_LINE('   Wait Class      : ' || rec.wait_class);
        DBMS_OUTPUT.PUT_LINE('   Event           : ' || rec.event);
        DBMS_OUTPUT.PUT_LINE('   Seconds in Wait : ' || rec.seconds_in_wait);
        DBMS_OUTPUT.PUT_LINE('--------------------------------------');
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(' (Any rows here => concurrency issues that can increase load.)');
    DBMS_OUTPUT.PUT_LINE('');

    -----------------------------------------------------------------------
    -- 8. SYSTEM RESOURCE USAGE
    -----------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('8. SYSTEM RESOURCE USAGE');
    DBMS_OUTPUT.PUT_LINE('--------------------------------------');

    FOR rec IN (
        SELECT resource_name,
               current_utilization,
               max_utilization,
               limit_value
        FROM v$resource_limit
        ORDER BY resource_name
    )
    LOOP
        DBMS_OUTPUT.PUT_LINE(' Resource            : ' || rec.resource_name);
        DBMS_OUTPUT.PUT_LINE('   Current Util.     : ' || rec.current_utilization);
        DBMS_OUTPUT.PUT_LINE('   Max Util.         : ' || rec.max_utilization);
        DBMS_OUTPUT.PUT_LINE('   Limit Value       : ' || rec.limit_value);
        DBMS_OUTPUT.PUT_LINE('--------------------------------------');
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(' (Approaching limits => potential load or capacity issue.)');
    DBMS_OUTPUT.PUT_LINE('');

    -----------------------------------------------------------------------
    -- REPORT END
    -----------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('END OF ORACLE DATABASE LOAD & PERFORMANCE REPORT');
    DBMS_OUTPUT.PUT_LINE('============================================================');
END;
/
