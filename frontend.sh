#!/bin/bash

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

dnf module list nginx &>>$LOG_FILE
VALIDATE $? "Listing nginx modules"

dnf module disable nginx -y &>>$LOG_FILE
VALIDATE $? "Disabling default nginx module"

dnf module enable nginx:1.24 -y &>>$LOG_FILE
VALIDATE $? "Enabling nginx:1.24 module"

dnf install nginx -y &>>$LOG_FILE
VALIDATE $? "Installing nginx"

systemctl enable nginx &>>$LOG_FILE
VALIDATE $? "Enabling nginx service"

systemctl start nginx &>>$LOG_FILE
VALIDATE $? "Starting nginx service"

rm -rf /usr/share/nginx/html/* &>>$LOG_FILE
VALIDATE $? "Cleaning old nginx files"

curl -o /tmp/frontend.zip https://student-admission.s3.us-east-1.amazonaws.com/frontend.zip &>>$LOG_FILE

VALIDATE $? "Downloading frontend code"

cd /usr/share/nginx/html &>>$LOG_FILE
VALIDATE $? "Navigating to nginx html directory"

unzip -o /tmp/frontend.zip &>>$LOG_FILE
VALIDATE $? "Extracting frontend files"

rm -rf /etc/nginx/nginx.conf
VALIDATE $? "Remove default nginx configuration"

cp $SCRIPT_DIR/nginx.conf /etc/nginx/nginx.conf &>>$LOG_FILE
VALIDATE $? "Copying nginx configuration"

systemctl restart nginx &>>$LOG_FILE
VALIDATE $? "Restarting nginx service"