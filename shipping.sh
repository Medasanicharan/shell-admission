#!/bin/bash

START_TIME=$(date +%s)

USERID=$(id -u)

R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD

mkdir -p $LOGS_FOLDER
echo "Script started ececuting at: $(date)" | tee -a $LOG_FILE

if [ $USERID -ne 0 ]
then
    echo -e "$R ERROR:: Please run this script with root access $N" | tee -a $LOG_FILE
    exit 1 # Give other then 0 upto 127
else
    echo -e "$G You are running with root access $N" | tee -a $LOG_FILE
fi

# validate function takes input as exit status, what command they tried to install.
VALIDATE(){
    if [ $1 -eq 0 ]
    then
        echo -e "$2 is... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is... $R FAILURE $N" | tee -a $LOG_FILE
        exit 1
    fi
}

dnf install maven -y &>>$LOG_FILE
VALIDATE $? "Instaling maven and java"

id roboshop &>>$LOG_FILE
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
    VALIDATE $? "Creating roboshop system user"
else
    echo -e "roboshop user already exists - $Y SKIPPING $N" | tee -a $LOG_FILE
fi

echo "Please enter the root password to setup:"
read -s MYSQL_ROOT_PASSWORD

mkdir -p /app &>>$LOG_FILE
VALIDATE $? "creating app diectory"

curl -o /tmp/shipping.zip https://student-admission.s3.us-east-1.amazonaws.com/backend.zip
&>>$LOG_FILE
VALIDATE $? "Downloading shipping"

rm -rf /app/*
cd /app
unzip -o /tmp/shipping.zip &>>$LOG_FILE
VALIDATE $? "Unzipping shipping"

cd /app 
mvn clean package &>>$LOG_FILE
VALIDATE $? "Maven package creation"

mv target/shipping-1.0.jar shipping.jar &>>$LOG_FILE
VALIDATE $? "Renaming shipping.jar"

cp $SCRIPT_DIR/shipping.service /etc/systemd/system/shipping.service &>>$LOG_FILE
VALIDATE $? "Coping shipping service"

systemctl daemon-reload &>>$LOG_FILE
VALIDATE $? "Reloading systemd daemon"

systemctl enable shipping &>>$LOG_FILE
VALIDATE $? "Enabling shipping"

systemctl start shipping &>>$LOG_FILE
VALIDATE $? "Starting shipping"

dnf install mysql -y &>>$LOG_FILE
VALIDATE $? "Installing MySQL client"

mysql -h mysql.daws2025.online -uroot -p$MYSQL_ROOT_PASSWORD -e 'use cities'
if [ $? -ne 0 ]
then
    mysql -h mysql.daws2025.online -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/schema.sql &>>$LOG_FILE
    mysql -h mysql.daws2025.online -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/app-user.sql &>>$LOG_FILE
    mysql -h mysql.daws2025.online -uroot -p$MYSQL_ROOT_PASSWORD < /app/db/master-data.sql &>>$LOG_FILE
    VALIDATE $? "Loading master data into MySQL"
else
    echo -e "Data is already loaded into MySQL... $Y SKIPPING $N"
fi

systemctl restart shipping
VALIDATE $? "Restarting the shipping"

END_TIME=$(date +%s)
TOTAL_TIME=$(($END_TIME - $START_TIME))

echo -e "script execution completed successfully, $Y time taken: $TOTAL_TIME seconds $N" | tee -a $LOG_FILE