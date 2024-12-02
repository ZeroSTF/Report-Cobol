IDENTIFICATION DIVISION.
PROGRAM-ID. ENHANCED-EMPLOYEE-REPORT.
ENVIRONMENT DIVISION.
INPUT-OUTPUT SECTION.
FILE-CONTROL.
    SELECT EMPLOYEE-FILE ASSIGN TO DYNAMIC WS-EMPLOYEE-FILENAME
        ORGANIZATION IS LINE SEQUENTIAL.
    SELECT REPORT-FILE ASSIGN TO DYNAMIC WS-REPORT-FILENAME
        ORGANIZATION IS LINE SEQUENTIAL.
    SELECT CONFIG-FILE ASSIGN TO "config.txt"
        ORGANIZATION IS LINE SEQUENTIAL.
DATA DIVISION.
FILE SECTION.
FD EMPLOYEE-FILE.
01 EMPLOYEE-RECORD.
    05 EMP-ID              PIC 9(5).
    05 EMP-NAME            PIC X(30).
    05 EMP-POSITION        PIC X(20).
    05 EMP-SALARY          PIC 9(7)V99.
    05 EMP-DEPARTMENT      PIC X(20).
    05 EMP-HIRE-DATE       PIC X(10).
FD REPORT-FILE.
01 REPORT-LINE             PIC X(132).
FD CONFIG-FILE.
01 CONFIG-RECORD.
    05 CONFIG-KEY          PIC X(20).
    05 CONFIG-VALUE        PIC X(50).
WORKING-STORAGE SECTION.
01 WS-EOF                  PIC X VALUE 'N'.
01 WS-EMPLOYEE-FILENAME    PIC X(50).
01 WS-REPORT-FILENAME      PIC X(50).
01 WS-TOTAL-SALARY         PIC 9(11)V99 VALUE 0.
01 WS-EMPLOYEE-COUNT       PIC 9(5) VALUE 0.
01 WS-AVG-SALARY           PIC 9(7)V99.
01 WS-MEDIAN-SALARY        PIC 9(7)V99.
01 WS-HIGHEST-SALARY       PIC 9(7)V99 VALUE 0.
01 WS-LOWEST-SALARY        PIC 9(7)V99 VALUE 9999999.99.
01 WS-SALARY-STDEV         PIC 9(7)V99.
01 WS-DEPARTMENT-TOTALS.
    05 WS-DEPT OCCURS 20 TIMES INDEXED BY WS-DEPT-IDX.
        10 WS-DEPT-NAME    PIC X(20).
        10 WS-DEPT-COUNT   PIC 9(5) VALUE 0.
        10 WS-DEPT-SALARY  PIC 9(11)V99 VALUE 0.
01 WS-CURRENT-DATE.
    05 WS-YEAR             PIC 9(4).
    05 WS-MONTH            PIC 99.
    05 WS-DAY              PIC 99.
01 WS-HEADING.
    05 FILLER              PIC X(20) VALUE "EMPLOYEE REPORT AS OF".
    05 WS-HEADING-DATE     PIC X(10).
01 WS-ERROR-MESSAGE        PIC X(50).
01 WS-SALARY-ARRAY.
    05 WS-SALARY OCCURS 1000 TIMES INDEXED BY WS-SALARY-IDX
                           PIC 9(7)V99.
01 WS-TEMP-SALARY          PIC 9(7)V99.
01 WS-SORT-OPTION          PIC 9.
01 WS-VALID-DATE           PIC 9 VALUE 0.
01 WS-CONFIG-EOF           PIC X VALUE 'N'.
01 WS-MAX-SALARY           PIC 9(7)V99.
01 WS-MIN-SALARY           PIC 9(7)V99.

PROCEDURE DIVISION.
MAIN-PROCEDURE.
    PERFORM INITIALIZE-PROGRAM
    PERFORM OPEN-FILES
    PERFORM INITIALIZE-REPORT
    PERFORM PROCESS-RECORDS UNTIL WS-EOF = 'Y'
    PERFORM SORT-EMPLOYEES
    PERFORM CALCULATE-STATISTICS
    PERFORM WRITE-REPORT
    PERFORM CLOSE-FILES
    STOP RUN.

INITIALIZE-PROGRAM.
    PERFORM READ-CONFIG
    PERFORM GET-USER-INPUT.

READ-CONFIG.
    OPEN INPUT CONFIG-FILE
    PERFORM UNTIL WS-CONFIG-EOF = 'Y'
        READ CONFIG-FILE
            AT END
                MOVE 'Y' TO WS-CONFIG-EOF
            NOT AT END
                EVALUATE CONFIG-KEY
                    WHEN "MAX_SALARY"
                        MOVE CONFIG-VALUE TO WS-MAX-SALARY
                    WHEN "MIN_SALARY"
                        MOVE CONFIG-VALUE TO WS-MIN-SALARY
                END-EVALUATE
    END-PERFORM
    CLOSE CONFIG-FILE.

GET-USER-INPUT.
    DISPLAY "Enter employee file name: "
    ACCEPT WS-EMPLOYEE-FILENAME
    DISPLAY "Enter report file name: "
    ACCEPT WS-REPORT-FILENAME
    PERFORM GET-SORT-OPTION.

GET-SORT-OPTION.
    DISPLAY "Sort option (1-Name, 2-Salary, 3-Department): "
    ACCEPT WS-SORT-OPTION
    IF WS-SORT-OPTION < 1 OR WS-SORT-OPTION > 3
        DISPLAY "Invalid option. Please enter 1, 2, or 3."
        GO TO GET-SORT-OPTION.

OPEN-FILES.
    OPEN INPUT EMPLOYEE-FILE
    IF NOT FILE-STATUS = "00"
        MOVE "Error opening employee file" TO WS-ERROR-MESSAGE
        PERFORM DISPLAY-ERROR
    END-IF
    OPEN OUTPUT REPORT-FILE
    IF NOT FILE-STATUS = "00"
        MOVE "Error opening report file" TO WS-ERROR-MESSAGE
        PERFORM DISPLAY-ERROR
    END-IF.

INITIALIZE-REPORT.
    MOVE FUNCTION CURRENT-DATE TO WS-CURRENT-DATE
    MOVE FUNCTION CONCATENATE(WS-YEAR "-" WS-MONTH "-" WS-DAY)
        TO WS-HEADING-DATE
    MOVE WS-HEADING TO REPORT-LINE
    WRITE REPORT-LINE
    MOVE SPACES TO REPORT-LINE
    MOVE "ID    NAME                           POSITION             SALARY       DEPARTMENT         HIRE DATE" 
        TO REPORT-LINE
    WRITE REPORT-LINE
    MOVE ALL "-" TO REPORT-LINE
    WRITE REPORT-LINE.

PROCESS-RECORDS.
    READ EMPLOYEE-FILE
        AT END
            MOVE 'Y' TO WS-EOF
        NOT AT END
            PERFORM VALIDATE-RECORD
            IF WS-ERROR-MESSAGE = SPACES
                PERFORM CALCULATE-TOTALS
                PERFORM WRITE-EMPLOYEE-DETAILS
            ELSE
                PERFORM DISPLAY-ERROR
            END-IF.

VALIDATE-RECORD.
    MOVE SPACES TO WS-ERROR-MESSAGE
    IF EMP-ID = ZEROS
        MOVE "Invalid Employee ID" TO WS-ERROR-MESSAGE
    ELSE IF EMP-NAME = SPACES
        MOVE "Invalid Employee Name" TO WS-ERROR-MESSAGE
    ELSE IF EMP-SALARY = ZEROS OR 
            EMP-SALARY < WS-MIN-SALARY OR 
            EMP-SALARY > WS-MAX-SALARY
        MOVE "Invalid Employee Salary" TO WS-ERROR-MESSAGE
    ELSE
        PERFORM VALIDATE-HIRE-DATE.

VALIDATE-HIRE-DATE.
    MOVE 0 TO WS-VALID-DATE
    IF EMP-HIRE-DATE(5:1) = "-" AND EMP-HIRE-DATE(8:1) = "-"
        IF EMP-HIRE-DATE(1:4) IS NUMERIC AND
           EMP-HIRE-DATE(6:2) IS NUMERIC AND
           EMP-HIRE-DATE(9:2) IS NUMERIC
            MOVE 1 TO WS-VALID-DATE
    END-IF
    IF WS-VALID-DATE = 0
        MOVE "Invalid Hire Date" TO WS-ERROR-MESSAGE.

CALCULATE-TOTALS.
    ADD 1 TO WS-EMPLOYEE-COUNT
    ADD EMP-SALARY TO WS-TOTAL-SALARY
    IF EMP-SALARY > WS-HIGHEST-SALARY
        MOVE EMP-SALARY TO WS-HIGHEST-SALARY
    END-IF
    IF EMP-SALARY < WS-LOWEST-SALARY
        MOVE EMP-SALARY TO WS-LOWEST-SALARY
    END-IF
    PERFORM UPDATE-DEPARTMENT-TOTALS
    MOVE EMP-SALARY TO WS-SALARY(WS-EMPLOYEE-COUNT).

UPDATE-DEPARTMENT-TOTALS.
    PERFORM VARYING WS-DEPT-IDX FROM 1 BY 1 
        UNTIL WS-DEPT-IDX > 20 OR WS-DEPT-NAME(WS-DEPT-IDX) = EMP-DEPARTMENT 
        OR WS-DEPT-NAME(WS-DEPT-IDX) = SPACES
    END-PERFORM
    IF WS-DEPT-IDX <= 20
        IF WS-DEPT-NAME(WS-DEPT-IDX) = SPACES
            MOVE EMP-DEPARTMENT TO WS-DEPT-NAME(WS-DEPT-IDX)
        END-IF
        ADD 1 TO WS-DEPT-COUNT(WS-DEPT-IDX)
        ADD EMP-SALARY TO WS-DEPT-SALARY(WS-DEPT-IDX).

WRITE-EMPLOYEE-DETAILS.
    MOVE SPACES TO REPORT-LINE
    STRING EMP-ID " " EMP-NAME " " EMP-POSITION " " 
        EMP-SALARY " " EMP-DEPARTMENT " " EMP-HIRE-DATE
        DELIMITED BY SIZE INTO REPORT-LINE
    WRITE REPORT-LINE.

SORT-EMPLOYEES.
    EVALUATE WS-SORT-OPTION
        WHEN 1
            PERFORM SORT-BY-NAME
        WHEN 2
            PERFORM SORT-BY-SALARY
        WHEN 3
            PERFORM SORT-BY-DEPARTMENT.

SORT-BY-SALARY.
    PERFORM VARYING WS-SALARY-IDX FROM 1 BY 1 
        UNTIL WS-SALARY-IDX > WS-EMPLOYEE-COUNT - 1
        PERFORM VARYING WS-DEPT-IDX FROM WS-SALARY-IDX BY 1 
            UNTIL WS-DEPT-IDX > WS-EMPLOYEE-COUNT
            IF WS-SALARY(WS-SALARY-IDX) > WS-SALARY(WS-DEPT-IDX)
                MOVE WS-SALARY(WS-SALARY-IDX) TO WS-TEMP-SALARY
                MOVE WS-SALARY(WS-DEPT-IDX) TO WS-SALARY(WS-SALARY-IDX)
                MOVE WS-TEMP-SALARY TO WS-SALARY(WS-DEPT-IDX)
            END-IF
        END-PERFORM
    END-PERFORM.

CALCULATE-STATISTICS.
    IF WS-EMPLOYEE-COUNT > 0
        DIVIDE WS-TOTAL-SALARY BY WS-EMPLOYEE-COUNT 
            GIVING WS-AVG-SALARY ROUNDED
        COMPUTE WS-SALARY-IDX = WS-EMPLOYEE-COUNT / 2
        MOVE WS-SALARY(WS-SALARY-IDX) TO WS-MEDIAN-SALARY
        PERFORM CALCULATE-STDEV
    END-IF.

CALCULATE-STDEV.
    COMPUTE WS-SALARY-STDEV = 
        FUNCTION SQRT(
            FUNCTION SUM(
                (WS-SALARY(ALL) - WS-AVG-SALARY) ** 2
            ) / WS-EMPLOYEE-COUNT
        ).

WRITE-REPORT.
    PERFORM WRITE-SUMMARY-STATISTICS
    PERFORM WRITE-DEPARTMENT-SUMMARY.

WRITE-SUMMARY-STATISTICS.
    MOVE SPACES TO REPORT-LINE
    WRITE REPORT-LINE
    MOVE ALL "-" TO REPORT-LINE
    WRITE REPORT-LINE
    MOVE SPACES TO REPORT-LINE
    STRING "Total Employees: " WS-EMPLOYEE-COUNT
        DELIMITED BY SIZE INTO REPORT-LINE
    WRITE REPORT-LINE
    MOVE SPACES TO REPORT-LINE
    STRING "Total Salary: $" WS-TOTAL-SALARY
        DELIMITED BY SIZE INTO REPORT-LINE
    WRITE REPORT-LINE
    MOVE SPACES TO REPORT-LINE
    STRING "Average Salary: $" WS-AVG-SALARY
        DELIMITED BY SIZE INTO REPORT-LINE
    WRITE REPORT-LINE
    MOVE SPACES TO REPORT-LINE
    STRING "Median Salary: $" WS-MEDIAN-SALARY
        DELIMITED BY SIZE INTO REPORT-LINE
    WRITE REPORT-LINE
    MOVE SPACES TO REPORT-LINE
    STRING "Highest Salary: $" WS-HIGHEST-SALARY
        DELIMITED BY SIZE INTO REPORT-LINE
    WRITE REPORT-LINE
    MOVE SPACES TO REPORT-LINE
    STRING "Lowest Salary: $" WS-LOWEST-SALARY
        DELIMITED BY SIZE INTO REPORT-LINE
    WRITE REPORT-LINE
    MOVE SPACES TO REPORT-LINE
    STRING "Salary Standard Deviation: $" WS-SALARY-STDEV
        DELIMITED BY SIZE INTO REPORT-LINE
    WRITE REPORT-LINE.

WRITE-DEPARTMENT-SUMMARY.
    MOVE SPACES TO REPORT-LINE
    WRITE REPORT-LINE
    MOVE "DEPARTMENT SUMMARY" TO REPORT-LINE
    WRITE REPORT-LINE
    MOVE ALL "-" TO REPORT-LINE
    WRITE REPORT-LINE
    PERFORM VARYING WS-DEPT-IDX FROM 1 BY 1 UNTIL WS-DEPT-IDX > 20
        IF WS-DEPT-NAME(WS-DEPT-IDX) NOT = SPACES
            MOVE SPACES TO REPORT-LINE
            STRING WS-DEPT-NAME(WS-DEPT-IDX) ": " 
                WS-DEPT-COUNT(WS-DEPT-IDX) " employees, Total Salary: $"
                WS-DEPT-SALARY(WS-DEPT-IDX)
                ", Percentage of total salary: "
                FUNCTION TRIM(FUNCTION REM(
                    (WS-DEPT-SALARY(WS-DEPT-IDX) / WS-TOTAL-SALARY * 100), 0.01
                ))
                "%"
                DELIMITED BY SIZE INTO REPORT-LINE
            WRITE REPORT-LINE
        END-IF
    END-PERFORM.

CLOSE-FILES.
    CLOSE