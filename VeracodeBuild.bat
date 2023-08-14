@ECHO OFF

echo Let us pretend that this is building something ... and takes 20 seconds

FOR /l %%A in (1, 1, 20) DO (
  ECHO Building [[01;31m %%A of 20 [00m]
  PING 192.0.2.1 -n 1 -w 1000 >NUL
)

(
  ECHO ^<html^>
  ECHO ^<body^>
  ECHO ^<h3^>An example artifact^</h3^>
  ECHO ^<pre^>
  ECHO ==== ==== ====
  ECHO An example artifact, created on:
  DATE /T
  TIME /T
  ECHO Pipeline which created it: %GO_PIPELINE_NAME%
  ECHO Pipeline counter was: %GO_PIPELINE_COUNTER%
  ECHO ==== ==== ====
  ECHO ^</pre^>
  ECHO ^<body^>
  ECHO ^</html^>
) >my-artifact.html

SET VERACODE_JAR_PATH=.\VeracodeJavaAPI.jar
SET API_ID=8e3c8af9f16be054867c9344ce74090e
SET API_KEY=3e95620ba25005d71b4d983a178454d9efe0836e6c00e60def419649472f3023878512af1d2aa24ec3950afc92aac916013add32409b9e4d60f623eb978546ff
SET APP_NAME=GoCDVerademo-dotnet0001
SET SCAN_NAME=Scan007
SET VERSION=Version007
SET SCAN_PDF_REPORT=scan_report.pdf
SET FILEPATH=C:\local-repos\verademo-dotnet\app\bin.zip

ECHO Start of: Veracode Upload and Scan
REM Upload to Veracode
java -jar "%VERACODE_JAR_PATH%" -vid "%API_ID%" -vkey "%API_KEY%" -action uploadandscan -appname "%APP_NAME%" -createprofile false -filepath %FILEPATH% -version %VERSION%
ECHO End of: Veracode Upload and Scan

:CHECK_SCAN_STATUS
FOR /f "tokens=*" %%i in ('java -jar "%VERACODE_JAR_PATH%" -vid "%API_ID%" -vkey "%API_KEY%" -action getappbuilds -appname "%APP_NAME%" ^| findstr "status="') do (
    SET "SCAN_STATUS=%%i"
)

REM Check the scan status
IF "%SCAN_STATUS%" EQU "ResultsReady" (
    REM Download PDF report
    java -jar "%VERACODE_JAR_PATH%" -vid "%API_ID%" -vkey "%API_KEY%" -action summaryreport -appname "%APP_NAME%" -buildname "%SCAN_NAME%" -outputfile "%SCAN_PDF_REPORT%"
) ELSE (
    TIMEOUT /T 10
    GOTO CHECK_SCAN_STATUS
)

EXIT /B
