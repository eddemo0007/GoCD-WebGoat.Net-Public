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
SET SCAN_NAME=Scan012
SET VERSION=Version012
SET SCAN_PDF_REPORT=scan_report.pdf
SET FILEPATH=C:\local-repos\verademo-dotnet\app\bin.zip

ECHO Start of: Veracode Upload and Scan
REM Upload to Veracode
java -jar "%VERACODE_JAR_PATH%" -vid "%API_ID%" -vkey "%API_KEY%" -action uploadandscan -appname "%APP_NAME%" -createprofile false -filepath %FILEPATH% -version %VERSION%
ECHO End of: Veracode Upload and Scan

ECHO Start of: Lets get the Analysis ID

# Using grep and awk to extract the analysis ID
# Path to the console.log file within the artifacts directory
log_file_path="cruise-output/console.log"

# Extracting the analysis ID from the log file
analysis_id=$(grep -oE 'analysis id of the new analysis is "([0-9]+)"' "$log_file_path" | awk -F '"' '{print $2}')

# Printing the extracted analysis ID
echo "Extracted Analysis ID: $analysis_id"

Echo End of: Lets get the Analysis ID

ECHO Start of Eds Check
java -jar "%VERACODE_JAR_PATH%" -vid "%API_ID%" -vkey "%API_KEY%" -action getappbuilds -appname "%APP_NAME%" 
ECHO End of Eds Check

ECHO Start of: Check Scan Status 001

:CHECK_SCAN_STATUS
FOR /f "tokens=*" %%i in ('java -jar "%VERACODE_JAR_PATH%" -vid "%API_ID%" -vkey "%API_KEY%" -action getappbuilds -appname "%APP_NAME%" ^| findstr /C:"status="') do (
    SET "SCAN_STATUS=%%i"
)
SET "SCAN_STATUS=%SCAN_STATUS:status=%"

ECHO End of: Check Scan Status 001

ECHO Start of: Check Scan Status 002
REM Check the scan status
IF "%SCAN_STATUS%" == " ResultsReady " (
    REM Download PDF report
    java -jar "%VERACODE_JAR_PATH%" -vid "%API_ID%" -vkey "%API_KEY%" -action summaryreport -appname "%APP_NAME%" -buildname "%SCAN_NAME%" -outputfile "%SCAN_PDF_REPORT%"
) ELSE (
    TIMEOUT /T 10
    GOTO CHECK_SCAN_STATUS
)
ECHO End of: Check Scan Status 002

EXIT /B

