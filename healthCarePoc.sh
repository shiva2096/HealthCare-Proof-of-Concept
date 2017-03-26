#Input File Detail
inputFileName=InputPdfPoc1.pdf
#Variables Used
mysqlDbName=health_db
mysqlTableName=health_tab
hiveDbName=health_care_db
hiveTableName=health_care_tab
#Input and Output HDFS Location Names
InputPdfLocation=/Poc1Input
MRLogLocation=/HealthCareLog
MROutputLocation=/HealthCareOut
PigDistinctOutputLocation=/PigDistinctOut
PigSortOutputLocation=/PigSortOut
#Mysql Connection Details
mysqlUser=root
mysqlPass=root

#Code Starts From Here
########################################################################################################

#Removing HDFS Directories
hadoop fs -rmr $PigDistinctOutputLocation $PigSortOutputLocation $InputPdfLocation

#Placing Input Pdf File On HDFS 
hadoop fs -mkdir $InputPdfLocation
hadoop fs -put InputPdfPoc1.pdf $InputPdfLocation

#Running MapReduce Job
hadoop jar PdfProcessing.jar com/pdfprocess/poc1/PdfDriver $InputPdfLocation/$inputFileName $MRLogLocation $MROutputLocation

#Running Pig Script
pig -p Input=$MROutputLocation/* -p DistinctLoc=$PigDistinctOutputLocation -p SortLoc=$PigSortOutputLocation HealthCarePoc.pig

#Creating MySql Table
mysql -u $mysqlUser -p$mysqlPass << EOF
drop database if exists $mysqlDbName;
create database $mysqlDbName;
create table $mysqlDbName.$mysqlTableName(
pid int,
pname varchar(20),
page int,
pgender varchar(6),
pdisease varchar(10),
hname varchar(20),
adate varchar(10),
paddress varchar(30));
grant all privileges on $mysqlDbName.* to ''@'localhost';
EOF

#Exporting Pig Output to MySql Table
sqoop export --connect jdbc:mysql://localhost/$mysqlDbName --table $mysqlTableName --fields-terminated-by '\t' --export-dir $PigSortOutputLocation/part*;

#Exporting Pig Output To Hive Table
hive << EOF
drop database if exists $hiveDbName cascade;
create database $hiveDbName;
create external table $hiveDbName.$hiveTableName(pid int,pname string,page int,pgender string,pdisease string,
hname string,adate string,paddress string)
row format delimited
fields terminated by '\t'
lines terminated by '\n'
stored as textfile location '$PigSortOutputLocation';
EOF
